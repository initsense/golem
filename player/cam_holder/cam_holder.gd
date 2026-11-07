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
const HEADBOB_MIN_SPEED : float = 0.1
var headbob_time : float = 0.0
var headbob_weight : float = 0.0
var bob_speed : float = 0.0
var headbob_offset : Vector2 = Vector2.ZERO
# CAMERA LIMITS
var cam_limit_up : float
var cam_limit_down : float
# ZOOM
@onready var last_zoom_val : float = cR.zoom_val
@onready var curr_zoom: float = cR.zoom_val
# FOV
@onready var curr_fov: float = cR.cam_fov
# SHAKE
var cam_shake_offset: Vector3 = Vector3.ZERO
var shake_timer : float = 0.0
var shake_time : float = 0.0


func _ready() -> void:
	cR.connect("pose_changed", Callable(self, "_on_pose_changed"))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.set_use_accumulated_input(false)
	set_active(active)
	
	set_camera_mode(camera_mode)


func set_active(state : bool):
	# enable/disable play char camera
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
		set_camera_mode(Camera.FIRST)
	
	if event.is_action_pressed("third_person") and camera_mode != Camera.THIRD:
		set_camera_mode(Camera.THIRD)
	
	if event.is_action_pressed("third_aim_left") and camera_mode != Camera.THIRD_L:
		set_camera_mode(Camera.THIRD_L)
	
	if event.is_action_pressed("third_aim_right") and camera_mode != Camera.THIRD_R:
		set_camera_mode(Camera.THIRD_R)
	
	# rotate cam according to the mouse
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * cR.mouse_sens
		rotation.y = wrapf(rotation.y, 0.0, TAU)
		rotation.x -= event.relative.y * cR.mouse_sens
		rotation.x = clamp(rotation.x, cam_limit_up, cam_limit_down)


func _physics_process(delta: float) -> void:
	update_camera_shake(delta)
	
	## Update camera position if mode changed or shaking
	#if camera_mode_changed or shake_timer > 0.0:
		#set_camera_position()
		#camera_mode_changed = false


func _process(delta: float) -> void:
	if cR.can_change_zoom and camera_mode != Camera.FIRST:
		zoom_handling(delta)
		
	if cR.can_change_fov:
		fov_handling(delta)

	headbob_handling(delta)
	
	#if cR.can_shake and cR.is_on_floor():
		#pass

	if cR.can_tilt and camera_mode == Camera.FIRST:
		cam.rotation.z = lerp(cam.rotation.z, cR.move_dir_relative.x * cR.tilt_value, delta * cR.tilt_speed)


func set_camera_mode(new_mode: Camera) -> void:
	print("Changing camera mode from ", camera_mode, " to ", new_mode)
	print("Current zoom val: ", curr_zoom, " | Last zoom_val: ", last_zoom_val)
	
	if camera_mode != Camera.FIRST and new_mode == Camera.FIRST:
		last_zoom_val = curr_zoom
	
	elif camera_mode == Camera.FIRST and new_mode != Camera.FIRST:
		spring_length = last_zoom_val
	
	camera_mode = new_mode
	print("New camera mode set:", camera_mode, " | Zoom val now:", curr_zoom)
	
	if camera_mode != Camera.FIRST:
		reset_headbob()
	
	if camera_mode == Camera.FIRST:
		if cR.pose == cR.Pose.STANDING:
			position = position.lerp(Vector3(0.0, cR.first_cam_height, 0.0), cR.standing_speed)
		elif cR.pose == cR.Pose.CROUCHED:
			position = position.lerp(Vector3(0.0, cR.first_cam_crouch_height, 0.0), cR.crouching_speed)
		
		cam_limit_down = cR.first_limit_down
		cam_limit_up = cR.first_limit_up
		spring_length = 0.0
		visual_root.visible = false
	else:
		if camera_mode == Camera.THIRD:
			position = Vector3(0.0, cR.third_cam_height, 0.0)
		elif camera_mode == Camera.THIRD_L:
			position = Vector3(-cR.aim_cam_pos.x, cR.aim_cam_pos.y, 0.0)
		elif camera_mode == Camera.THIRD_R:
			position = Vector3(cR.aim_cam_pos.x, cR.aim_cam_pos.y, 0.0)
		
		cam_limit_down = cR.third_limit_down
		cam_limit_up = cR.third_limit_up
		spring_length = curr_zoom
		visual_root.visible = true


