"""Build an articulated, unconstrained 3-D capsule proxy from a Godot description."""
from math import pi
from xml.etree import ElementTree as ET

import mujoco
import numpy as np

DT = 0.008
G = 9.81


def xyz(godot):
    return np.asarray(godot)[[2, 0, 1]]  # forward, left, up


def vec(v):
    return " ".join(f"{x:.12g}" for x in v)


def leg_yaw(leg, height):
    spread = leg["home"][0] - leg["hip"][0]
    return np.sign(spread)*pi/2 if abs(spread) > .5*height else 0.


def build(desc):
    analysis = desc["analysis"]
    mass, h = analysis["mass"], analysis["hip_height"]
    density = desc.get("density", 1000)
    xml = ET.Element("mujoco")
    add = ET.SubElement
    add(xml, "compiler", angle="radian")
    add(xml, "option", timestep=str(DT), integrator="implicitfast", iterations="25")
    assets = add(xml, "asset")
    add(assets, "texture", name="checks", type="2d", builtin="checker", width="64", height="64",
        rgb1=".37 .44 .39", rgb2=".45 .51 .45")
    add(assets, "material", name="ground", texture="checks", texuniform="true",
        texrepeat=vec([1/h, 1/h]), reflectance="0")
    world = add(xml, "worldbody")
    add(world, "light", pos="0 -3 6", dir="0 0.4 -1")
    add(world, "geom", name="floor", type="plane", size="0 0 0.1", material="ground")
    root = add(world, "body", name="trunk", pos=vec([0, 0, h]))
    for axis, name in zip(np.eye(3), ["forward", "side", "up"]):
        add(root, "joint", name=name, type="slide", axis=vec(axis))
    add(root, "joint", name="attitude", type="ball")
    actuators = add(xml, "actuator")
    add(actuators, "velocity", name="guide", joint="forward", kv=str(mass * 1.5),
        forcerange=vec([-0.18 * mass * G, 0.18 * mass * G]))
    sensors = add(xml, "sensor")
    add(sensors, "contact", name="collision", subtree1="trunk", subtree2="trunk", data="found")
    add(sensors, "framepos", name="head_pos", objtype="site", objname="head")
    add(sensors, "subtreecom", name="com", body="trunk")
    contact = add(xml, "contact")
    origins = {"trunk": np.array([0., 0., h])}
    bodies = {"trunk": root}

    def body(name, parent, origin):
        origins[name] = origin
        bodies[name] = add(bodies[parent], "body", name=name, pos=vec(origin - origins[parent]))

    def hinge(owner, name, axis, strength):
        limit = strength * mass ** 0.67
        kp = 6 * limit
        add(bodies[owner], "joint", name=name, axis=vec(axis),
            armature=str(0.003 * limit * h / G))
        add(actuators, "position", name=name, joint=name, kp=str(kp),
            kv=str(0.18 * kp * (h / G) ** 0.5), forcerange=vec([-limit, limit]))

    spine = desc["spine"]
    points = [xyz(s["pos"]) for s in spine]
    split = max(1, min(len(points)-2, len(points)//2))
    body("girdle", "trunk", points[split])
    hinge("girdle", "flex", [0, 1, 0], 9)
    hinge("girdle", "yaw", [0, 0, 1], 6)
    neck = next((i for i in range(split, len(points)-1)
                 if spine[i+1]["region"] in ("neck", "head")), len(points)-2)
    body("neck", "girdle", points[neck])
    hinge("neck", "neck_pitch", [0, 1, 0], 5)
    tail_end = min(split, sum(s["region"] == "tail" for s in spine))
    if tail_end:
        body("tail", "trunk", points[tail_end])
        hinge("tail", "tail_pitch", [0, 1, 0], 5)
    # Adjacent anatomical spine regions overlap at their capsule ends.
    owners = []
    for i, (a, b) in enumerate(zip(points, points[1:])):
        owner = ("tail" if i < tail_end else "neck" if i >= neck else
                 "girdle" if i >= split else "trunk")
        owners.append(owner)
        r, s = spine[i]["radius"], spine[i+1]["radius"]
        weight = density * pi / 3 * np.linalg.norm(a-b) * (r*r + r*s + s*s)
        if i == 0:
            weight += density * 2*pi/3 * r**3
        if i == len(points)-2:
            weight += density * 2*pi/3 * s**3
        add(bodies[owner], "geom", type="capsule", size=str((r+s)/2),
            fromto=vec(np.r_[a-origins[owner], b-origins[owner]]),
            mass=str(weight), rgba=".32 .55 .63 1")
    # Tiny inertia at an articulation that carries no segment (short insect spines).
    for name in bodies:
        if name not in owners:
            add(bodies[name], "geom", size=str(.012*h), mass=str(.0001*mass),
                contype="0", conaffinity="0")
    axial = list(bodies)
    for i, name in enumerate(axial):
        for other in axial[:i]:
            add(contact, "exclude", body1=name, body2=other)
    add(bodies["neck"], "site", name="head", pos=vec(points[-1]-origins["neck"]), size=str(.02*h))
    for p in desc["parts"]:
        pos = xyz(p["pos"])
        idx = np.argmin([np.linalg.norm(pos-(a+b)/2) for a,b in zip(points,points[1:])])
        owner = owners[idx]
        add(bodies[owner], "geom", size=str(.025*h), pos=vec(pos-origins[owner]),
            mass=str(p["mass"]), contype="0", conaffinity="0")
    for i, leg in enumerate(analysis["legs"]):
        hip = xyz(leg["hip"])
        owner = "girdle" if leg["station"] > 0 and hip[0] >= points[split][0] else "trunk"
        upper, lower = f"thigh{i}", f"shin{i}"
        body(upper, owner, hip)
        bodies[upper].set("euler", vec([0, 0, leg_yaw(leg, h)]))
        hinge(upper, f"roll{i}", [1, 0, 0], 8)
        hinge(upper, f"hip{i}", [0, 1, 0], 12)
        knee = hip - [0, 0, leg["upper"]]
        body(lower, upper, knee)
        hinge(lower, f"knee{i}", [0, 1, 0], 10)
        for region in axial:
            add(contact, "exclude", body1=upper, body2=region)
        for name, length, scale, color in [(upper, leg["upper"], .9, ".82 .61 .40 1"),
                                            (lower, leg["lower"], .675, ".72 .48 .30 1")]:
            radius = leg["radius"]*scale
            add(bodies[name], "geom", type="capsule", size=str(radius),
                fromto=vec([0, 0, 0, 0, 0, -length]), rgba=color,
                mass=str(density*pi*radius**2*length))
        # Trim the shin collision end above a thin sole.
        shin = bodies[lower].find("geom")
        end = max(.5*leg["lower"], leg["lower"] - max(0, radius-leg["ankle"]))
        shin.set("fromto", vec([0, 0, 0, 0, 0, -end]))
        foot = f"foot{i}"
        radius = leg["foot_radius"]
        body(foot, lower, knee - [0, 0, leg["lower"]])
        hinge(foot, f"ankle{i}", [0, 1, 0], 4)
        add(bodies[foot], "geom", name=foot, type="ellipsoid",
            size=vec([radius, .75*radius, leg["ankle"]]),
            mass=str(density*4*pi/3*radius**3*.6), rgba=".28 .24 .22 1")
        add(sensors, "contact", name=foot, geom1="floor", geom2=foot,
            data="found force linvel", reduce="maxforce")
    for actuator in actuators:
        add(sensors, "actuatorfrc", name="force_" + actuator.get("name"), actuator=actuator.get("name"))
    for region in axial:
        add(sensors, "contact", name="ground_"+region, body1=region, geom2="floor", data="found")
    add(sensors, "contact", name="ground_force", geom1="floor", subtree2="trunk",
        data="force", reduce="netforce")
    model = mujoco.MjModel.from_xml_string(ET.tostring(xml, encoding="unicode"))
    mujoco.mj_setTotalmass(model, mass)
    mujoco.mj_setConst(model, mujoco.MjData(model))
    return model
