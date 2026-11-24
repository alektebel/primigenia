"""T0 spike for the jungle look study: grows crooked, multi-stemmed cloud-forest trees as woody skeletons in Blender and exports one GLB
(web/gaitlab/forest_assets/trees.glb) plus trees.json (crown clump anchors and limb points for the lab's leaf cards, hanging moss, vines).
  blender --background --python tools/forest/grow_trees.py -- web/gaitlab/forest_assets
Each tree is a recursive growth (stems fork low, limbs leave at 40-85 degrees from vertical, sub-limbs and twigs, random-walk crook plus
phototropism, pipe-model radii). Wood only: leaves are cards placed in the browser on the exported clump anchors. Vertex colour RGB is the bark
tint, ALPHA is the moss mask (up-facing, thick and low wood), which the lab turns into moss per version. Two LODs per variant (L0 8 sides with
twigs, L1 5 sides without twigs). Pure bpy/bmesh, deterministic per seed."""
import bpy, bmesh, math, random, json, sys, os
from mathutils import Vector

OUT = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else '.'
KINDS = {
  # n variants, H range, stems, base radius (m), first limb height, limb length, limb spacing, crook, limb up-angle from vertical (deg), buttress
  'laurel':  dict(n=5, H=(13, 19), stems=(1, 3), r=(.24, .42), fb=(2.6, 4.2), ll=(3.2, 6.8), sp=(1.4, 2.1), crook=.2, ang=(48, 86), butt=.35),
  'crooked': dict(n=3, H=(8.5, 12), stems=(2, 4), r=(.14, .26), fb=(2.6, 3.4), ll=(2.6, 5.4), sp=(1.1, 1.7), crook=.38, ang=(40, 88), butt=.2),
  'tall':    dict(n=3, H=(19, 25), stems=(1, 1), r=(.28, .4), fb=(9, 13), ll=(3.4, 5.6), sp=(1.0, 1.5), crook=.06, ang=(35, 62), butt=.7),
  'giant':   dict(n=2, H=(26, 32), stems=(1, 1), r=(.7, 1.0), fb=(12, 16), ll=(6, 9.5), sp=(1.5, 2.1), crook=.05, ang=(35, 65), butt=1.4),
  'small':   dict(n=3, H=(5, 8), stems=(1, 2), r=(.07, .12), fb=(2.4, 3.2), ll=(1.6, 3.0), sp=(1.0, 1.5), crook=.28, ang=(45, 85), butt=.1),
  'sap':     dict(n=3, H=(3.2, 6), stems=(1, 2), r=(.025, .045), fb=(99, 99), ll=(0, 0), sp=(9, 9), crook=.18, ang=(40, 70), butt=0),
}

