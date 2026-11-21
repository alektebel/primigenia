"""Fit the ten-body M1 pilot and replay one winner per body on software EGL."""
import argparse
from concurrent.futures import ProcessPoolExecutor
import gzip
import hashlib
from importlib.metadata import version
import json
import multiprocessing as mp
import os
from pathlib import Path
import subprocess
import sys
import tempfile

# Inherit nice priority and single-threaded numeric kernels in every child.
if os.nice(0) < 19:
    os.nice(19-os.nice(0))
for var in ("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS", "LP_NUM_THREADS"):
    os.environ[var] = "1"
os.environ.update(MUJOCO_GL="disable", LIBGL_ALWAYS_SOFTWARE="1", GALLIUM_DRIVER="llvmpipe")


def software_backend():
    # Both importing and creating a GL context can fail. Probe outside the solver
    # interpreter so traces can still be generated with MuJoCo's GL backend disabled.
    probe = """import mujoco
from OpenGL import GL
with mujoco.Renderer(mujoco.MjModel.from_xml_string('<mujoco/>')) as renderer:
    print(GL.glGetString(GL.GL_RENDERER).decode())
"""
    failures = []
    for backend in ("osmesa", "egl"):
        process = subprocess.run([sys.executable, "-c", probe], capture_output=True, text=True,
                                 env={**os.environ, "MUJOCO_GL": backend})
        if process.returncode == 0 and is_software_renderer(process.stdout):
            return backend, ""
        message = (process.stderr or process.stdout or "context creation failed").strip()
        failures.append(f"{backend} {message.splitlines()[-1]}")
    return "disable", " / ".join(failures)


def is_software_renderer(name):
    return any(driver in name.lower() for driver in ("llvmpipe", "softpipe", "swrast"))


gl_error = ""
if __name__ == "__main__" and "--evidence-only" in sys.argv:
    os.environ["MUJOCO_GL"], gl_error = software_backend()

import mujoco
import numpy as np

from cost import Trial
from gait_ref import BOUNDS, decode, gait_choices
from proxy import DT

PILOT = ("biped", "horizontal_biped", "light_quadruped", "heavy_quadruped", "hexapod",
         "octopod", "wader", "hatchling", "merodeador", "garfio")
SPEEDS = (.30, .50, .70, 2., 3.)
POP = 24


def fit(job):
    name, desc, fr, seed, generations = job
    import cma

    trial = Trial(desc)
    plan = desc["analysis"]["plan"]
    choices = gait_choices(plan)
    best = {}
    counts = dict.fromkeys(choices, 0)
    iterations = 0

    def search(center, sigma, budget, run_seed, fixed_gait=None):
        if budget == 0:
            return 0
        es = cma.CMAEvolutionStrategy(center, sigma, {
            "seed": run_seed, "bounds": [0., 1.], "popsize": POP, "maxiter": budget,
            "verbose": -9, "verb_log": 0, "CMA_diagonal": True,
        })
        while not es.stop():
            candidates = es.ask()
            scores = []
            for candidate in candidates:
                x = candidate if fixed_gait is None else np.r_[candidate, fixed_gait]
                p = decode(x, plan)
                score = trial.run(p, fr)["total"]
                scores.append(score)
                gait = p["gait"]
                counts[gait] += 1
                if gait not in best or score < best[gait][0]:
                    best[gait] = (score, p, x.copy())
            es.tell(candidates, scores)
        return es.countiter

    mixed = min(24, generations)
    iterations += search([.5]*len(BOUNDS), .27, mixed, seed)
    mixed_scores = {g: entry[0] for g, entry in best.items()}
    # Give every footfall family the same local-search opportunity at every speed.
    per_family = (generations-mixed)//len(choices)
    for i, gait in enumerate(choices):
        x0 = best[gait][2][:-1] if gait in best else np.full(len(BOUNDS)-1, .5)
        iterations += search(np.clip(x0, .02, .98), .17, per_family,
                             seed+1000*(i+1), (i+.5)/len(choices))
    score, p, _ = min(best.values(), key=lambda item: item[0])
    metrics, _ = trial.run(p, fr, replay=True)
    if not np.isclose(metrics["total"], score, atol=1e-9, rtol=0):
        raise RuntimeError("Winner replay differs from evaluation")
    print(f"{name} Fr={fr:g} {p['gait']} cost={score:.3f}", flush=True)
    return name, dict(seed=seed, generations=iterations, evaluations=sum(counts.values()),
                      evaluations_by_gait=counts, mixed_search_cost_by_gait=mixed_scores,
                      best_params=p, best_cost_by_gait={g: entry[0] for g,entry in best.items()}, **metrics)


def save(path, payload):
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(payload, indent=2, allow_nan=False)+"\n")
    tmp.replace(path)


