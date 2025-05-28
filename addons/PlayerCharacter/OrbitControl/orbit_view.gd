extends SpringArm3D

var active : bool = true : set = set_active

@export_group("View variables")
enum Camera {
	FIRST,
	THIRD,
	THIRD_L,
	THIRD_R }
@export var camera_mode: Camera
var cam_aimed : bool = false #if true, cam goes into "aim/shooter mode", above the play char shoulder
@export var third_cam_pos : Vector2 = Vector2(0.0, 0.5)
@export var aim_cam_pos : Vector2 = Vector2(2.0, 1.0)

@export_group("Head bob")
@export var headbob_amplitude : float = 0.03
@export var headbob_frequency : float = 2.3
var headbob_time : float = 0.0
var can_bob : bool = false

@export_group("Camera variables")
@export_range(0.0, 0.005, 0.0005) var mouse_sens : float
@export_range(-90.0, 90.0, 0.1, "radians") var min_limit_x : float
@export_range(-90.0, 90.0, 0.1, "radians") var max_limit_x : float
@export_range(0.0, 20.0, 0.01) var pan_rotation_val : float

@export_group("Zoom variables")
@export var zoom_val : float
@export var max_zoom_val : float
@export var min_zoom_val : float
@export var zoom_speed : float
@onready var last_zoom_val : float = zoom_val

@export_group("Keybinding variables")
@export var mouse_mode_action : String = ""
@export var aim_cam_action : String = ""
@export var aim_cam_side_action : String = ""
@export var cam_zoom_in_action : String = ""
@export var cam_zoom_out_action : String = ""

#references variables
@onready var cam : Camera3D = %Camera3D
@onready var godot_plush_skin : Node3D = %GodotPlushSkin
@onready var visual_root : Node3D = %VisualRoot
@onready var player: CharacterBody3D = $".."


func _ready():
	#capture mouse cursor, and enable camera
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.set_use_accumulated_input(false)
	set_active(active)
	set_zoom(camera_mode)


func set_active(state : bool):
	#enable/disable play char camera
	active = state
	set_process_input(active)
	set_process(active)


func _input(event):
	#free/capture mouse cursor
	if event.is_action_pressed(mouse_mode_action):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	#if mouse cursor is free, can't rotate cam
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	
	# switches between camera modes
	if event.is_action_pressed("first_person") and camera_mode != Camera.FIRST:
		set_zoom(Camera.FIRST)
		set_camera_mode(Camera.FIRST)

	if event.is_action_pressed("third_person") and camera_mode != Camera.THIRD:
		set_zoom(Camera.THIRD)
		set_camera_mode(Camera.THIRD)

	if event.is_action_pressed("third_aim_left") and camera_mode != Camera.THIRD_L:
		set_zoom(Camera.THIRD_L)
		set_camera_mode(Camera.THIRD_L)

	if event.is_action_pressed("third_aim_right") and camera_mode != Camera.THIRD_R:
		set_zoom(Camera.THIRD_R)
		set_camera_mode(Camera.THIRD_R)

	#rotate cam according to the mouse
	if event is InputEventMouseMotion:
		var viewport_transform: Transform2D = get_tree().root.get_final_transform()
		var mouse_motion = event.xformed_by(viewport_transform).relative
		rotate_from_vector(mouse_motion * mouse_sens)


func _process(delta):
	#get pan direction
	var joy_dir = Input.get_vector("pan_left", "pan_right", "pan_up", "pan_down")
	
	#position the cam according to her mode (default, aim (with left or right side))
	if camera_mode == Camera.FIRST:
		cam.position = Vector3(0.0, 0.0, zoom_val)
	elif camera_mode == Camera.THIRD:
		cam.position = Vector3(third_cam_pos.x, third_cam_pos.y, zoom_val)
	elif camera_mode == Camera.THIRD_L:
		cam.position = Vector3(-aim_cam_pos.x, aim_cam_pos.y, zoom_val)
	elif camera_mode == Camera.THIRD_R:
		cam.position = Vector3(aim_cam_pos.x, aim_cam_pos.y, zoom_val)


	# handle zoom in third person
	if not camera_mode == Camera.FIRST:
		zoom_handling(delta)

	#rotate cam
	rotate_from_vector(joy_dir * Vector2(1.0, 0.5) * pan_rotation_val * delta)

	if can_bob:
		handle_headbob(delta)


func rotate_from_vector(vector : Vector2):
	#rotate cam by the vector's amount, and clamp the rotation between max up and max down values
	#(to avoid doing 360 degree turn with the cam for example)
	if vector.length() == 0: return
	rotation.y -= vector.x
	rotation.x -= vector.y
	rotation.x = clamp(rotation.x, min_limit_x, max_limit_x)


# apply zoom and visibility based on the view
func set_zoom(new_camera_mode: Camera) -> void:
	if new_camera_mode == Camera.FIRST:
		# Save current zoom only if we're switching *from* third person
		if camera_mode != Camera.FIRST:
			last_zoom_val = zoom_val
		zoom_val = 0
		visual_root.visible = false

	elif camera_mode == Camera.FIRST:
		# Restore zoom only when switching *from* first person
		zoom_val = last_zoom_val
		visual_root.visible = true


func set_camera_mode(new_mode: Camera) -> void:
	if new_mode in Camera.values():
		camera_mode = new_mode
		print("Camera mode set to: ", get_camera_mode_name())
	else:
		print("Invalid camera mode")


func get_camera_mode_name() -> String:
	for key in Camera.keys():
		if Camera[key] == camera_mode:
			return key
	return "UNKNOWN"


func zoom_handling(delta : float):
	#zoom in/out cam, and clamp zoom value between min and max zoom values
	zoom_val += Input.get_axis(cam_zoom_in_action, cam_zoom_out_action) * zoom_speed * delta
	zoom_val = clamp(zoom_val, min_zoom_val, max_zoom_val)


func handle_headbob(delta: float):
	headbob_time += delta * pow(player.velocity.length(), 0.8)

	var speed_factor = pow(player.velocity.length(), 0.5)  # Non-linear scaling (square root)

	cam.transform.origin += Vector3(
		cos(headbob_time * headbob_frequency * 0.5) * headbob_amplitude * speed_factor,
		sin(headbob_time * headbob_frequency) * headbob_amplitude * speed_factor,
		0
	)

	
	print("BAmplitude: ", headbob_amplitude * player.velocity.length())
