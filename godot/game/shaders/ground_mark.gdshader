shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// One shader for every ground ring of the diegetic UI (docs/godot/UI-DIEGETIC.md section 8, PLAN-ui-diegetic.md).
// The mesh is a patch that lies on the terrain (ground_mark.gd); UV 0..1 covers it, p = (UV - 0.5) * 2 is -1..1 and
// every radius below is a fraction of the patch half-size. Styles: 0 smooth, 1 teeth, 2 dots, 3 double, 4 cut.

uniform vec4 color : source_color = vec4(0.957, 0.929, 0.878, 1.0);
uniform vec4 disc_color : source_color = vec4(0.941, 0.439, 0.290, 1.0);
uniform float radius = 0.5;
uniform float width = 0.03;
uniform int style = 0;
uniform float count = 12.0;
uniform float lit = -1.0;          // style 4: segments lit (negative: all)
uniform float frac = 1.0;          // arc length 0..1 (the unlit part is drawn at `track`)
uniform float start = 0.0;         // radians, where the arc begins (the creature's front)
uniform float dir = 1.0;           // +1 clockwise, -1 anticlockwise
uniform float track = 0.24;
uniform float wash = 0.0;
uniform float dot_r = 0.0;         // centre dot radius
uniform float cross_r = 0.0;       // a small cross in the centre (a move that cannot go there)
uniform float disc = 0.0;          // wind-up disc as a fraction of radius
uniform float ring2 = 0.0;         // second ring radius (0 = off)
uniform float ring2_alpha = 0.5;
uniform float thick = 0.0;
uniform float halo = 1.0;
uniform float alpha = 1.0;
uniform float gap_deg = 14.0;      // style 4: the gap between segments, degrees
uniform float min_px = 1.6;        // line width floor on screen

const vec3 INK = vec3(0.055, 0.09, 0.082);

void vertex() {
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX + vec3(0.0, 0.04, 0.0), 1.0)).xyz;
	vp -= normalize(vp) * (0.02 * length(vp));      // a little towards the camera: no z-fighting, creatures still hide it
	POSITION = PROJECTION_MATRIX * vec4(vp, 1.0);
}

float line_mask(float d, float r, float w, float aa) {
	return 1.0 - smoothstep(w, w + aa, abs(d - r));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float aa = max(fwidth(d), 0.0005);
	float wmin = aa * min_px;
	float wd = max(width + thick, wmin);
	float w = wd * 0.5;
	float ang = atan(p.x, -p.y) - start;
	ang = ang * dir;
	ang = mod(ang, TAU);
	float t = ang / TAU;

	float m = 0.0;
	float mt = 0.0;     // arc mask for colour vs track
	if (style == 2) {
		float cell = fract(t * count) - 0.5;
		vec2 q = vec2(cell * TAU * radius / count, d - radius);
		m = 1.0 - smoothstep(w * 1.5, w * 1.5 + aa, length(q));
	} else if (style == 4) {
		float seg = floor(t * count);
		float local = fract(t * count) * 360.0 / count;
		float gap = gap_deg * 0.5;
		float inside = smoothstep(gap, gap + 1.5, local) * (1.0 - smoothstep(360.0 / count - gap - 1.5, 360.0 / count - gap, local));
		m = line_mask(d, radius, w, aa) * inside;
	} else {
		m = line_mask(d, radius, w, aa);
	}
	if (style == 1 && aa < width) {
		float k = floor(t * count + 0.5);
		float ac = k * TAU / count;
		float da = ang - ac;
		da = mod(da + PI, TAU) - PI;
		float s = da * radius;
		float h = d - radius - w;
		float th = 3.0 * width;
		float bw = 0.45 * TAU / count * radius;
		float tri = step(0.0, h) * step(h, th) * (1.0 - smoothstep(bw * (1.0 - h / th) - aa, bw * (1.0 - h / th), abs(s)));
		m = max(m, tri);
	}
	if (style == 3) {
		m = max(m, line_mask(d, radius + 2.4 * width, w * 0.7, aa) * 0.85);
	}
	// arc: the lit part and the faint track
	float lit_part = 1.0;
	if (style == 4) {
		float seg2 = floor(t * count);
		lit_part = (lit < 0.0 || seg2 < lit) ? 1.0 : 0.0;
	} else {
		lit_part = t <= frac + 0.0005 ? 1.0 : 0.0;
	}
	float arc_a = mix(track, 1.0, lit_part);
	float ca = m * arc_a;
	// wash, centre dot, cross, disc, second ring
	float inside_r = 1.0 - smoothstep(radius - aa, radius, d);
	ca = max(ca, wash * inside_r);
	if (dot_r > 0.0) {
		ca = max(ca, 1.0 - smoothstep(dot_r, dot_r + aa, d));
	}
	if (cross_r > 0.0) {
		vec2 a2 = abs(vec2(p.x + p.y, p.x - p.y)) * 0.7071;
		float cr = (1.0 - smoothstep(w, w + aa, min(a2.x, a2.y))) * step(d, cross_r);
		ca = max(ca, cr);
	}
	vec3 rgb = color.rgb;
	float disc_a = 0.0;
	if (disc > 0.0) {
		float dr = disc * radius;
		disc_a = (1.0 - smoothstep(dr - aa, dr, d)) * 0.30;
		disc_a = max(disc_a, line_mask(d, dr, w * 0.8, aa) * 0.9);
	}
	float r2 = 0.0;
	if (ring2 > 0.0) {
		r2 = line_mask(d, ring2, w * 0.75, aa) * ring2_alpha;
	}
	// halo: the main ring widened, dark
	float hm = 0.0;
	if (style == 2) {
		hm = 1.0 - smoothstep(w * 1.5 + 2.0 * wd, w * 1.5 + 2.0 * wd + aa, length(vec2((fract(t * count) - 0.5) * TAU * radius / count, d - radius)));
	} else {
		hm = line_mask(d, radius, w + 1.0 * wd, aa);
	}
	hm = max(hm, line_mask(d, ring2, w * 0.75 + wd, aa) * step(0.0001, ring2) * ring2_alpha);
	float ha = hm * 0.6 * halo * arc_a;
	// composite: colour over halo; the disc under the line
	float a_col = clamp(max(ca, r2), 0.0, 1.0);
	vec3 base_rgb = mix(disc_color.rgb, rgb, step(0.01, a_col));
	float a_disc = disc_a * (1.0 - a_col);
	float out_a = a_col + a_disc + ha * (1.0 - a_col - a_disc);
	vec3 out_rgb = (rgb * a_col + disc_color.rgb * a_disc + INK * ha * (1.0 - a_col - a_disc)) / max(out_a, 0.0001);
	ALBEDO = out_rgb;
	ALPHA = clamp(out_a, 0.0, 1.0) * alpha * color.a;
}