def grow(kind, vi, seed):
    K = KINDS[kind]; R = random.Random(seed)
    H = R.uniform(*K['H']); nst = R.randint(*K['stems']); r0 = R.uniform(*K['r']); fb = R.uniform(*K['fb'])
    branches = []   # (nodes, radii, depth)
    clumps = []; limbpts = []

    def walk(p, d, length, ra, rb, depth, crook, step, up=0.0, droop=0.0):
        d = d.normalized(); nodes = [p.copy()]; radii = [ra]; w = Vector((0, 0, 0)); n = max(2, int(length / step))
        for i in range(n):
            t = (i + 1) / n
            w += Vector((R.gauss(0, crook), R.gauss(0, crook), R.gauss(0, crook * .5)))
            w *= .8
            d = (d + w * .22 + Vector((0, 0, up - droop * t))).normalized()
            p = p + d * step
            nodes.append(p.copy()); radii.append(ra + (rb - ra) * t)
        return nodes, radii

    stems = []
    for s in range(nst):
        ang = R.uniform(0, 6.283); fh = 0 if s == 0 else R.uniform(.3, 1.8)
        lean = math.radians(R.uniform(4, 10) if s == 0 else R.uniform(14, 32))
        d = Vector((math.sin(lean) * math.cos(ang), math.sin(lean) * math.sin(ang), math.cos(lean)))
        p = Vector((R.gauss(0, .12) * (s > 0), R.gauss(0, .12) * (s > 0), 0 if s == 0 else fh * .3))
        ra = r0 * (1 if s == 0 else R.uniform(.55, .8)); length = H * (R.uniform(.88, 1.0) if s == 0 else R.uniform(.6, .85))
        nodes, radii = walk(p, d, length, ra, max(.03, ra * .16), 0, K['crook'], .5, up=.012)
        stems.append((nodes, radii)); branches.append((nodes, radii, 0))
        # limbs
        z0 = nodes[0].z; first = fb if kind != 'sap' else 99
        h = first + R.uniform(0, .6); k = R.uniform(0, 6.28)
        while h < nodes[-1].z - 1.0 and K['ll'][1] > 0:
            i = min(range(len(nodes)), key=lambda j: abs(nodes[j].z - h))
            f = h / max(1, nodes[-1].z); k += 2.399 + R.uniform(-.5, .5)
            a = math.radians(R.uniform(*K['ang']) - 18 * f)   # upper limbs rise more
            ld = Vector((math.sin(a) * math.cos(k), math.sin(a) * math.sin(k), math.cos(a)))
            prof = max(.4, math.sin(math.pi * min(1, .15 + .85 * f * 1.0)))
            L = R.uniform(*K['ll']) * prof * (1.0 if kind != 'small' else .8)
            rl = max(.04, radii[i] * R.uniform(.38, .55))
            ln, lr = walk(nodes[i], ld, L, rl, max(.02, rl * .12), 1, K['crook'] * 1.2, .45, up=.02, droop=.05 if L > 4 else 0)
            branches.append((ln, lr, 1))
            for q in range(1, len(ln), 2): limbpts.append(ln[q].copy())
            # sub-limbs and twigs
            for sub in range(R.randint(1, 3)):
                j = R.randint(max(1, len(ln) // 3), len(ln) - 1); sa = k + R.uniform(-1.4, 1.4)
                sd = Vector((math.cos(sa) * .8, math.sin(sa) * .8, R.uniform(.1, .6)))
                sl, sr = walk(ln[j], sd, L * R.uniform(.3, .5), max(.025, lr[j] * .55), .015, 2, K['crook'] * 1.4, .35, up=.03)
                branches.append((sl, sr, 2))
                for q in range(0, len(sl), 2): clumps.append((sl[q].x, sl[q].y, sl[q].z, R.uniform(.9, 1.5)))
                for tw in range(R.randint(1, 2)):
                    jj = R.randint(0, len(sl) - 1); ta = R.uniform(0, 6.28)
                    tl, trr = walk(sl[jj], Vector((math.cos(ta), math.sin(ta), R.uniform(0, .6))), R.uniform(.9, 1.6), .016, .008, 3, .3, .25, up=.04)
                    branches.append((tl, trr, 3))
            for q in range(1, len(ln), 2 if kind in ('laurel', 'tall', 'giant') else 1): clumps.append((ln[q].x, ln[q].y, ln[q].z + .2, R.uniform(.9, 1.4)))
            clumps.append((ln[-1].x, ln[-1].y, ln[-1].z + .2, R.uniform(1.0, 1.6)))
            h += R.uniform(*K['sp'])
        top = nodes[-1]
        clumps.append((top.x, top.y, top.z + .3, R.uniform(1.0, 1.6)))
        if kind in ('small', 'sap'):
            for q in range(max(1, len(nodes) // 3), len(nodes)): clumps.append((nodes[q].x + R.gauss(0, .3), nodes[q].y + R.gauss(0, .3), nodes[q].z, R.uniform(.55, .9)))
    return dict(branches=branches, clumps=clumps, limbpts=limbpts, H=H, r0=r0, fb=fb, K=K, stems=stems)

def build(name, tree, lod, K, R):
    bm = bpy.context.scene  # noqa
    mesh = bpy.data.meshes.new(name); bmx = bmesh.new()
    uvl = bmx.loops.layers.uv.new('UVMap'); col = bmx.loops.layers.color.new('Col')
    sides = 8 if lod == 0 else 5
    fins = R.choice([4, 5, 6]); fin0 = R.uniform(0, 6.28)
    for bi, (nodes, radii, depth) in enumerate(tree['branches']):
        if lod == 1 and depth >= 3: continue
        if lod == 1 and depth == 2 and bi % 2: continue
        sd = sides if depth < 2 else max(4, sides - 3)
        rings = []; length = 0
        for i, (p, r) in enumerate(zip(nodes, radii)):
            t = nodes[min(i + 1, len(nodes) - 1)] - nodes[max(i - 1, 0)]
            if t.length < 1e-6: t = Vector((0, 0, 1))
            t.normalize()
            ref = Vector((0, 0, 1)) if abs(t.z) < .95 else Vector((1, 0, 0))
            u = (ref - t * ref.dot(t)).normalized(); v = t.cross(u)
            if i > 0: length += (p - nodes[i - 1]).length
            ring = []
            for s in range(sd):
                th = 2 * math.pi * s / sd
                rr = r
                if depth == 0 and bi == 0 or (depth == 0 and tree['K']['butt'] > .5):
                    fin = max(0, math.cos(fins * (th + fin0))) ** 2.4
                    rr = r * (1 + K['butt'] * math.exp(-p.z / 1.6) * fin) * (1 + .25 * math.exp(-p.z / .8))
                d = u * math.cos(th) + v * math.sin(th)
                ring.append((bmx.verts.new(p + d * rr), d, th, length))
            rings.append(ring)
        for i in range(len(rings) - 1):
            for s in range(sd):
                a = rings[i][s]; b = rings[i][(s + 1) % sd]; c = rings[i + 1][(s + 1) % sd]; d_ = rings[i + 1][s]
                try:
                    f = bmx.faces.new((a[0], b[0], c[0], d_[0]))
                except ValueError:
                    continue
                for lp, (vv, dd, th, ln) in zip(f.loops, (a, b, c, d_)):
                    uu = th / (2 * math.pi) * (1 if s < sd - 1 or True else 1)
                    lp[uvl].uv = (uu, ln * .4)
                    # bark tint, moss mask in alpha: up-facing, thick and low wood carries moss
                    up = max(0.0, dd.z) if abs(dd.z) < 1 else 0.0
                    wr = vv.co  # noqa
                    m = min(1.0, .22 + .85 * up + (.25 if depth == 0 else 0) - .06 * depth)
                    m *= .55 + .45 * (math.sin(ln * 1.3 + th * 2 + bi) * .5 + .5)
                    lp[col] = (.30 + .05 * R.random(), .26, .22, max(0.0, min(1.0, m)))
        # cap tip
    bmesh.ops.recalc_face_normals(bmx, faces=bmx.faces[:])
    bmx.to_mesh(mesh); bmx.free()
    for p in mesh.polygons: p.use_smooth = True
    obj = bpy.data.objects.new(name, mesh); bpy.context.collection.objects.link(obj)
    return obj

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    meta = {}; R0 = random.Random(2024)
    for kind, K in KINDS.items():
        for vi in range(K['n']):
            seed = hash((kind, vi)) & 0xffff if False else (sum(map(ord, kind)) * 131 + vi * 977)
            tr = grow(kind, vi, seed); Rb = random.Random(seed + 5)
            for lod in (0, 1):
                build('%s%d_L%d' % (kind, vi, lod), tr, lod, K, random.Random(seed + 5))
            toY = lambda x, y, z: [round(x, 2), round(z, 2), round(-y, 2)]
            main_r = max(st[1][0] for st in tr['stems'])
            meta['%s%d' % (kind, vi)] = dict(H=round(tr['H'], 2), dbh=round(2 * main_r, 3), firstBr=round(tr['fb'], 2),
                clumps=[toY(c[0], c[1], c[2]) + [round(c[3], 2)] for c in tr['clumps']],
                limb=[toY(p.x, p.y, p.z) for p in tr['limbpts'][:60]], stems=len(tr['stems']))
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'trees.glb'), export_format='GLB', export_apply=True, export_yup=True,
                              export_materials='NONE', export_normals=True, export_texcoords=True, export_cameras=False, export_lights=False,
                              export_vertex_color='ACTIVE', export_active_vertex_color_when_no_material=True)
    json.dump(meta, open(os.path.join(OUT, 'trees.json'), 'w'), separators=(',', ':'))
    print('trees', len(meta), 'clumps', sum(len(m['clumps']) for m in meta.values()))
main()
