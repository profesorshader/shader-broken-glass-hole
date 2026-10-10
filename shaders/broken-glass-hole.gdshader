shader_type canvas_item;

#define USE_RADIAL 1
#define USE_NOISE 1

uniform int g_random_seed = 0;
uniform vec2 g_grid_size = vec2(7.0, 21.0); // x=cols, y=rows
uniform vec4 g_color_glass : source_color = vec4(0.8, 1.0, 1.0, 0.6); // glass color
uniform vec4 g_color_cracks : source_color = vec4(1.0, 1.0, 1.0, 1.0); // crack color
uniform vec4 g_color_hole : source_color = vec4(1.0, 1.0, 1.0, 0.0); // hole color
uniform float g_line_size : hint_range(0.001, 0.5) = 0.015;

uniform float g_hole_limit = 0.0; // where the hole starts
uniform float g_hole_limit_fade_mult = 0.1; // how fast cracks grow when hole grows

uniform float g_fade_start_min : hint_range(0.1, 0.8) = 0.25;
uniform float g_fade_start_max : hint_range(0.2, 0.9) = 0.60; // should be > _min value
uniform float g_fade_length_min : hint_range(0.0, 0.8) = 0.1;
uniform float g_fade_length_max : hint_range(0.0, 0.9) = 0.2; // should be > _min value

uniform float g_power = 5.0; // how sharp de you want the cracks

#if USE_RADIAL
uniform float g_radial_zoom : hint_range(0.1, 0.7) = 0.69;
uniform float g_radial_repeat = 1.0;
#endif

#if USE_NOISE
uniform sampler2D g_noise_tex : repeat_enable; // use a seamless noise texture with different R and G values (you can use: As Normal Map [x] On)
uniform float g_noise_scale = 1.0;
uniform float g_noise_strength : hint_range(0.000, 0.025, 0.001) = 0.010;
#endif

// returns a pseudo random number 
float random(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + vec2(45.32));
    return fract(p.x * p.y);
}

// taken from godotshaders.com :) (but, a bit modified)
#if USE_RADIAL
vec2 polar_coordinates(vec2 uv, vec2 center, float zoom, float repeat, float offset)
{
	vec2 dir = uv - center;
	float radius = length(dir) * 2.0;
	float angle = atan(dir.y, dir.x) * 1.0/TAU;
	return mod(vec2(radius * zoom - offset, angle * repeat), 1.0);
}
#endif

vec4 get_row_info(float seed, vec2 grid_uv, float row_offset) {
	
	// get row indices
	vec2 grid_uv_rows = vec2(0.0, grid_uv.y);
	vec2 row_num = floor(grid_uv_rows); // row indices	
	
	// apply offset
	row_num.y = round(mod(round(row_num.y + row_offset), g_grid_size.y));

	// get row Y position (in cell space)	
	vec2 rnd_pos_y = seed + row_num + vec2(1.0, 1.0);
	float pos_y = random(rnd_pos_y);	

	// get fade start and length
	vec2 rnd_fade_start_rnd = seed + row_num + vec2(2.0, 2.0);
	float fade_start = mix(g_fade_start_min, g_fade_start_max, random(rnd_fade_start_rnd) );	
	vec2 rnd_fade_length_rnd = seed + row_num + vec2(3.0, 3.0);
	float fade_length = mix(g_fade_length_min, g_fade_length_max, random(rnd_fade_length_rnd) );	

	// add hole limit to fade start
	fade_start -= g_hole_limit * g_hole_limit_fade_mult;

	// return row position Y (cell space), row index, fade start and fade length
	return vec4(pos_y, row_num.y, fade_start, fade_length);
	
}

vec2 get_cell_info(float seed, vec2 grid_uv, float row_offset) {
	
	// get cell indices
	vec2 cell_num = floor(grid_uv); // cell indices	

	// apply offset
	cell_num.y = round(mod(round(cell_num.y + row_offset), g_grid_size.y));

	// get row X position (in cell space)
	vec2 rnd_pos_x = seed + cell_num + vec2(4.0, 4.0);
	float pos_x = random(rnd_pos_x);	
	
	// return cell position X, cell col index
	return vec2(pos_x, cell_num.x);
		
}