#region HANDLINGS
func zoom_handling(delta: float) -> void:
	var zoom_input: float = Input.get_axis(cR.cam_zoom_in_action, cR.cam_zoom_out_action)
	
	if zoom_input != 0.0:
		curr_zoom += zoom_input * cR.zoom_speed * delta
		curr_zoom = clamp(curr_zoom, cR.min_zoom_val, cR.max_zoom_val)
		print("Zoom val: ", curr_zoom)
	
	if not is_equal_approx(curr_zoom, last_zoom_val):
		last_zoom_val = curr_zoom
		spring_length = curr_zoom


func fov_handling(delta: float) -> void:
	var fov_input := Input.get_axis(cR.cam_fov_decrease, cR.cam_fov_increase)

	if fov_input != 0.0:
		cR.cam_fov += fov_input * cR.fov_speed * delta
		cR.cam_fov = clamp(cR.cam_fov, cR.min_fov, cR.max_fov)
		curr_fov = cR.cam_fov
	else:
		var target_fov: float = cR.cam_fov
		var speed: float = cR.reset_fov_speed

		match state_machine.curr_state_name:
			"Walk":
				target_fov += cR.walk_fov_increase
				speed = cR.walk_fov_increase_speed
			"Run":
				target_fov += cR.run_fov_increase
				speed = cR.run_fov_increase_speed

		curr_fov = lerp(curr_fov, target_fov, 1.0 - exp(-speed * delta))

	cam.fov = curr_fov


func headbob_handling(delta: float) -> void:
	"""Handle first person camera head bobbing, fading in/out with player movement"""
	var horizontal_speed: float = Vector2(cR.velocity.x, cR.velocity.z).length()
	var is_bobbing: bool = (
		cR.can_headbob
		and camera_mode == Camera.FIRST
		and state_machine.curr_state_name in ["Walk", "Run"]
		and horizontal_speed > HEADBOB_MIN_SPEED
	)
	
	if is_bobbing:
		bob_speed = horizontal_speed
		headbob_weight = move_toward(headbob_weight, 1.0, delta / cR.headbob_fade_in_time)
		headbob_time += delta * pow(bob_speed, 0.8)
		var amplitude: float = cR.headbob_amplitude * pow(bob_speed, 0.5) * smoothstep(0.0, 1.0, headbob_weight)
		# sin on both axes so a short step starts at rest instead of a full sideways offset
		headbob_offset = Vector2(
			sin(headbob_time * cR.headbob_frequency * 0.5) * amplitude,
			sin(headbob_time * cR.headbob_frequency) * amplitude
		)
	elif headbob_offset != Vector2.ZERO:
		# ease our own offset back to rest; the spring arm clears the camera position every physics tick,
		# so reading cam.position here would already be zero and the stop would snap
		var settle := 1.0 - exp(-delta / cR.headbob_fade_out_time)
		headbob_offset = headbob_offset.lerp(Vector2.ZERO, settle)
		headbob_weight = lerpf(headbob_weight, 0.0, settle)
		if headbob_offset.length() < 0.0005:
			reset_headbob()
			return
	else:
		return
	
	cam.position.x = headbob_offset.x
	cam.position.y = headbob_offset.y


func reset_headbob() -> void:
	headbob_weight = 0.0
	headbob_time = 0.0
	bob_speed = 0.0
	headbob_offset = Vector2.ZERO
	cam.position.x = 0.0
	cam.position.y = 0.0


func trigger_camera_shake() -> void:
	var period = 1.0 / cR.shake_frequency
	shake_timer = ceil(cR.shake_duration / period) * period
	shake_time = 0.0


func update_camera_shake(delta: float) -> void:
	if shake_timer > 0.0:
		shake_timer -= delta
		shake_time += delta
	
	var amplitude = cR.shake_strength
	
	# fade out amplitude in last cycle
	var period = 1.0 / cR.shake_frequency
	var time_left = shake_timer
	if time_left < period:
		amplitude *= time_left / period  # linear fade out
		cam_shake_offset.y = amplitude * sin(shake_time * TAU * cR.shake_frequency)
	else:
		cam_shake_offset.y = 0.0
		cR.shake_time = 0.0
#endregion


func _on_pose_changed():
	pass
