shader_type spatial;
render_mode cull_back;
// Keratin (claws, teeth, horns, spines, beaks, plates): the fix for the flat white spikes. Grown from a dark, stained
// root to a pale translucent tip, with growth ridges across the length, fine fibres along it, damp polish where it
// is smooth. `UV.x` is the position along the part, 0 at the wide root to 1 at the tip (CreatureGeo.compute_along),
// `CUSTOM0.xyz` the object-space position that also drives the skin detail. realism = 0 gives the old flat colour.
uniform float realism = 1.0;
uniform float kind = 0.0;              // 0 horn / bone, 1 tooth, 2 beak
uniform vec3 root_col : source_color = vec3(0.30, 0.22, 0.13);
uniform vec3 tip_col : source_color = vec3(0.86, 0.78, 0.60);
uniform vec3 flat_col : source_color = vec3(0.75, 0.68, 0.54);
uniform float gloss = 0.5;
uniform float ridge_freq = 26.0;
uniform vec3 sun_dir = vec3(-0.62, 0.3, -0.72);

varying float vAlong;
varying vec3 vRp;

float h3(vec3 p){p=fract(p*.3183099+.1);p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float n3(vec3 x){vec3 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);return mix(mix(mix(h3(i),h3(i+vec3(1.,0.,0.)),f.x),mix(h3(i+vec3(0.,1.,0.)),h3(i+vec3(1.,1.,0.)),f.x),f.y),mix(mix(h3(i+vec3(0.,0.,1.)),h3(i+vec3(1.,0.,1.)),f.x),mix(h3(i+vec3(0.,1.,1.)),h3(i+vec3(1.,1.,1.)),f.x),f.y),f.z);}
vec3 pN(vec3 sp,vec3 sn,vec2 dH){vec3 sx=dFdx(sp),sy=dFdy(sp),r1=cross(sy,sn),r2=cross(sn,sx);float det=dot(sx,r1);vec3 g=sign(det)*(dH.x*r1+dH.y*r2);return normalize(abs(det)*sn-g);}

void vertex() {
	vAlong = UV.x;
	vRp = CUSTOM0.xyz;
}

void fragment() {
	if (realism < .5) {
		ALBEDO = flat_col;
		ROUGHNESS = mix(0.5, 0.3, kind * 0.5);
		METALLIC = 0.0;
		CLEARCOAT = 0.3;
		CLEARCOAT_ROUGHNESS = 0.2;
	} else {
		float a = clamp(vAlong, 0.0, 1.0);
		float warp = n3(vRp * 9.0);
		float ridge = sin(a * ridge_freq + warp * 9.0);
		float ridge_w = (kind < .5) ? 0.55 : (kind < 1.5 ? 0.06 : 0.25);
		float fibre = n3(vec3(vRp.x * 26.0, vRp.y * 26.0, vRp.z * 26.0) + vec3(0.0, a * 40.0, 0.0));
		float tipmix = smoothstep(0.12, 0.98, a) * (kind < 1.5 ? 0.85 : 0.6);
		vec3 col = mix(root_col, tip_col, tipmix);
		col *= 0.88 + 0.12 * (0.5 + 0.5 * ridge * ridge_w) + 0.1 * (fibre - 0.5);
		// dirt and age at the root, polish at the tip
		col = mix(col, root_col * 0.7, (1.0 - smoothstep(0.0, 0.35, a)) * 0.35 * n3(vRp * 14.0));
		ALBEDO = col;
		float hgt = (ridge * ridge_w * 0.0025 + fibre * 0.0012) * (0.6 + a);
		vec3 n = pN(VERTEX, NORMAL, vec2(dFdx(hgt), dFdy(hgt)));
		NORMAL = n;
		ROUGHNESS = clamp(mix(0.55, 0.22, gloss) + (fibre - 0.5) * 0.18 - tipmix * 0.08, 0.08, 1.0);
		METALLIC = 0.0;
		CLEARCOAT = 0.25 * gloss + (kind > 1.5 ? 0.25 : 0.0);
		CLEARCOAT_ROUGHNESS = 0.18;
		// translucent keratin: a warm glow of light passing through the thin tip
		vec3 view = normalize(-VERTEX);
		vec3 Lw = normalize((VIEW_MATRIX * vec4(sun_dir, 0.0)).xyz);
		float thru = pow(clamp(-dot(n, Lw), 0.0, 1.0), 1.3);
		float rim = pow(1.0 - clamp(dot(view, n), 0.0, 1.0), 3.0);
		EMISSION = tip_col * vec3(1.0, 0.7, 0.45) * (thru * 0.35 * tipmix + rim * 0.06);
	}
}
