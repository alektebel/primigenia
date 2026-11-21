// Creature skin, ported from SKIN_GLSL + skinMaterial() in web/creature/rig.js.
// CUSTOM0 carries the per-vertex "skin" vec4 (xyz pattern coordinate, w = back
// (+1) / belly (-1) weight). Define MEMBRANE (and MEMBRANE_STYLE 1 glider,
// 2 insect, 3 sac) before including for the thin-tissue variants.
uniform vec3 cA : source_color = vec3(0.533);
uniform vec3 cB : source_color = vec3(0.267);
uniform vec3 cC : source_color = vec3(0.8);
uniform float uPat = 1.0;
uniform float uWet = 0.3;
global uniform float moon_k;      // 0 day .. 1 night, set by day_night.gd (skin v1: moonlight response)
uniform float uScale = 7.0;
uniform float clearcoat_amount = 0.24;
uniform float clearcoat_rough = 0.4;
uniform float opacity = 1.0;
uniform float membrane_roughness = 0.94;
// World-space direction towards the sun (rig.js SUN).
uniform vec3 sun_dir = vec3(-0.62, 0.3, -0.72);

// ---- realism pilot (docs/godot/CREATURE-REALISM.md). realism = 0 renders the pre-pilot look.
uniform float realism = 1.0;
uniform sampler2D turing : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float tur_tile = 4.0;      // metres per texture tile (physical, relative to body size)
uniform float tur_kind = 0.0;      // 0 mottle only, 1 stripes, 2 spots, 3 blotches
uniform float tur_ros = 0.0;
uniform float cs = 0.5;            // countershading amount (creator slider)
uniform float pc = 1.0;            // pattern contrast (creator slider)       // 1: spots become rosettes
uniform float use_uv = 0.0;        // 1 on the body tube: UV = (arc along spine, arc around) in metres
uniform float body_r = 0.6;        // typical body radius, the detail scale is relative to it
uniform vec4 snout = vec4(0.0, 0.0, 0.0, 0.0); // xyz head tip (body rest space), w wet radius; w = 0 off
uniform float thin_default = 0.35; // skin thickness of meshes without tube data (parts, legs)
uniform float sss = 0.45;          // fake subsurface strength
uniform float wrinkle = 0.35;
uniform float scale_amt = 1.0;     // scales / plates detail amount
uniform float act_mode = 1.0;      // 1 muscle, 2 hydraulic, 3 exoskeleton, 4 hydrostatic
uniform float leg_mode = 1.0;      // actuation of this limb: 1 muscle, 2 hydraulic, 3 muscle in exo, 4 hydrostat, 5 tendon, 6 spring, 7 tube feet
uniform float leg_part = 0.0;      // 1 upper leg, 2 lower leg (limb material copies only)
uniform float seg_len = 1.0;       // limb segment length
uniform float flex = 0.0;          // knee bend 0..1, swells muscle
uniform float seg_rings = 9.0;     // exoskeleton segments along the body
uniform float act_phase = 0.0;
uniform float breathe = 1.0;
uniform float tube_feet = 0.0;     // radial arms: sucker dots on the undersides (body tube with use_uv)
uniform float gel = 0.0;           // radial jellies (GEL defined by skin_gel.gdshader): translucency, wrap light, rim
uniform vec4 mounts[6];            // muscle bulges on the body (hips and shoulders): xyz body rest space, w radius
uniform int n_mounts = 0;

const float BOUNCE = 0.14;
const float SKY_FLOOR = 0.035;
const float MOON_FILL = 0.45;
const float MOON_FLOOR = 0.15;
const float MOON_RIM = 1.2;

varying vec4 vSkin;
varying vec2 vUVb;
varying vec2 vUV2b;
varying vec3 vNo;
varying vec4 vAct;

float h3(vec3 p){p=fract(p*.3183099+.1);p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float n3(vec3 x){vec3 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);return mix(mix(mix(h3(i),h3(i+vec3(1.,0.,0.)),f.x),mix(h3(i+vec3(0.,1.,0.)),h3(i+vec3(1.,1.,0.)),f.x),f.y),mix(mix(h3(i+vec3(0.,0.,1.)),h3(i+vec3(1.,0.,1.)),f.x),mix(h3(i+vec3(0.,1.,1.)),h3(i+vec3(1.,1.,1.)),f.x),f.y),f.z);}
vec2 wor(vec3 x){vec3 p=floor(x),f=fract(x);float a=8.,b=8.;for(int k=-1;k<=1;k++)for(int j=-1;j<=1;j++)for(int i=-1;i<=1;i++){vec3 g=vec3(float(i),float(j),float(k));vec3 o=vec3(h3(p+g),h3(p+g+17.3),h3(p+g+41.7));vec3 r=g+o-f;float d=dot(r,r);if(d<a){b=a;a=d;}else if(d<b){b=d;}}return sqrt(vec2(a,b));}
vec3 pN(vec3 sp,vec3 sn,vec2 dH){vec3 sx=dFdx(sp),sy=dFdy(sp),r1=cross(sy,sn),r2=cross(sn,sx);float det=dot(sx,r1);vec3 g=sign(det)*(dH.x*r1+dH.y*r2);return normalize(abs(det)*sn-g);}

