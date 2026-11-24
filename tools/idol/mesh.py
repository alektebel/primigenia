#!/usr/bin/env python3
"""CPU 3DGS density -> marching cubes -> QEM -> vertex-coloured GLB.

PLY follows Idol save_ply: already y-up; scales are log(sigma), opacity is
logit(alpha), rotations are wxyz, f_dc is degree-zero spherical harmonics.
See README for the explicit field and approximation limits.
"""
import argparse
from dataclasses import dataclass
import json
from pathlib import Path
import numpy as np
from plyfile import PlyData
from scipy.spatial import cKDTree
from skimage.measure import marching_cubes
import trimesh
from trimesh.visual.material import PBRMaterial

SH0 = .28209479177387814
REGIONS = {'skin': ('Tidal teal skin', .65), 'keratin': ('Plum keratin', .48),
           'eye': ('Obsidian eyes', .16), 'membrane': ('Coral membrane', .72)}


@dataclass
class Splats:
    xyz: np.ndarray
    scale: np.ndarray
    rotation: np.ndarray
    alpha: np.ndarray
    rgb: np.ndarray


def quaternion_matrices(q):
    q = q / np.linalg.norm(q, axis=1, keepdims=True)
    w,x,y,z = q.T
    return np.stack([1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w),
                     2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w),
                     2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)],axis=1).reshape(-1,3,3)


def load_splats(path):
    v = PlyData.read(str(path))['vertex'].data
    def columns(names):
        if not set(names).issubset(v.dtype.names):
            raise ValueError('Expected standard 3DGS PLY with opacity, log scales, wxyz rotation and f_dc')
        return np.column_stack([v[n] for n in names]).astype(np.float64)
    xyz = columns(['x','y','z'])
    log_scale = columns(['scale_0','scale_1','scale_2'])
    q = columns(['rot_0','rot_1','rot_2','rot_3'])
    opacity = columns(['opacity'])[:,0]
    rgb = columns(['f_dc_0','f_dc_1','f_dc_2']) * SH0 + .5
    if not all(np.isfinite(a).all() for a in (xyz,log_scale,q,opacity,rgb)):
        raise ValueError('Nonfinite Gaussian attributes')
    if np.any(np.linalg.norm(q,axis=1)<1e-8) or np.any(log_scale>2) or np.any(log_scale<-25):
        raise ValueError('Invalid Gaussian rotation or unreasonable log scale')
    alpha = 1 / (1 + np.exp(-np.clip(opacity,-80,80)))
    keep = alpha >= .01
    if not keep.any():
        raise ValueError('No Gaussians have opacity >= .01')
    return Splats(xyz[keep],np.exp(log_scale[keep]),q[keep],alpha[keep],np.clip(rgb[keep],0,1))


def extract_mesh(splats, resolution=128, level=.18, budget=4000):
    if not 24<=resolution<=192 or not 0<level<1 or not 4<=budget<=4000:
        raise ValueError('resolution 24..192, level 0..1 exclusive, budget 4..4000 required')
    s = splats
    rot = quaternion_matrices(s.rotation)
    covariance = np.einsum('nik,nk,njk->nij',rot,s.scale**2,rot)
    # Pad by >3 sigmas to keep the extracted iso-surface away from grid bounds.
    radius = 3.5*np.sqrt(np.diagonal(covariance,axis1=1,axis2=2))
    lo = (s.xyz-radius).min(axis=0); hi=(s.xyz+radius).max(axis=0)
    pitch = float(np.max(hi-lo)/(resolution-5))
    if not np.isfinite(pitch) or pitch<=0:
        raise ValueError('Degenerate Gaussian bounds')
    center=(hi+lo)/2; lo=center-pitch*(resolution-1)/2
    covariance += np.eye(3)[None]*(pitch*.5)**2
    inverse = np.linalg.inv(covariance)
    support=3.5*np.sqrt(np.diagonal(covariance,axis1=1,axis2=2))
    tau=np.zeros((resolution,)*3,dtype=np.float32)
    for pos,cov_inv,r,a in zip(s.xyz,inverse,support,s.alpha):
        start=np.maximum(0,np.floor((pos-r-lo)/pitch).astype(int))
        end=np.minimum(resolution,np.ceil((pos+r-lo)/pitch).astype(int)+1)
        axes=[lo[k]+np.arange(start[k],end[k])*pitch-pos[k] for k in range(3)]
        delta=np.stack(np.meshgrid(*axes,indexing='ij'),axis=-1)
        d2=np.einsum('...i,ij,...j->...',delta,cov_inv,delta,optimize=True)
        density=(-np.log1p(-min(a,1-1e-6)))*np.exp(-.5*d2)
        density[d2>3.5**2]=0
        tau[tuple(slice(a,b) for a,b in zip(start,end))]+=density.astype(np.float32)
    occupancy=-np.expm1(-tau)
    if not float(occupancy.min())<level<float(occupancy.max()):
        raise ValueError('No density iso-surface at requested level')
    vertices,faces,_,_=marching_cubes(occupancy,level=level,spacing=(pitch,)*3,allow_degenerate=False)
    mesh=trimesh.Trimesh(vertices+lo,faces,process=True)
    initial_faces=len(mesh.faces)
    pieces=mesh.split(only_watertight=False)
    threshold=max(len(p.faces) for p in pieces)*.01
    kept=[p for p in pieces if len(p.faces)>=threshold]
    mesh=trimesh.util.concatenate(kept)
    if len(mesh.faces)>budget:
        mesh=mesh.simplify_quadric_decimation(face_count=budget)
    mesh.remove_unreferenced_vertices()
    trimesh.repair.fix_normals(mesh,multibody=True)
    if not len(mesh.faces) or len(mesh.faces)>budget or not np.isfinite(mesh.vertices).all():
        raise ValueError('Decimation produced invalid mesh or exceeded triangle budget')
    report={'retained_gaussians':len(s.xyz),'resolution':resolution,'iso_level':level,
            'pitch':pitch,'initial_triangles':initial_faces,'triangles':len(mesh.faces),
            'components_before':len(pieces),'components_kept':len(kept),
            'watertight':bool(mesh.is_watertight),'bounds':mesh.bounds.tolist()}
    return mesh,report