void fragment() {	
	float seed = float(g_random_seed);
	
	vec2 src_uv = UV;	
	vec2 uv = src_uv;

#if USE_NOISE
	vec4 noise = texture(g_noise_tex, UV * g_noise_scale);
	uv.x += ((noise.r * 2.0) - 1.0) * g_noise_strength;
	uv.y += ((noise.g * 2.0) - 1.0) * g_noise_strength;
#endif
		
#if USE_RADIAL
	uv = polar_coordinates(uv, vec2(0.5), g_radial_zoom, g_radial_repeat, 0.0);
#endif	
	
    vec2 grid_uv = (uv * g_grid_size);
    vec2 local_pos = fract(grid_uv); // position inside the cell	
	
	// get current row info (previous, current, next row)
	vec4 row_prv = get_row_info(seed, grid_uv, -1.0);
	vec4 row_cur = get_row_info(seed, grid_uv, 0.0);
	vec4 row_nxt = get_row_info(seed, grid_uv, 1.0);
	
	// get cell info (previous, current, next row)
	// vec2 cell_prv = get_cell_info(seed, grid_uv, -1.0);
	vec2 cell_cur = get_cell_info(seed, grid_uv, 0.0);
	vec2 cell_nxt = get_cell_info(seed, grid_uv, 1.0);	
	
	// compute row fade values
	float fade_prv = smoothstep(row_prv.z, row_prv.z + row_prv.a, 1.0 - uv.x);	
	float fade_cur = smoothstep(row_cur.z, row_cur.z + row_cur.a, 1.0 - uv.x);
	float fade_nxt = smoothstep(row_nxt.z, row_nxt.z + row_nxt.a, 1.0 - uv.x);	
	
	// we are above or under current row horizontal line?
	float pos_x = 0.5; // cell space
	float pos_y_a = 0.0; // grid space
	float pos_y_b = 0.0; // grid space
	float fade_a = 0.0;
	float fade_b = 0.0;
	float row_dist = 0.0;
	if (local_pos.y < row_cur.x)
	{
		// get X position in cell space
		pos_x = cell_cur.x;
		// get Y positions in grid space
		pos_y_a = row_prv.y + row_prv.x;
		pos_y_b = row_cur.y + row_cur.x;
		if (pos_y_b < pos_y_a) { // a little fix for when the prev row is the last one (repeat-Y)
			pos_y_a = row_cur.y + row_cur.x;
			pos_y_b = row_prv.y + row_prv.x;
		}		
		// get distance to the row
		row_dist = row_cur.x - local_pos.y;
		// get fade values
		fade_a = fade_prv;
		fade_b = fade_cur;		
	}
	else
	{
		// get X position in cell space
		pos_x = cell_nxt.x;
		// get Y positions in grid space
		pos_y_a = row_cur.y + row_cur.x;		
		pos_y_b = row_nxt.y + row_nxt.x;		
		if (pos_y_b < pos_y_a) { // a little fix for when the next row is the first one (repeat-Y)
			pos_y_a = row_nxt.y + row_nxt.x;
			pos_y_b = row_cur.y + row_cur.x;				
		}
		// get distance to the row
		row_dist = (local_pos.y - row_cur.x);
		// get fade values
		fade_a = fade_cur;
		fade_b = fade_nxt;		
	}	
	
	// compute row height
	float row_height = (pos_y_b - pos_y_a);
	// normalize row dist 
	float row_dist_nrm = (row_dist / row_height);
	if (local_pos.y < row_cur.x)
	{
		row_dist_nrm = 1.0 - row_dist_nrm;
	}
	// interpolate fades
	float col_fade = mix(fade_a, fade_b, row_dist_nrm);
	
	// color value (0 = a, 1 = b)
	float color_val = 0.5;
		
	// draw rows
	if ((local_pos.y < row_cur.x - g_line_size) || (local_pos.y > row_cur.x + g_line_size))
	{
		color_val = 0.0;
	} 
	else
	{
		color_val = fade_cur;
	}

	// draw columns
	if ((local_pos.x >= pos_x - g_line_size) && (local_pos.x <= pos_x + g_line_size))
	{
		color_val = col_fade; 
	}
		
	// draw hole (first cells on the left)
	float hole_val = 0.0;
	if (
		((cell_cur.y == floor(g_hole_limit)) && (local_pos.x < pos_x)) 	
		|| 
		(cell_cur.y < g_hole_limit - 1.0)		
	) {		
		hole_val = 1.0;			
	} 
	
	// render final color
	COLOR = mix(g_color_glass, g_color_cracks, pow(color_val, g_power));
	COLOR = mix(COLOR, g_color_hole, hole_val);
}