void vertex() {
	vSkin = CUSTOM0;
	vUVb = UV;
	vUV2b = UV2;
	vNo = NORMAL;
	vAct = vec4(0.0);
#ifndef MEMBRANE
	if (realism > .5) {
		float k = 0.0;
		float rad = max(UV2.x, 0.001);
		if (leg_part > .5) {
			// Limb segment: local -Y runs from the joint to the far end. leg_mode = the limb's actuation (A24).
			float sl = clamp(-VERTEX.y / max(seg_len, 0.001), 0.0, 1.0);
			float swell = sin(3.14159 * sl);
			float m = leg_mode;
			if (m < 1.5) {                 // muscle on bone: the belly swells with joint flexion
				k = swell * (0.07 + 0.34 * flex) * (leg_part < 1.5 ? 1.0 : 0.8);
				if (leg_part > 1.5) k -= smoothstep(0.55, 1.0, sl) * 0.18;
			} else if (m < 2.5) {          // hydraulic: slim rigid tube, knuckle at each joint, no bulge
				k = -0.16 - 0.1 * swell + 0.5 * (exp(-sl * sl * 80.0) + exp(-(1.0 - sl) * (1.0 - sl) * 80.0));
			} else if (m < 3.5) {          // muscle in an exoskeleton: three rigid sclerites with deep grooves between them
				float g = pow(abs(cos(3.14159 * sl * 3.0)), 5.0);
				k = -0.2 * g + 0.04 * swell;
				vAct.z = g;
			} else if (m < 4.5) {          // hydrostat: boneless, smooth and tapering, a slow wave along it
				k = 0.22 - 0.75 * sl;
				VERTEX.x += 0.05 * seg_len * sin(sl * 5.0 - TIME * 1.6 + act_phase) * sl;
			} else if (m < 5.5) {          // elastic tendon: thin sinewy limb, muscle only near the hip
				k = -0.52 + 0.62 * exp(-sl * sl * 10.0) - 0.04 * swell;
				vAct.w = atan(VERTEX.x, VERTEX.z);
			} else if (m < 6.5) {          // spring-latch: a coiled, loaded joint, thin rod beyond it
				k = 0.5 * exp(-sl * sl * 30.0) - 0.3 * smoothstep(0.25, 0.55, sl) + 0.1 * sin(sl * 48.0) * (1.0 - smoothstep(0.15, 0.5, sl));
				vAct.z = (1.0 - smoothstep(0.1, 0.5, sl)) * (0.5 + 0.5 * sin(sl * 48.0));
			} else {                       // tube feet: stubby, tapering, studded with suckers
				k = 0.1 - 0.35 * sl;
			}
			vAct.x = sl;
			VERTEX.xz *= (1.0 + k);
		} else if (use_uv > .5) {
			float t = UV2.y;
			float torso = smoothstep(0.25, 0.45, t) * (1.0 - smoothstep(0.7, 0.9, t));
			if (act_mode > 3.5) {          // hydrostatic: peristaltic wave of the circular muscles
				k = 0.05 * sin(t * 15.0 - TIME * 2.4 + act_phase) * smoothstep(0.02, 0.2, t);
			} else if (act_mode > 2.5) {   // exoskeleton: overlapping segment plates and soft joint rings
				float g = pow(abs(sin(3.14159 * t * seg_rings)), 5.0);
				k = -0.13 * g + 0.035;
				vAct.z = g;
			} else if (act_mode < 1.5) {   // muscle: haunch and shoulder masses
				for (int i = 0; i < n_mounts; i++) {
					float d = distance(CUSTOM0.xyz, mounts[i].xyz);
					float r = max(mounts[i].w, 0.01);
					k += 0.18 * exp(-d * d / (r * r));
				}
			}
			k += breathe * 0.013 * sin(TIME * 1.7 + act_phase) * torso;
			VERTEX += NORMAL * (k * rad);
			vAct.y = t;
		}
	}
#endif
}

