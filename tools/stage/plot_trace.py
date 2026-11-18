#!/usr/bin/env python3
"""SVG top-down plot of steer_trace outputs: plot_trace.py out.svg label=trace.txt [label=trace.txt ...]"""
import sys
out=sys.argv[1]
cols=["#d33","#36c","#2a2","#c80","#808","#088"]
series=[]
for a in sys.argv[2:]:
    label,path=a.rsplit("=",1)
    pts=[tuple(map(float,l.split()[1:3])) for l in open(path) if l.strip()]
    series.append((label,pts))
xs=[p[0] for _,s in series for p in s];zs=[p[1] for _,s in series for p in s]
x0,x1,z0,z1=min(xs)-3,max(xs)+3,min(zs)-3,max(zs)+3
sc=min(900/(x1-x0),700/(z1-z0))
W=int((x1-x0)*sc)+20;H=int((z1-z0)*sc)+60
def P(p):return (10+(p[0]-x0)*sc,H-30-(p[1]-z0)*sc)
o=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" font-family="sans-serif" font-size="13"><rect width="100%" height="100%" fill="white"/>']
g=5
v=int(x0//g)*g
while v<=x1:
    a=P((v,z0));b=P((v,z1));o.append(f'<line x1="{a[0]:.0f}" y1="{a[1]:.0f}" x2="{b[0]:.0f}" y2="{b[1]:.0f}" stroke="#eee"/>');v+=g
v=int(z0//g)*g
while v<=z1:
    a=P((x0,v));b=P((x1,v));o.append(f'<line x1="{a[0]:.0f}" y1="{a[1]:.0f}" x2="{b[0]:.0f}" y2="{b[1]:.0f}" stroke="#eee"/>');v+=g
for i,(label,pts) in enumerate(series):
    c=cols[i%len(cols)]
    d=" ".join(f"{P(p)[0]:.1f},{P(p)[1]:.1f}" for p in pts)
    o.append(f'<polyline points="{d}" fill="none" stroke="{c}" stroke-width="2"/>')
    for k in range(0,len(pts),10):
        q=P(pts[k]);o.append(f'<circle cx="{q[0]:.1f}" cy="{q[1]:.1f}" r="2.5" fill="{c}"/>')
    o.append(f'<text x="14" y="{20+i*18}" fill="{c}">{label}</text>')
o.append('<text x="14" y="%d" fill="#555">top-down, metres (grid 5 m), dots every 1 s</text></svg>'%(H-8))
open(out,"w").write("\n".join(o))
