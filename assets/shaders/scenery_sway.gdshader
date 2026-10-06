shader_type canvas_item;
// Wind for arena scenery (trees, bushes, grass): the top of the picture leans, the base
// stays put. One shared material for every swaying piece: the phase comes from where
// each one stands, so a forest never moves in lockstep and the CPU does nothing.

uniform float strength = 1.6;  // world units the top moves
uniform float speed = 1.3;

void vertex() {
	float phase = MODEL_MATRIX[3].x * 0.045 + MODEL_MATRIX[3].y * 0.02;
	float top = clamp(1.0 - UV.y, 0.0, 1.0);
	VERTEX.x += sin(TIME * speed + phase) * strength * top * top;
}