def evidence(name, desc, result, out):
    trial = Trial(desc)
    for row in result["speeds"]:
        metrics, qpos = trial.run(row["best_params"], row["command_fr"], replay=True)
        if abs(metrics["total"]-row["total"]) > 1e-9:
            raise RuntimeError(f"Evidence replay differs for {name} at Fr {row['command_fr']}")
        row.update(metrics)
        if row["command_fr"] == .50:
            clip_poses = qpos
    row = next(row for row in result["speeds"] if row["command_fr"] == .50)
    m, d = trial.m, trial.d
    # 25 fps from the 125 Hz simulation. Use the same replay for both formats.
    frames = clip_poses[4::5]
    try:
        if os.environ["MUJOCO_GL"] == "disable":
            raise RuntimeError(gl_error or "Software GL disabled")
        from OpenGL import GL
        m.vis.quality.offsamples = 0
        m.vis.quality.shadowsize = 256
        with mujoco.Renderer(m, height=192, width=320) as renderer:
            driver = GL.glGetString(GL.GL_RENDERER).decode()
            if not is_software_renderer(driver):
                raise RuntimeError("Software renderer unavailable")
            cam = mujoco.MjvCamera()
            cam.azimuth, cam.elevation = 105, -14
            h = desc["analysis"]["hip_height"]
            cam.distance = max(3.9*h, 2.1*np.linalg.norm(np.ptp([s["pos"] for s in desc["spine"]],axis=0)))
            with tempfile.TemporaryDirectory(dir=out) as tmp:
                movie = Path(tmp)/f"{name}.mp4"
                args = ["ffmpeg", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
                        "-s", "320x192", "-r", "25", "-i", "-", "-an", "-c:v", "libx264",
                        "-threads", "1", "-filter_threads", "1", "-crf", "29", "-pix_fmt", "yuv420p", str(movie)]
                with subprocess.Popen(args, stdin=subprocess.PIPE) as proc:
                    for pose in frames:
                        d.qpos[:] = pose
                        mujoco.mj_forward(m, d)
                        cam.lookat[:] = [pose[0], pose[1], .8*h]
                        renderer.update_scene(d, camera=cam)
                        renderer.scene.flags[mujoco.mjtRndFlag.mjRND_SHADOW] = False
                        renderer.scene.flags[mujoco.mjtRndFlag.mjRND_REFLECTION] = False
                        proc.stdin.write(renderer.render().tobytes())
                    proc.stdin.close()
                    if proc.wait():
                        raise RuntimeError("ffmpeg failed")
                movie.replace(out/movie.name)
        return dict(file=f"{name}.mp4", renderer=driver, command_fr=row["command_fr"], fps=25)
    except (ImportError, OSError, RuntimeError, AttributeError) as error:
        path = out/f"{name}.trace.json.gz"
        with gzip.open(path, "wt") as f:
            json.dump(dict(qpos_joints=[m.joint(j).name for j in range(m.njnt)],
                           qpos_adr=m.jnt_qposadr.tolist(), time_s=(np.arange(1,101)*5*DT).tolist(),
                           qpos=frames.round(7).tolist()), f)
        return dict(file=path.name, reason=str(error), command_fr=row["command_fr"], fps=25)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bodies", type=Path)
    parser.add_argument("--out", type=Path, default=Path(__file__).parent/"results/pilot")
    parser.add_argument("--workers", type=int, choices=range(1,7), default=4)
    parser.add_argument("--generations", type=int, choices=range(1,151), default=60, metavar="1..150")
    parser.add_argument("--evidence-only", action="store_true")
    args = parser.parse_args()
    bodies = json.loads(args.bodies.read_text())
    out = args.out
    out.mkdir(parents=True, exist_ok=True)
    if args.evidence_only:
        for name in PILOT:
            path = out/f"{name}.json"
            result = json.loads(path.read_text())
            desc = bodies[name]
            fingerprint = hashlib.sha256(json.dumps(desc, sort_keys=True).encode()).hexdigest()
            if result["morphology_sha256"] != fingerprint:
                raise ValueError(f"Morphology differs from saved fit for {name}")
            result["versions"] = {package: version(package) for package in ("mujoco", "numpy", "cma")}
            result["foot_order"] = [{"station": leg["station"], "side": leg["side"]}
                                    for leg in desc["analysis"]["legs"]]
            result["evidence"] = evidence(name, desc, result, out)
            save(path, result)
        return
    jobs = [(name,bodies[name],fr,190100+i*10+j,args.generations)
            for i,name in enumerate(PILOT) for j,fr in enumerate(SPEEDS)]
    results = {name: [] for name in PILOT}
    with ProcessPoolExecutor(args.workers, mp_context=mp.get_context("fork")) as pool:
        for name, row in pool.map(fit, jobs):
            results[name].append(row)
            if len(results[name]) == len(SPEEDS):
                desc = bodies[name]
                save(out/f"{name}.json", dict(body=name, plan=desc["analysis"]["plan"],
                     morphology_sha256=hashlib.sha256(json.dumps(desc,sort_keys=True).encode()).hexdigest(),
                     mass_kg=desc["analysis"]["mass"], hip_height_m=desc["analysis"]["hip_height"],
                     population=POP, duration_s=4, dt_s=DT, speeds=results[name]))
    # A fresh interpreter lets physics run even on hosts without any GL implementation.
    command = [sys.executable, __file__, str(args.bodies), "--out", str(out), "--evidence-only"]
    subprocess.run(command, check=True)


if __name__ == "__main__":
    main()
