shader_type canvas_item;

uniform float left_eye_angle_degrees = 0.0;
uniform float right_eye_angle_degrees = 1.0;
uniform float index_of_refraction = 1.5;
uniform float pixels_per_lens = 10.0;
uniform bool for_left_eye = true;

float f_prime(float x) {
	return (x*-1.0)/sqrt(1.0-x*x);
}

float t(float x) {
	return degrees(asin(index_of_refraction*sin(atan(f_prime(x)))) - atan(f_prime(x)));
}

void fragment() {
	float pixel_exit_angle_degrees = t(2.0*mod(float(FRAGCOORD.x), pixels_per_lens)/pixels_per_lens - 1.0);

    if (isnan(pixel_exit_angle_degrees)) {
        COLOR.a = 0.0;
    } else {
        if (abs(left_eye_angle_degrees - pixel_exit_angle_degrees) > abs(right_eye_angle_degrees - pixel_exit_angle_degrees)) {
            // Closer to right eye, make it transparent
            COLOR.a = for_left_eye ? 0.0 : 1.0;
        } else {
            COLOR.a = for_left_eye ? 1.0 : 0.0;
        }
    }
}