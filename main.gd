extends Node3D

@export var calibration_ui: Control
@export var camera: Camera3D

var conn
var waiting_for_request: bool = true;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	conn = StreamPeerTCP.new()

	var result = await conn.connect_to_host('127.0.0.1', 42842)

	if result != OK:
		print('Failed to connect to controller program, with error code %d' % result)
		get_tree().quit()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:

	conn.poll()

	if conn.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		print('waiting')
		print(conn.get_status())
		return

	var num_bytes_ready_to_read: int = conn.get_available_bytes()

	if num_bytes_ready_to_read > 0:
		print('Num bytes ready: ' + str(num_bytes_ready_to_read))

		if waiting_for_request:
			print('Must be request code, so has to be a int 64')
			var request_code: int = conn.get_64()

			print('Request code is ' + str(request_code))

			match request_code:
				0:
					# Show calibration window
					calibration_ui.visible = true
				1:
					# Hide calibration window
					calibration_ui.visible = false
				3:
					# Return window size
					conn.put_64(get_viewport().get_visible_rect().size.x)	
				4:
					# New eye angles, so move the camera
					var left_eye_horizontal_angle: float = conn.get_double()
					var left_eye_vertical_angle: float = conn.get_double()
					var right_eye_horizontal_angle: float = conn.get_double()
					var right_eye_vertical_angle: float = conn.get_double()
					

					var x = cos(deg_to_rad(left_eye_vertical_angle)) * cos(deg_to_rad(left_eye_horizontal_angle))
					var y = -sin(deg_to_rad(left_eye_vertical_angle))
					var z = cos(deg_to_rad(left_eye_vertical_angle)) * sin(deg_to_rad(left_eye_horizontal_angle))

					camera.set_position(Vector3(x, y, z))
					camera.look_at(Vector3.ZERO)
