// Creature skin, ported from SKIN_GLSL + skinMaterial() in web/creature/rig.js.
// CUSTOM0 carries the per-vertex "skin" vec4 (xyz pattern coordinate, w = back
// (+1) / belly (-1) weight). Define MEMBRANE (and MEMBRANE_STYLE 1 glider,
// 2 insect, 3 sac) before including for the thin-tissue variants.
uniform vec3 cA : source_color = vec3(0.533);
uniform vec3 cB : source_color = vec3(0.267);
uniform vec3 cC : source_color = vec3(0.8);
uniform float uPat = 1.0;
uniform float uWet = 0.3;
uniform float uScale = 7.0;
uniform float clearcoat_amount = 0.24;
uniform float clearcoat_rough = 0.4;
uniform float opacity = 1.0;
uniform float membrane_roughness = 0.94;
// World-space direction towards the sun (rig.js SUN).
uniform vec3 sun_dir = vec3(-0.62, 0.3, -0.72);

varying vec4 vSkin;

float h3(vec3 p){p=fract(p*.3183099+.1);p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float n3(vec3 x){vec3 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);return mix(mix(mix(h3(i),h3(i+vec3(1.,0.,0.)),f.x),mix(h3(i+vec3(0.,1.,0.)),h3(i+vec3(1.,1.,0.)),f.x),f.y),mix(mix(h3(i+vec3(0.,0.,1.)),h3(i+vec3(1.,0.,1.)),f.x),mix(h3(i+vec3(0.,1.,1.)),h3(i+vec3(1.,1.,1.)),f.x),f.y),f.z);}
vec2 wor(vec3 x){vec3 p=floor(x),f=fract(x);float a=8.,b=8.;for(int k=-1;k<=1;k++)for(int j=-1;j<=1;j++)for(int i=-1;i<=1;i++){vec3 g=vec3(float(i),float(j),float(k));vec3 o=vec3(h3(p+g),h3(p+g+17.3),h3(p+g+41.7));vec3 r=g+o-f;float d=dot(r,r);if(d<a){b=a;a=d;}else if(d<b){b=d;}}return sqrt(vec2(a,b));}
vec3 pN(vec3 sp,vec3 sn,vec2 dH){vec3 sx=dFdx(sp),sy=dFdy(sp),r1=cross(sy,sn),r2=cross(sn,sx);float det=dot(sx,r1);vec3 g=sign(det)*(dH.x*r1+dH.y*r2);return normalize(abs(det)*sn-g);}

void vertex() {
	vSkin = CUSTOM0;
}

void fragment() {
	vec3 rp = vSkin.xyz;
	float dd = vSkin.w, nn = n3(rp*1.3) + .5*n3(rp*2.9), mk = 0.;
	if (uPat > .5 && uPat < 1.5) mk = smoothstep(.42, .62, .5 + .5*sin(rp.z*4.6 + (nn - .75)*3.2));
	else if (uPat > 1.5 && uPat < 2.5) { vec2 w0 = wor(rp*1.5); mk = 1. - smoothstep(.2, .33, w0.x); }
	else if (uPat > 2.5) mk = smoothstep(.5, .72, nn*.66 + dd*.12);
	mk *= smoothstep(-.4, .2, dd);
	vec3 sk = mix(cA, cB, mk);
	sk = mix(sk, cC, 1. - smoothstep(-.85, -.2, dd));
	sk *= mix(1., .72, smoothstep(.7, 1., dd));
	vec2 w1 = wor(rp*uScale);
	float sh = smoothstep(0., .2, w1.y - w1.x);
	float bp = smoothstep(0., .45, w1.y - w1.x)*.007 + n3(rp*3.)*.015;
	sk *= mix(.7, 1., sh)*(.9 + .2*n3(rp*11.));
	vec3 view = normalize(-VERTEX);
#ifdef MEMBRANE
#if MEMBRANE_STYLE > 0
	sk = mix(sk, cC, .58);
#if MEMBRANE_STYLE == 2
	sk = mix(sk, mix(vec3(.14,.58,.7), vec3(.58,.3,.74), pow(1. - abs(dot(normalize(NORMAL), view)), 2.)), .42);
#endif
#else
	sk = mix(sk, cB, .35 + .15*n3(rp*5.5));
	sk = mix(sk, cC, .12)*.65;
#endif
	ROUGHNESS = membrane_roughness;
	ALPHA = opacity;
#else
	ROUGHNESS = clamp(mix(.82, .3, uWet)*mix(1.25, .9, sh), .06, 1.);
#endif
	ALBEDO = sk;
	vec3 n = pN(VERTEX, NORMAL, vec2(dFdx(bp), dFdy(bp)));
	NORMAL = n;
	vec3 em = sk*pow(1. - clamp(dot(view, n), 0., 1.), 3.)*.5;
#ifdef MEMBRANE
	vec3 Lw = normalize((VIEW_MATRIX*vec4(sun_dir, 0.)).xyz);
	float ndl = dot(n, Lw);
	float thru = pow(clamp(-ndl, 0., 1.), 1.2);
	float rim = pow(1. - abs(dot(view, n)), 2.4);
	em += sk*(thru*.65 + rim*.16);
#endif
	EMISSION = em;
	METALLIC = 0.;
	CLEARCOAT = clearcoat_amount;
	CLEARCOAT_ROUGHNESS = clearcoat_rough;
}
