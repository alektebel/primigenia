"""One stride generator for every commanded speed. Gait choice has no Fr thresholds."""
import numpy as np

from proxy import DT, G, leg_yaw

BOUNDS = {
    "duty_factor": (.20, .86), "relative_stride": (.6, 3.6),
    "swing_height_ratio": (.045, .30), "bounce_share": (0., 1.),
    "standing_hip_ratio": (.62, .96), "pitch_gain": (0., .14),
    "lean_gain": (0., .18), "spine_flex_rad": (.0, .14),
    "girdle_yaw_rad": (.0, .16), "neck_spring_gain": (.45, 1.8),
    "tail_spring_gain": (.45, 1.8), "sequence_offset": (-.11, .11),
    "lead_lag": (.04, .18), "gait": (0., 1.),
}


def gait_choices(plan):
    if plan == "quadruped":
        return ("walk", "trot", "gallop")
    if plan == "multi":
        return ("tripod", "ripple")
    return ("walk", "run")


def decode(x, plan):
    p = {k: float(lo + (hi-lo)*v) for (k, (lo, hi)), v in zip(BOUNDS.items(), x)}
    choices = gait_choices(plan)
    gait = choices[min(int(p["gait"]*len(choices)), len(choices)-1)]
    p["gait"] = gait
    # A walking template has overlapping support, a running template can have flight.
    lo, hi = {"walk": (.51,.86), "run": (.20,.50), "trot": (.26,.55),
              "gallop": (.18,.48)}.get(gait, (.40,.82))
    p["duty_factor"] = float(lo + x[0]*(hi-lo))
    return p


def targets(model, desc, p, fr):
    analysis = desc["analysis"]
    legs, h = analysis["legs"], analysis["hip_height"]
    speed = np.sqrt(fr*G*h)
    stride = p["relative_stride"]*h
    phase = np.arange(round(4/DT))*DT*(speed/stride)
    cycle = 2*np.pi*phase
    gait, duty = p["gait"], p["duty_factor"]
    ctrl = np.zeros((len(phase), model.nu))
    ctrl[:, 0] = speed

    def set_target(name, value):
        ctrl[:, model.actuator(name).id] = value

    spring = p["bounce_share"]
    bob = .038*h*(1-2*spring)*np.cos(2*cycle)
    pitch = p["pitch_gain"]*np.sin(2*cycle) + p["lean_gain"]*(speed/(speed+np.sqrt(G*h)))
    flex = p["spine_flex_rad"]*np.sin(cycle-.3*np.pi) if gait == "gallop" else np.zeros_like(phase)
    set_target("flex", flex)
    set_target("yaw", p["girdle_yaw_rad"]*np.sin(cycle))
    set_target("neck_pitch", -pitch-flex)
    if any(s["region"] == "tail" for s in desc["spine"]):
        set_target("tail_pitch", -pitch)
    reach_error = np.zeros_like(phase)
    for i, leg in enumerate(legs):
        st, right = leg["station"], int(leg["side"] < 0)
        offset = right*.5
        if gait == "gallop":
            offset = st*(.30+p["sequence_offset"]) + (1-right)*p["lead_lag"]
        elif gait in ("walk", "trot") and analysis["plan"] == "quadruped":
            offset += st*((.25 if gait == "walk" else .5) + p["sequence_offset"])
        elif gait == "tripod":
            offset += st*.5
        elif gait == "ripple":
            offset += st*.75/(1+max(l["station"] for l in legs))
        u = (phase-offset) % 1
        swing = np.clip((u-duty)/(1-duty), 0, 1)
        # Smooth reversing swing between the two ends of the planted stroke.
        travel = np.where(u < duty, duty/2-u, duty*(-.5+swing-np.sin(2*np.pi*swing)/(2*np.pi)))
        hip, home = leg["hip"], leg["home"]
        forward = home[2]-hip[2]+stride*travel
        lateral = home[0]-hip[0]
        if len(legs) == 2:
            # Bring the pelvis over the supporting foot during single support.
            track = abs(hip[0])
            lateral -= min(.14*h, track)*np.cos(cycle-np.pi*duty)
        down = (hip[1]-home[1]) - h*(1-p["standing_hip_ratio"]) + bob
        down -= h*p["swing_height_ratio"]*np.sin(np.pi*swing)**2
        yaw = leg_yaw(leg, h)
        forward, lateral = (np.cos(yaw)*forward + np.sin(yaw)*lateral,
                            -np.sin(yaw)*forward + np.cos(yaw)*lateral)
        sagittal = np.hypot(down, lateral)
        length = np.hypot(sagittal, forward)
        a, b = leg["upper"], leg["lower"]
        reach_error = np.maximum(reach_error, np.maximum(length-a-b, abs(a-b)-length)/h)
        knee = np.arccos(np.clip((length**2-a*a-b*b)/(2*a*b), -1, 1))
        if st > 0 and yaw == 0:  # forelimb elbow folds in the opposite direction
            knee = -knee
        angle = -np.arctan2(forward, sagittal)-np.arctan2(b*np.sin(knee), a+b*np.cos(knee))
        set_target(f"roll{i}", np.arctan2(lateral, down))
        set_target(f"hip{i}", angle-pitch*np.cos(yaw))
        set_target(f"knee{i}", knee)
        set_target(f"ankle{i}", -angle-knee)
    return ctrl, reach_error