def sample_colours(mesh,s):
    # Local interpolation avoids baking view-dependent lighting from invented SH.
    _,idx=cKDTree(s.xyz).query(mesh.vertices,k=min(8,len(s.xyz)))
    idx=np.asarray(idx).reshape(len(mesh.vertices),-1)
    rot=quaternion_matrices(s.rotation)
    cov=np.einsum('nik,nk,njk->nij',rot,s.scale**2,rot)+np.eye(3)[None]*1e-8
    delta=mesh.vertices[:,None]-s.xyz[idx]
    d2=np.einsum('nki,nkij,nkj->nk',delta,np.linalg.inv(cov)[idx],delta)
    weights=np.exp(-.5*np.minimum(d2,80))*s.alpha[idx]+1e-20
    return (s.rgb[idx]*weights[...,None]).sum(axis=1)/weights.sum(axis=1,keepdims=True)


def export_asset(mesh,splats,path,style='toon',region='keratin'):
    if style not in ('toon','physical') or region not in REGIONS:
        raise ValueError('Unknown style or material region')
    mesh=mesh.copy()
    rgb=sample_colours(mesh,splats)
    if style=='toon':
        # Palette C linear r0/r1/r2 from tools/hero/build_hero.py, not guessed hex.
        palette=np.array([[.15,.165,.19],[.28,.215,.14],[.19,.135,.085]])
        linear=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
        nearest=((linear[:,None]-palette)**2).sum(axis=2).argmin(axis=1)
        base=palette[nearest]
        light=np.array([.6,.8,.5]);light/=np.linalg.norm(light)
        nl=mesh.vertex_normals@light
        bands=np.where(nl[:,None]<.05,np.array([.68,.84,1.20]),
                       np.where(nl[:,None]<.55,np.array([.94,.97,1.02]),np.array([1.30,1.10,.84])))
        linear=np.clip(base*bands,0,1)
        rgb=np.where(linear<=.0031308,12.92*linear,1.055*linear**(1/2.4)-.055)
        material=PBRMaterial(name='Palette C baked toon',baseColorFactor=[255]*4,roughnessFactor=1,metallicFactor=0)
    else:
        name,roughness=REGIONS[region]
        material=PBRMaterial(name=name,baseColorFactor=[255]*4,roughnessFactor=roughness,metallicFactor=0)
    colours=np.column_stack([np.rint(np.clip(rgb,0,1)*255).astype(np.uint8),np.full(len(rgb),255,dtype=np.uint8)])
    # TextureVisuals retains the PBR material; add COLOR_0 explicitly at export.
    mesh.visual=trimesh.visual.TextureVisuals(material=material)
    mesh.vertex_attributes['color']=colours
    mesh.metadata={'cpore_visual_asset_only':True,'cpore_region':region if style=='physical' else 'prop',
                   'cpore_style':style,'cpore_attachment':'unreviewed','source':'Idol 3DGS density extraction'}
    scene=trimesh.Scene(mesh)
    def postprocess(tree):
        # trimesh emits custom attributes with underscore; move to glTF COLOR_0.
        for m in tree.get('meshes',[]):
            for p in m['primitives']:
                attrs=p['attributes']
                if '_color' in attrs:attrs['COLOR_0']=attrs.pop('_color')
        if style=='toon':
            tree.setdefault('extensionsUsed',[]).append('KHR_materials_unlit')
            for m in tree['materials']:m.setdefault('extensions',{})['KHR_materials_unlit']={}
    data=trimesh.exchange.gltf.export_glb(scene,tree_postprocessor=postprocess)
    Path(path).parent.mkdir(parents=True,exist_ok=True)
    Path(path).write_bytes(data)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('ply',type=Path);p.add_argument('--out',type=Path,required=True)
    p.add_argument('--kind',choices=['prop','part'],required=True)
    p.add_argument('--region',choices=list(REGIONS),default='keratin')
    p.add_argument('--resolution',type=int,default=128);p.add_argument('--level',type=float,default=.18)
    args=p.parse_args();s=load_splats(args.ply)
    m,r=extract_mesh(s,args.resolution,args.level,3000 if args.kind=='part' else 4000)
    style='physical' if args.kind=='part' else 'toon'
    export_asset(m,s,args.out,style,args.region)
    r.update(style=style,region=args.region if args.kind=='part' else None,source=str(args.ply))
    args.out.with_suffix('.json').write_text(json.dumps(r,indent=2)+'\n')
    print(json.dumps(r))


if __name__=='__main__':main()