void fragment() {
#ifndef MEMBRANE
	if (realism > .5) {
		vec3 rp = vSkin.xyz;
		float dd = vSkin.w;
		float freq = uScale * 1.7 * (0.7 / max(body_r, 0.05));
		float px = length(fwidth(rp)) * freq;           // cells per pixel: detail fades before it aliases
		float fade = 1.0 - smoothstep(0.22, 0.8, px);
		// ---- Turing pattern (object-space, physical scale) ----
		float tex = 0.5;
		if (tur_kind > .5) {
			if (use_uv > .5) {
				tex = texture(turing, vec2(vUVb.y, vUVb.x) / tur_tile).r;
			} else {
				vec3 an = pow(abs(vNo), vec3(4.0));
				an /= (an.x + an.y + an.z + 1e-4);
				tex = texture(turing, rp.zy / tur_tile).r * an.x + texture(turing, rp.xz / tur_tile).r * an.y + texture(turing, rp.xy / tur_tile).r * an.z;
			}
		}
		float nn = n3(rp * 1.3 / max(body_r, 0.1) * 0.7) + .5 * n3(rp * 2.9 / max(body_r, 0.1) * 0.7);
		float mk = 0.0;
		if (tur_kind > .5 && tur_kind < 1.5) mk = smoothstep(0.46, 0.6, tex);
		else if (tur_kind > 1.5 && tur_kind < 2.5) {
			mk = smoothstep(0.52, 0.66, tex);
			if (tur_ros > .5) mk *= 1.0 - 0.55 * smoothstep(0.72, 0.86, tex);   // lighter centre: a rosette
		} else if (tur_kind > 2.5) mk = smoothstep(0.5, 0.62, tex * 0.8 + nn * 0.14);
		mk *= smoothstep(-0.4, 0.3, dd);
		// ---- colour: countershading, mottling, pattern ----
		// Countershading keeps the player's hues: it only mixes towards the belly colour and shifts value.
		vec3 sk = mix(cA, cC, (1.0 - smoothstep(-0.6, 0.3, dd)) * clamp(0.35 + 0.65 * cs, 0.0, 1.0));
		sk *= 1.0 - 0.18 * cs * smoothstep(0.2, 1.0, dd) + 0.08 * cs * (1.0 - smoothstep(-0.8, 0.0, dd));
		sk *= 0.9 + 0.2 * smoothstep(0.3, 1.1, nn);
		sk = mix(sk, cB, mk * 0.92 * pc);
		// ---- procedural detail height: scales, pores, wrinkles (object space, relative to body size) ----
		vec2 w1 = wor(rp * freq);
		float sh = smoothstep(0.0, 0.2, w1.y - w1.x);
		float plate = smoothstep(0.0, 0.55, w1.y - w1.x);
		float pores = n3(rp * freq * 5.0);
		float cre = n3(rp * freq * 0.45 + n3(rp * freq * 0.2) * 3.0);
		float wr = 1.0 - abs(2.0 * cre - 1.0);
		float hgt = scale_amt * plate * 0.085 + pores * 0.025 + wrinkle * wr * wr * 0.22;
		hgt *= fade / freq;
		hgt -= vAct.z * 0.05;                 // segment grooves of an exoskeleton read in the normal too
		sk *= mix(1.0, mix(0.86, 1.0, sh), scale_amt * 0.7 * fade) * (0.95 + 0.1 * pores);
		// plates of an exoskeleton: dark joint rings, polished sclerites
		float joint = vAct.z;
		float loaded = 0.0;
		sk *= 1.0 - 0.6 * joint;
		if (leg_part > .5 && leg_mode > 4.5 && leg_mode < 5.5) {       // the elastic tendon: a pale, raised cord down the back of the limb
			float da = abs(abs(vAct.w) - 3.14159);
			float cord = (1.0 - smoothstep(0.08, 0.2, da)) * smoothstep(0.1, 0.3, vAct.x);
			sk = mix(sk, vec3(0.86, 0.8, 0.66), cord * 0.85);
			hgt += cord * 0.006;
		}
		if (leg_part > .5 && leg_mode > 5.5 && leg_mode < 6.5) {       // spring-latch: coil shading and the glow of stored energy
			sk *= 1.0 - 0.35 * joint;
			loaded = joint * 0.6;
		}
		if (leg_part > .5 && leg_mode > 6.5) {                          // tube feet: sucker dots
			float dots = 1.0 - smoothstep(0.18, 0.34, w1.x);
			sk = mix(sk, sk * 0.55, dots * 0.8);
			hgt -= dots * 0.004;
		}
		if (tube_feet > .5 && use_uv > .5 && vUVb.x > 5.0) {              // radial arms: two rows of sucker feet along the underside
			float across = vUVb.y / max(vUV2b.x, 0.001);                // 0 on the back .. pi on the belly midline
			float sp = max(vUV2b.x * 1.5, 0.02);
			vec2 q = vec2(fract((vUVb.x - 10.0) / sp) - 0.5, (across - 2.55) * 1.2);
			float dots = 1.0 - smoothstep(0.2, 0.34, length(q));
			float row = smoothstep(1.9, 2.4, across);
			sk = mix(sk, sk * 0.45, dots * 0.85 * row);
			hgt -= dots * row * 0.004;
		}
		vec3 view = normalize(-VERTEX);
		// ---- roughness: dry back, damp belly, wet snout and mouth ----
		float wetm = 0.0;
		if (snout.w > 0.0) wetm = 1.0 - smoothstep(0.0, 1.0, distance(rp, snout.xyz) / snout.w);
		float dry = mix(0.9, 0.58, uWet);   // skin v1: matte default, wet only where the genome says so
		float rgh = dry * mix(1.0, 0.78, smoothstep(0.2, -0.6, dd)) * (1.0 - 0.12 * plate * scale_amt) + (pores - 0.5) * 0.12;
		if (act_mode > 2.5 && act_mode < 3.5) rgh = mix(rgh, 0.36, 0.7);
		ROUGHNESS = clamp(mix(rgh, 0.12, wetm), 0.07, 1.0);
		ALBEDO = sk;
		vec3 n = pN(VERTEX, NORMAL, vec2(dFdx(hgt), dFdy(hgt)));
		NORMAL = n;
		// ---- fake subsurface: wrap light at the terminator, stronger where the tube is thin ----
		float thin = thin_default;
		if (use_uv > .5) thin = clamp(1.0 - vUV2b.x / (body_r * 1.1), 0.0, 1.0);
		vec3 Lw = normalize((VIEW_MATRIX * vec4(sun_dir, 0.0)).xyz);
		float ndl = dot(n, Lw);
		float wrap = clamp((ndl + 0.5) / 1.5, 0.0, 1.0) - clamp(ndl, 0.0, 1.0);
		vec3 blood = sk * vec3(1.0, 0.52, 0.36) * 1.4 + vec3(0.02, 0.0, 0.0);
		vec3 em = sk * pow(1.0 - clamp(dot(view, n), 0.0, 1.0), 3.0) * 0.18;
		em += blood * wrap * sss * (0.25 + 0.75 * thin);
		// skin v1 moonlight: at night a soft self-fill and a rim on the side facing the moon, always the skin's own colour (no glow, no outline).
		float moonside = 0.55 + 0.45 * dot(n, Lw);
		// skin v1: ground bounce on the sides and belly (the dry skin no longer mirrors the sky, so the shade side keeps its colour from the ground).
		float ny = (INV_VIEW_MATRIX * vec4(n, 0.0)).y;
		em += sk * BOUNCE * smoothstep(0.5, -0.7, ny) + cA * SKY_FLOOR;
		em += moon_k * (sk * MOON_FILL + cA * MOON_FLOOR) + sk * moon_k * ( MOON_RIM * pow(1.0 - clamp(dot(view, n), 0.0, 1.0), 2.5) * moonside);
#ifdef RENDERER_FORWARD_PLUS
		SSS_STRENGTH = sss * (0.15 + 0.5 * thin);
#endif
		em += vec3(0.9, 0.35, 0.08) * loaded * 0.5;
#ifdef GEL
		float fres = pow(1.0 - clamp(dot(view, n), 0.0, 1.0), 2.2);
		em += sk * (0.35 + 0.9 * fres) * gel * 0.55 + vec3(0.5, 0.75, 0.8) * fres * gel * 0.25;
		ALPHA = clamp(mix(1.0, 0.38 + 0.55 * fres, gel), 0.0, 1.0);
		ROUGHNESS = 0.08;
#endif
		EMISSION = em;
		METALLIC = 0.0;
		SPECULAR = mix(mix(0.03, 0.45, smoothstep(0.15, 0.7, dot(view, n))), 0.5, wetm);   // skin v1: dry skin has a weak sheen, the wet snout keeps full specular
		CLEARCOAT = clamp(clearcoat_amount * (0.3 + 3.0 * wetm), 0.0, 1.0);
		CLEARCOAT_ROUGHNESS = mix(clearcoat_rough, 0.06, wetm);
	} else {
#endif
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
#ifndef MEMBRANE
	}
#endif
}
