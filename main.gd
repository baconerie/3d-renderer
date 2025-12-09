extends Node3D

@export var calibration_ui: Control
@export var left_cameras: Node3D
@export var right_cameras: Node3D

var conn
var waiting_for_request: bool = true;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	conn = StreamPeerTCP.new()

	var result = await conn.connect_to_host('127.0.0.1', 42842)

	if result != OK:
		#print('Failed to connect to controller program, with error code %d' % result)
		get_tree().quit()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#print('NEW PROCESS.')

	#print('Starting polling')
	conn.poll()
	#print('Polling done.')

	if conn.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		#print('waiting')
		#print(conn.get_status())
		return

	var num_bytes_ready_to_read: int = conn.get_available_bytes()
	#print('Num bytes ready: ' + str(num_bytes_ready_to_read))

	if num_bytes_ready_to_read > 0:

		if waiting_for_request:
			#print('Must be request code, so has to be a int 64')
			var request_code: int = conn.get_64()

			#print('Request code is ' + str(request_code))

			match request_code:
				0:
					# Show calibration window
					calibration_ui.visible = true
				1:
					# Hide calibration window
					calibration_ui.visible = false
				3:
					# Return window size
					#print('Received code 3.')
					conn.put_64(get_viewport().get_visible_rect().size.x)
					#print('We\'ve put in the size of the window x: ' + str(get_viewport().get_visible_rect().size.x))
				4:
					# New eye angles, so move the camera
					var left_eye_horizontal_angle: float = conn.get_double()
					var left_eye_vertical_angle: float = conn.get_double()
					var right_eye_horizontal_angle: float = conn.get_double()
					var right_eye_vertical_angle: float = conn.get_double()
					
					var left_x = cos(deg_to_rad(left_eye_vertical_angle)) * cos(deg_to_rad(left_eye_horizontal_angle))
					var left_y = -sin(deg_to_rad(left_eye_vertical_angle))
					var left_z = cos(deg_to_rad(left_eye_vertical_angle)) * sin(deg_to_rad(left_eye_horizontal_angle))

					var right_x = cos(deg_to_rad(right_eye_vertical_angle)) * cos(deg_to_rad(right_eye_horizontal_angle))
					var right_y = -sin(deg_to_rad(right_eye_vertical_angle))
					var right_z = cos(deg_to_rad(right_eye_vertical_angle)) * sin(deg_to_rad(right_eye_horizontal_angle))

					left_cameras.position = Vector3(left_x, left_y, left_z)
					right_cameras.position = Vector3(right_x, right_y, right_z)
	
				5:
					#print('Received code 5.')
					# Interlacing pattern
					var is_left_eye: bool = conn.get_64() == 0
					var segment_width: int = conn.get_64()

					#print('Is left eye: ' + str(is_left_eye))
					#print('Initial segment width: ' + str(segment_width))

					var window_x: float = get_viewport().get_visible_rect().size.x
					var window_y: float = get_viewport().get_visible_rect().size.y

					var combined_fov = 2 * atan(tan(42.5) * (window_x / window_y))

					var angle_covered: float = 0.0
					var pixels_covered: int = 0

					for n in left_cameras.get_children():
						left_cameras.remove_child(n)
						n.queue_free()

					for n in right_cameras.get_children():
						right_cameras.remove_child(n)
						n.queue_free()

					while segment_width != -1:
						#print('Line 87. Inside the while loop. Segment width: ' + str(segment_width))
						conn.poll()
						segment_width = conn.get_64()

						var sub_viewport_container = SubViewportContainer.new()
						var sub_viewport = SubViewport.new()
						var camera = Camera3D.new()

						sub_viewport.add_child(camera)
						sub_viewport_container.add_child(sub_viewport)

						sub_viewport_container.size = Vector2(segment_width, window_y)
						sub_viewport_container.position = Vector2(pixels_covered, 0)

						if is_left_eye:
							camera.position = left_cameras.position
							#print('Main.gd. Line 96 Trying to add sub_viewport_container as a child to left_cameras')
							#print('The parent of the sub_viewport_container is: ' + str(sub_viewport_container.get_parent()))
							left_cameras.add_child(sub_viewport_container)
						else:
							camera.position = right_cameras.position
							#print('Main.gd. Line 100 Trying to add sub_viewport_container as a child to right_cameras')
							#print('The parent of the sub_viewport_container is: ' + str(sub_viewport_container.get_parent()))
							right_cameras.add_child(sub_viewport_container)

						var segment_fov = rad_to_deg(2 * atan(tan(deg_to_rad(42.5)) * (segment_width / window_y)))
						camera.fov = segment_fov

						# Rotate the camera to the correct angle
						camera.look_at(Vector3(0, 0, 0), Vector3.UP)
						camera.rotate_y(deg_to_rad(angle_covered + segment_fov / 2 - (combined_fov / 2)))

						# Update angle covered
						angle_covered += segment_fov
						pixels_covered += segment_width
						is_left_eye = not is_left_eye
						segment_width = conn.get_64()
					
			
			#print('End of match statement')
	
	#print('End of process function\n\n\n')
