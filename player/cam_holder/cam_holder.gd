extends SpringArm3D

var active : bool = true : set = set_active

@onready var cam : Camera3D = %Camera3D
@onready var godot_plush_skin : Node3D = %GodotPlushSkin
@onready var visual_root : Node3D = %VisualRoot
@onready var cR: CharacterBody3D = $".."
@onready var state_machine: Node = $"../StateMachine"


@export_group("Camera mode")
enum Camera {
	FIRST,
	THIRD,
	THIRD_L,
	THIRD_R
}
@export var camera_mode: Camera = Camera.FIRST

# HEADBOB
var headbob_time : float = 0.0
var cached_speed_factor : float = 0.0

# CAMERA LIMITS
var cam_limit_up : float
var cam_limit_down : float

# ZOOM
@onready var last_zoom_val : float = cR.zoom_val
@onready var curr_fov: float = cR.cam_fov


func _ready() -> void:
	#capture mouse cursor, and enable camera
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.set_use_accumulated_input(false)
	set_active(active)
	cam.fov = cR.cam_fov
	set_zoom(camera_mode)


func set_active(state : bool):
	#enable/disable play char camera
	active = state
	set_process_input(active)
	set_process(active)


func _input(event) -> void:
	#free/capture mouse cursor
	if event.is_action_pressed(cR.mouse_mode_action):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	#if mouse cursor is free, can't rotate cam
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	
	# switches between camera modes
	if event.is_action_pressed("first_person") and camera_mode != Camera.FIRST:
		set_zoom(Camera.FIRST)
		set_camera_mode(Camera.FIRST)
		visual_root.visible = false
	
	if event.is_action_pressed("third_person") and camera_mode != Camera.THIRD:
		set_zoom(Camera.THIRD)
		set_camera_mode(Camera.THIRD)
		visual_root.visible = true
	
	if event.is_action_pressed("third_aim_left") and camera_mode != Camera.THIRD_L:
		set_zoom(Camera.THIRD_L)
		set_camera_mode(Camera.THIRD_L)
		visual_root.visible = true
	
	if event.is_action_pressed("third_aim_right") and camera_mode != Camera.THIRD_R:
		set_zoom(Camera.THIRD_R)
		set_camera_mode(Camera.THIRD_R)
		visual_root.visible = true
	
	# rotate cam according to the mouse
	if event is InputEventMouseMotion:
		# simple method
		rotation.y -= event.relative.x * cR.mouse_sens
		rotation.y = wrapf(rotation.y, 0.0, TAU)
		rotation.x -= event.relative.y * cR.mouse_sens
		rotation.x = clamp(rotation.x, cam_limit_up, cam_limit_down)


func _process(delta) -> void:
	#get pan direction
	#var joy_dir: Vector2 = Input.get_vector("pan_left", "pan_right", "pan_up", "pan_down")
	
	set_camera_position()
	
	# handle zoom in third person
	if camera_mode != Camera.FIRST:
		zoom_handling(delta)
	
	fov_handling(delta)
	
	if cR.headbob and not cR.was_on_floor and state_machine.curr_state_name != "Idle":
		handle_headbob(delta)
	
	#rotate cam with keyboard
	#rotate_from_vector(joy_dir * Vector2(1.0, 0.5) * pan_rotation_val * delta)
	
	# tilt the camera when moving sideways
	if cR.tilt: cam.rotation = lerp(cam.rotation, Vector3(0, 0, cR.move_dir_relative.x * cR.tilt_value), delta * cR.tilt_speed)


#func rotate_from_vector(vector : Vector2) -> void:
	##rotate cam by the vector's amount, and clamp the rotation between max up and max down values
	##(to avoid doing 360 degree turn with the cam for example)
	#if vector.length() == 0:
		#return
	#rotation.y -= vector.x
	#rotation.x -= vector.y
	#if camera_mode == Camera.FIRST:
		#rotation.x = clamp(rotation.x, first_limit_up, first_limit_down)
	#else:
		#rotation.x = clamp(rotation.x, third_limit_up, third_limit_down)


