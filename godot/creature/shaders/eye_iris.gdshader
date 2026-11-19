shader_type spatial;
render_mode cull_back;
// Iris with radial fibres, a collarette, a dark limbal ring and a pupil whose shape follows the way of life of the
// animal (round, vertical slit for ambush / night hunters, horizontal bar for grazers). UV = disc coordinates of the
// iris mesh in [-1, 1] (CreatureGeo.compute_disc), with +Y the up of the part. realism = 0 gives the old flat orange.
uniform float realism = 1.0;
uniform vec3 col_in : source_color = vec3(0.78, 0.5, 0.1);
uniform vec3 col_out : source_color = vec3(0.45, 0.26, 0.05);
uniform float pupil_kind = 0.0;      // 0 round, 1 slit, 2 bar
uniform float dilation = 0.5;        // 0 pinched .. 1 wide open
uniform float seed = 0.0;

varying vec2 vD;

float h2(vec2 p){p=fract(p*vec2(.1031,.1030)+seed*.37);p+=dot(p,p.yx+33.33);return fract((p.x+p.y)*p.x);}
float n2(vec2 x){vec2 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);return mix(mix(h2(i),h2(i+vec2(1.,0.)),f.x),mix(h2(i+vec2(0.,1.)),h2(i+vec2(1.,1.)),f.x),f.y);}

void vertex() {
	vD = UV;
}

void fragment() {
	if (realism < .5) {
		ALBEDO = vec3(0.91, 0.64, 0.11);
		ROUGHNESS = 0.2;
		EMISSION = vec3(0.4, 0.23, 0.0);
	} else {
		vec2 p = vD;
		float r = length(p);
		float a = atan(p.y, p.x);
		float fib = n2(vec2(a * 9.0, r * 2.5)) * 0.6 + n2(vec2(a * 31.0, r * 6.0)) * 0.4;
		vec3 col = mix(col_in, col_out, smoothstep(0.18, 0.95, r));
		col *= 0.62 + 0.55 * fib;
		col += col_in * 0.35 * exp(-pow((r - 0.42) * 12.0, 2.0));        // collarette
		col *= mix(1.0, 0.18, smoothstep(0.76, 0.99, r));                 // limbal ring
		float open = mix(0.55, 1.0, dilation);
		float d;
		if (pupil_kind < .5) d = r / (0.36 * open);
		else if (pupil_kind < 1.5) d = length(vec2(p.x / (0.12 * open + 0.03), p.y / (0.7 * open + 0.08)));
		else d = length(vec2(p.x / (0.7 * open + 0.08), p.y / (0.18 * open + 0.04)));
		float pup = 1.0 - smoothstep(0.88, 1.08, d);
		col = mix(col, vec3(0.008), pup);
		ALBEDO = col;
		ROUGHNESS = 0.32;
		EMISSION = col * 0.08 * (1.0 - pup);
	}
	METALLIC = 0.0;
}
