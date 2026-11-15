#!/usr/bin/env python3
"""Run licensed photos through the official Idol SDK and CPU GLB converter.

Execute with nice -n 10. All HF data stays outside the repository. No alternative
encoder or fabricated splat is substituted when the required models are gated.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import threading
import time

ROOT=Path(__file__).resolve().parents[2]
EXTERNAL=ROOT.parent/'_agent'
MODELS=EXTERNAL/'models'
# Set before importing Hugging Face, torch or the Idol SDK.
os.environ['HF_HOME']=str(MODELS/'huggingface')
os.environ['TORCH_HOME']=str(MODELS/'torch')
os.environ.setdefault('ATTN_BACKEND','sdpa')
os.environ.setdefault('OMP_NUM_THREADS','4')
SDK_REVISION='8db700349a5570aac390e4780fa32e3eed6b587a'
MODEL_REVISION='2731c2291fc65a797c5cb627a5e5526fc1490902'
DEFAULT_WEIGHTS=MODELS/f'huggingface/hub/models--speridlabs--idol/snapshots/{MODEL_REVISION}'


def approved_inputs(manifest, ids):
    assets=json.loads(Path(manifest).read_text())['assets']
    selected=[]
    for a in assets:
        if ids and a['id'] not in ids:continue
        if not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*',a['id']):
            raise ValueError('Unsafe asset id')
        if a['license'] not in ('CC0-1.0','public-domain','owner-provided'):
            raise ValueError(f"Unapproved image licence: {a['id']}")
        if not a.get('author') or not a.get('source_url'):
            raise ValueError('Image credit is required')
        path=(ROOT/a['image']).resolve()
        if ROOT not in path.parents:raise ValueError('Image path must be within this worktree')
        if hashlib.sha256(path.read_bytes()).hexdigest()!=a['sha256']:
            raise ValueError(f"Image checksum mismatch: {a['id']}")
        if a['kind'] not in ('prop','part'):raise ValueError('Unknown asset kind')
        selected.append(a)
    if ids and set(ids)!={a['id'] for a in selected}:raise ValueError('Unknown requested asset id')
    if not selected:raise ValueError('No images selected')
    return selected


class DeviceMemorySampler:
    """Device-wide VRAM via nvidia-smi; includes display/other processes. MiB."""
    def __init__(self):self.values=[];self.stop=threading.Event()
    def sample(self):
        while not self.stop.is_set():
            r=subprocess.run(['nvidia-smi','--query-gpu=memory.used','--format=csv,noheader,nounits','--id=0'],capture_output=True,text=True)
            if r.returncode==0:
                try:self.values.append(int(r.stdout.strip()))
                except ValueError:pass
            self.stop.wait(.2)
    def __enter__(self):
        self.thread=threading.Thread(target=self.sample,daemon=True);self.thread.start();return self
    def __exit__(self,*args):self.stop.set();self.thread.join()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--manifest',type=Path,default=ROOT/'assets/idol/manifest.json')
    p.add_argument('--ids',nargs='+',default=['rock-03','stump-01','horn-01'])
    p.add_argument('--all',action='store_true');p.add_argument('--preflight',action='store_true')
    p.add_argument('--weights',default=str(DEFAULT_WEIGHTS))
    p.add_argument('--steps',type=int,default=50);p.add_argument('--gaussians',type=int,default=65536)
    p.add_argument('--seed',type=int,default=42);p.add_argument('--resolution',type=int,default=128)
    p.add_argument('--out',type=Path,default=ROOT/'assets/idol/generated')
    p.add_argument('--report',type=Path,default=ROOT/'docs/evidence/idol/benchmark.json')
    args=p.parse_args()
    if not 1<=args.steps<=100 or not 32768<=args.gaussians<=1048576 or args.gaussians%32:
        p.error('steps 1..100; Gaussians 32768..1048576 divisible by 32')
    assets=approved_inputs(args.manifest,None if args.all else args.ids)
    import torch
    torch.set_num_threads(4)
    from idol import IdolPipeline
    from idol.conditioning import EncoderAccessError, require_encoder_access
    from mesh import load_splats,extract_mesh,export_asset
    from PIL import Image
    report={'timestamp_utc':datetime.now(timezone.utc).isoformat(),'sdk_revision':SDK_REVISION,
            'model_revision':MODEL_REVISION,'weights':args.weights,'torch':torch.__version__,
            'gpu':torch.cuda.get_device_name() if torch.cuda.is_available() else None,
            'settings':{'steps':args.steps,'num_gaussians':args.gaussians,'seed':args.seed,'mode':'real','optimize':False},
            'measurement':'CUDA synchronized wall seconds per request, including preprocess and encoders; excludes loading and PLY/GLB export. MiB = 2^20 bytes. Device peak sampled every 0.2s includes other processes.',
            'model_load_seconds':None,'assets':[]}
    def save():
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(report,indent=2)+'\n')
    # Fail before loading GPU weights, but retain a structured row for each test.
    try:
        require_encoder_access(['facebook/dinov3-vith16plus-pretrain-lvd1689m','black-forest-labs/FLUX.2-dev'])
    except EncoderAccessError as e:
        report['status']='blocked_encoder_access';report['error']=str(e)
        for a in assets:
            report['assets'].append({'id':a['id'],'input_sha256':a['sha256'],'status':'blocked_before_inference',
                                     'inference_seconds':None,'peak_allocated_mib':None,'peak_reserved_mib':None,'peak_device_used_mib':None})
        save();print(report['error']);return 2
    if args.preflight:
        report['status']='encoder_access_ok';save();print(report['status']);return 0
    if not torch.cuda.is_available():
        report['status']='cuda_unavailable';save();return 2
    args.out.mkdir(parents=True,exist_ok=True)
    start=time.perf_counter()
    try:
        pipeline=IdolPipeline.from_pretrained(args.weights,device='cuda',optimize=False)
        torch.cuda.synchronize();report['model_load_seconds']=time.perf_counter()-start
    except Exception as e:
        report.update(status='model_load_failed',error=f'{type(e).__name__}: {e}');save();raise
    for a in assets:
        row={'id':a['id'],'input_sha256':a['sha256'],'status':'running','inference_seconds':None,
             'peak_allocated_mib':None,'peak_reserved_mib':None,'peak_device_used_mib':None}
        report['assets'].append(row);save()
        try:
            image=Image.open(ROOT/a['image']).convert('RGB')
            if a.get('crop'):image=image.crop(a['crop'])
            torch.cuda.synchronize();torch.cuda.reset_peak_memory_stats()
            with DeviceMemorySampler() as memory:
                start=time.perf_counter()
                output=pipeline(image,mode='real',seed=args.seed,steps=args.steps,num_gaussians=args.gaussians)
                torch.cuda.synchronize();row['inference_seconds']=time.perf_counter()-start
                row['peak_allocated_mib']=torch.cuda.max_memory_allocated()/2**20
                row['peak_reserved_mib']=torch.cuda.max_memory_reserved()/2**20
            row['peak_device_used_mib']=max(memory.values) if memory.values else None
            base=args.out/a['id']
            output.gaussian.save_ply(str(base.with_suffix('.ply')))
            output.preprocessed_image.save(str(base)+'_input.png')
            base.with_suffix('.camera.json').write_text(json.dumps(output.camera,indent=2)+'\n')
            del output
            start=time.perf_counter();splats=load_splats(base.with_suffix('.ply'))
            mesh,metrics=extract_mesh(splats,resolution=args.resolution,budget=3000 if a['kind']=='part' else 4000)
            export_asset(mesh,splats,base.with_suffix('.glb'),'physical' if a['kind']=='part' else 'toon',a.get('region') or 'keratin')
            row.update(status='generated_unreviewed',conversion_seconds=time.perf_counter()-start,mesh=metrics)
        except Exception as e:
            row.update(status='failed',error=f'{type(e).__name__}: {e}')
            if isinstance(e,torch.cuda.OutOfMemoryError):torch.cuda.empty_cache()
        save()
    report['status']='generated_unreviewed' if all(x['status']=='generated_unreviewed' for x in report['assets']) else 'failed'
    save();print(json.dumps(report,indent=2));return 0 if report['status']=='generated_unreviewed' else 1


if __name__=='__main__':raise SystemExit(main())
