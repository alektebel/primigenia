"""Score a complete four-second MuJoCo rollout from measured forces and motion."""
import mujoco
from mujoco import rollout
import numpy as np

from gait_ref import targets
from proxy import build, DT, G


class Trial:
    def __init__(self, desc):
        self.desc = desc
        self.m = build(desc)
        self.d = mujoco.MjData(self.m)
        self.joints = self.m.actuator_trnid[:, 0]
        self.angles = self.m.jnt_qposadr[self.joints]
        self.velocities = self.m.jnt_dofadr[self.joints]
        self.gains = self.m.actuator_gainprm[:, 0].copy()
        self.damping = self.m.actuator_biasprm[:, 2].copy()
        self.spring_ids = {}
        for part in ("neck", "tail"):
            actuator_id = mujoco.mj_name2id(self.m, mujoco.mjtObj.mjOBJ_ACTUATOR, part+"_pitch")
            if actuator_id >= 0:
                self.spring_ids[part] = actuator_id
        self.foot_start = self.m.sensor("foot0").adr[0]
        self.force_start = self.m.sensor("force_guide").adr[0]
        self.ground_start = self.m.sensor("ground_force").adr[0]

    def run(self, p, fr, replay=False):
        m, d = self.m, self.d
        h = self.desc["analysis"]["hip_height"]
        mass = self.desc["analysis"]["mass"]
        ctrl, reach = targets(m, self.desc, p, fr)
        for key, i in self.spring_ids.items():
            gain = p[key+"_spring_gain"]
            m.actuator_gainprm[i, 0] = self.gains[i]*gain
            m.actuator_biasprm[i, 1] = -self.gains[i]*gain
            m.actuator_biasprm[i, 2] = self.damping[i]*np.sqrt(gain)
        mujoco.mj_resetData(m, d)
        d.qpos[self.angles[1:]] = ctrl[0, 1:]
        d.qpos[2] = -h*(1-p["standing_hip_ratio"])
        d.qvel[0] = speed = ctrl[0, 0]
        d.qvel[self.velocities[1:]] = (ctrl[1,1:]-ctrl[0,1:])/DT
        # Position actuators apply kp*(target-q) - kd*qdot. Offset their controls
        # to obtain the matching +kd*target_velocity feed-forward term.
        kd_over_kp = -m.actuator_biasprm[1:, 2]/m.actuator_gainprm[1:, 0]
        ctrl[:,1:] += np.gradient(ctrl[:,1:], DT, axis=0)*kd_over_kp
        initial = np.r_[0., d.qpos, d.qvel]
        states, sensors = rollout.rollout(m, d, initial, control=ctrl)
        states, sensors = states[0], sensors[0]
        if not np.isfinite(states).all() or states[-1, 0] < 4-1e-7:
            if replay:
                raise ValueError("Selected trial diverged")
            return {"total": 1e9, "diverged": True}
        # Sensors use the state at the beginning of each integration step.
        qpos = states[:, 1:1+m.nq]
        v = np.vstack([initial[1+m.nq:], states[:-1, 1+m.nq:]])[:, self.velocities]
        start = self.force_start
        force = sensors[:, start:start+m.nu]
        power = force*v
        work = np.maximum(power[:, 1:], 0).sum()*DT
        guide = np.abs(power[:, 0]).sum()*DT
        distance = qpos[-1, 0]
        normalizer = mass*G*max(distance, .01*h)
        feet = sensors[:, self.foot_start:start].reshape(len(states), -1, 7)
        stance = (feet[:, :, 0] > 0) & (feet[:, :, 1] > .001*mass*G)
        slip = np.linalg.norm(feet[:, :, 5:7], axis=2)*stance*DT
        slips = []
        for touching, sliding in zip(stance.T, slip.T):
            changes = np.flatnonzero(np.diff(np.r_[False, touching, False]))
            slips.extend(sliding[a:b].sum() for a,b in changes.reshape(-1,2))
        ground_z = np.maximum(sensors[:, self.ground_start+2], 0.)
        foot_z = np.maximum(feet[:, :, 1], 0.).sum(axis=1)
        nonfoot_share = np.maximum(ground_z-foot_z, 0.).sum()/max(ground_z.sum(), 1e-9)
        peak_force = ground_z.max()/(mass*G)
        # Average head heights over 40 ms bins before differencing to limit contact chatter.
        head = sensors[:, 3].reshape(-1, 5).mean(axis=1)
        jerk = np.sqrt(np.mean((np.diff(head, n=3)/(.04**3))**2))
        tilt_cos = 1-2*(qpos[:,4]**2+qpos[:,5]**2)  # ball quaternion w,x,y,z
        fallen = (h+qpos[:,2] < .40*h) | (tilt_cos < .55)
        grounded = sensors[:, start+m.nu:self.ground_start].any(axis=1)
        fallen |= grounded
        collision = sensors[:,0] > 0
        achieved = distance/4
        terms = {
            "transport": work/normalizer, "guide": 5*guide/normalizer,
            "slip": 3*slip.sum()/(len(stance.T)*max(distance,.01*h)),
            "torque": .25*np.mean((force[:,1:]/m.actuator_forcerange[1:,1])**2),
            "impact": .08*max(0., peak_force-2)**2,
            "head_jerk": .002*jerk*np.sqrt(h/G)/G,
            "nonfoot_support": 30*nonfoot_share**2,
            "speed_error": 15*np.mean((v[:,0]/speed-1)**2),
            "fall": 100*float(fallen.any())+100*fallen.mean(),
            "reach": (50+200*reach.max()) if reach.max() > 1e-5 else 0.,
            "self_collision": 50*float(collision.any())+50*collision.mean(),
        }
        infeasible = fallen.any() or collision.any() or reach.max() > 1e-5 or nonfoot_share > .5
        terms["infeasible"] = 10000.0*float(infeasible)
        cot = work/(mass*distance) if distance > 0 else None
        taylor = 10.7*mass**-.316
        report = dict(total=sum(terms.values()), cost=terms, distance_m=distance,
                      command_m_s=speed, achieved_m_s=achieved, command_fr=fr,
                      achieved_fr=achieved**2/(G*h) if achieved>0 else None,
                      duty_measured=stance.mean(), duty_by_foot=stance.mean(axis=0).tolist(),
                      max_stance_slip_m=max(slips, default=0.), stances=len(slips),
                      guide_work_j=guide, positive_work_j=work,
                      guide_fraction=guide/(work+guide) if work+guide else None,
                      mechanical_cot_j_kg_m=cot, taylor_j_kg_m=taylor,
                      cot_ratio=cot/taylor if cot is not None else None,
                      nonfoot_load_fraction=nonfoot_share, peak_force_bodyweights=peak_force, head_jerk_m_s3=jerk,
                      head_excursion_m=np.ptp(head), com_excursion_m=np.ptp(sensors[:,6]),
                      peak_com_vertical_accel_g=np.max(np.abs(np.diff(sensors[:,6],n=2)))/(DT**2*G),
                      fell=bool(fallen.any()), self_collision=bool(collision.any()),
                      max_reach_excess_m=reach.max()*h)
        if replay:
            times = np.arange(len(stance))*DT
            touchdowns = [times[1:][foot[1:] & ~foot[:-1]] for foot in stance.T]
            # Where each foot actually carries vertical load within the reference cycle.
            # The circular mean withstands repeated touch/lift events within one stance.
            phase = times*speed/(p["relative_stride"]*h)
            normal = np.maximum(feet[:, :, 1], 0.)
            impulse = normal.sum(axis=0)
            moment = (np.exp(2j*np.pi*phase)[:, None]*normal).sum(axis=0)
            report["load_phase_cycles"] = [
                float(np.angle(z)/(2*np.pi) % 1) if w > 0 else None
                for z,w in zip(moment, impulse)]
            report["load_phase_concentration"] = (np.abs(moment)/np.maximum(impulse, 1e-12)).tolist()
            # Contact sensors precede the corresponding post-step root positions.
            root_x = np.r_[initial[1], qpos[:-1,0]]
            strides = [np.diff(np.interp(t, times, root_x))/h for t in touchdowns]
            lengths = np.concatenate(strides)
            report["measured_relative_stride"] = float(np.median(lengths)) if lengths.size else None
            report["trunk_excursion_m"] = float(np.ptp(qpos[:,2]))
            report["touchdowns_s"] = [t.round(3).tolist() for t in touchdowns]
            return report, qpos
        return report