func set_camera_position() -> void:
	"""Set camera position based on current camera mode"""
	match camera_mode:
		Camera.FIRST:
			if cR.pose == cR.Pose.STANDING:
				position = position.lerp(Vector3(0, cR.first_cam_height, 0), cR.standing_speed)
			elif cR.pose == cR.Pose.CROUCHED:
				position = position.lerp(Vector3(0, cR.first_cam_crouch_height, 0), cR.crouching_speed)
			spring_length = 0
			cam_limit_down = cR.first_limit_down
			cam_limit_up = cR.first_limit_up
		Camera.THIRD:
			position = Vector3(0, cR.third_cam_height, 0)
			spring_length = cR.zoom_val
			cam_limit_down = cR.third_limit_down
			cam_limit_up = cR.third_limit_up
		Camera.THIRD_L:
			position = Vector3(-cR.aim_cam_pos.x, cR.aim_cam_pos.y, 0)
			spring_length = cR.zoom_val
			cam_limit_down = cR.third_limit_down
			cam_limit_up = cR.third_limit_up
		Camera.THIRD_R:
			position = Vector3(cR.aim_cam_pos.x, cR.aim_cam_pos.y, 0)
			spring_length = cR.zoom_val
			cam_limit_down = cR.third_limit_down
			cam_limit_up = cR.third_limit_up


func set_zoom(new_camera_mode: Camera) -> void:
	var switching_to_first = new_camera_mode == Camera.FIRST
	var switching_from_first = camera_mode == Camera.FIRST and new_camera_mode != Camera.FIRST

	if switching_to_first:
		if camera_mode != Camera.FIRST:
			last_zoom_val = cR.zoom_val
		cR.zoom_val = 0.0
	elif switching_from_first:
		cR.zoom_val = last_zoom_val


func set_camera_mode(new_mode: Camera) -> void:
	if new_mode in Camera.values():
		camera_mode = new_mode
		print("Camera mode set to: ", get_camera_mode_name())
	else:
		print("Invalid camera mode: ", new_mode)


func get_camera_mode_name() -> String:
	"""Get the string name of the current camera mode"""
	match camera_mode:
		Camera.FIRST:
			return "FIRST"
		Camera.THIRD:
			return "THIRD"
		Camera.THIRD_L:
			return "THIRD_L"
		Camera.THIRD_R:
			return "THIRD_R"
		_:
			return "UNKNOWN"


func fov_handling(delta: float) -> void:
	var fov_input: float = Input.get_axis(cR.cam_fov_decrease, cR.cam_fov_increase)

	if fov_input != 0.0:
		cR.cam_fov += fov_input * cR.fov_speed * delta
		curr_fov = clamp(cR.cam_fov, cR.min_fov, cR.max_fov)
	else:
		var target_fov: float = cR.cam_fov
		var speed: float = cR.reset_fov_speed

		if state_machine.curr_state_name == "Walk":
			target_fov += cR.walk_fov_increase
			speed = cR.walk_fov_increase_speed
		elif state_machine.curr_state_name == "Run":
			target_fov += cR.run_fov_increase
			speed = cR.run_fov_increase_speed

		curr_fov = lerp(curr_fov, target_fov, 1.0 - exp(-speed * delta))

	cam.fov = curr_fov


func zoom_handling(delta : float) -> void:
	#zoom in/out cam, and clamp zoom value between min and max zoom values
	var zoom_input: float = Input.get_axis(cR.cam_zoom_in_action, cR.cam_zoom_out_action)
	cR.zoom_val += zoom_input * cR.zoom_speed * delta
	cR.zoom_val = clamp(cR.zoom_val, cR.min_zoom_val, cR.max_zoom_val)


func handle_headbob(delta: float) -> void:
	"""Handle camera head bobbing effect based on player movement"""
	var player_speed: float = cR.velocity.length()
	cached_speed_factor = pow(player_speed, 0.5)
	headbob_time += delta * pow(player_speed, 0.8)
	
	var headbob_offset: Vector3 = Vector3(
		cos(headbob_time * cR.headbob_frequency * 0.5) * cR.headbob_amplitude * cached_speed_factor,
		sin(headbob_time * cR.headbob_frequency) * cR.headbob_amplitude * cached_speed_factor,
		0.0
	)
	
	cam.transform.origin += headbob_offset
