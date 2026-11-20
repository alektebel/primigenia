# Planning brief (Opus): realistic motion from morphology, and wings + flight
You PLAN; you do not write project code. Output: `/home/diego/Desarrollo/cpore-wt/_agent/briefs/motion-flight-plan.md`,
split into self-contained implementation slices (goal, files, method, acceptance + evidence, size, implementer: Sonnet
subagent for Godot work with screenshots, Codex for headless C/tools). Repo /home/diego/Desarrollo/cpore (main). You may run
read-only commands, render xvfb captures (software GL only, `timeout`, `nice -n 10`; never the GPU, the owner plays on it),
and consult other models. Two other tracks are already running: a procedural run gait by speed/Froude (branch loco-run-gait)
and running + fall damage in the C sim (Codex, c2/run-fall); build on them, don't duplicate.
The owner's words:
1. "Procedural animation is still a little clumsy. Should we train something as an RL algorithm policy so that the creature
   learns to move realistically? What do you think. For a morphology, predict its optimal movement."
   Give a reasoned recommendation: RL per morphology vs offline optimisation (CMA-ES/trajectory optimisation of CPG/gait
   parameters in a cheap physics proxy) distilled into a fast predictor (morphology features → gait parameters) that drives
   the procedural rig at runtime; cost, compute on an RTX 5060 laptop, determinism (the C sim owns positions; animation is
   visual), how to evaluate "realistic" (foot sliding, energy, Froude similarity, comparison to animal data). Plan the version
   you recommend.
2. "Is Merodeador perhaps too big for an initial game?" Recommend the starter creature size/body (Spore starts tiny); effects
   on camera, speed, props scale, combat balance.
3. "Give the creature wings, I want to test flying as well now. Design wings using the council, and use perhaps the Idol model
   from Sperid Labs to actually get the 3D mesh."
   a) Run the council: ask at least two other model families for wing designs (e.g. `cd /tmp && codex exec --skip-git-repo-check
      -m gpt-6.1-sol -s read-only "<question>" < /dev/null`, and `-m gpt-6.2-astra`; also see tools/lore/council/), covering
      wing types that fit our biology (membrane/patagium, feather-analog keratin vanes, insect-like rigid wings, gliding flaps),
      how each attaches to our skeleton/genome (`cpore.creature/5` parts, A24 actuation), flapping kinematics, and creator
      controls. Synthesise; record who said what.
   b) Idol: it exists on branch `idol` (worktree /home/diego/Desarrollo/cpore-wt/idol); its README records that inference
      failed on a gated upstream encoder. Say honestly whether Idol (single photo → Gaussian splat) is a good fit for wing
      parts that must stay editable and procedural, what the owner would have to do to unblock it, and the alternative
      (procedural wing mesh from the genome).
   c) Flight: a test mode now (owner wants to try it): glide → flap → land, stamina, takeoff from height/run, camera, controls,
      fall damage interplay; where it lives (Godot-side test mode first vs the C sim, which owns positions and determinism),
      and the path to C4/C5 (gliding with dive attacks, full flight).
Read first: docs/godot/LOCOMOTION.md, docs/DESIGN.md (A24, G73), docs/CREATURE-ROADMAP.md, godot/locomotion/*, godot/creature/*,
godot/studio/*. ≤ 300 lines, owner decisions at the end with your recommendation.
