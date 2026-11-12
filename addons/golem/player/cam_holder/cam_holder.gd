extends SpringArm3D

var active: bool = true: set = set_active

@onready var cam: Camera3D = %Camera3D
@onready var godot_plush_skin: Node3D = %GodotPlushSkin
@onready var visual_root: Node3D = %VisualRoot
@onready var cR: CharacterBody3D = $".."
@onready var state_machine: Node = $"../StateMachine"

@export_group("Camera mode")
enum Camera {
	FIRST,
	THIRD,
	THIRD_L,
	THIRD_R
}
## Starting view: first person, third person, or an over-the-shoulder aim.
@export var camera_mode: Camera = Camera.FIRST

# HEADBOB
const HEADBOB_MIN_SPEED: float = 0.1
var headbob_time: float = 0.0
var headbob_weight: float = 0.0
var bob_speed: float = 0.0
var headbob_offset: Vector2 = Vector2.ZERO
var headbob_fade_speed: float = 0.0
# CAMERA LIMITS
var cam_limit_up: float
var cam_limit_down: float
# ZOOM
@onready var last_zoom_val: float = cR.zoom_val
@onready var curr_zoom: float = cR.zoom_val
# FOV
@onready var curr_fov: float = cR.cam_fov
# SHAKE
var cam_shake_offset: Vector3 = Vector3.ZERO
var stair_offset_y: float = 0.0
var _stair_spring_z: float = 0.0
var _stair_wrote_position: Vector3 = Vector3.ZERO
var _stair_wrote: bool = false
var shake_timer: float = 0.0
var shake_time: float = 0.0
# MODE BLEND
var mode_tween: Tween
var ragdoll_view: bool = false


func _ready() -> void:
	cR.connect("pose_changed", Callable(self, "_on_pose_changed"))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.set_use_accumulated_input(false)
	set_active(active)
	
	set_camera_mode(camera_mode, true)


func set_active(state: bool):
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


func _process(delta: float) -> void:
	if cR.can_change_zoom and camera_mode != Camera.FIRST and not ragdoll_view:
		zoom_handling(delta)
		
	if cR.can_change_fov:
		fov_handling(delta)

	headbob_handling(delta)
	update_camera_shake(delta)
	var catchup: float = cR.stair_camera_catchup
	if catchup > 0.0:
		stair_offset_y = lerpf(stair_offset_y, 0.0, 1.0 - exp(-catchup * delta))
	else:
		stair_offset_y = 0.0
	apply_camera_offsets()

	if cR.can_tilt and camera_mode == Camera.FIRST and not ragdoll_view:
		cam.rotation.z = lerp(cam.rotation.z, cR.move_dir_relative.x * cR.tilt_value, delta * cR.tilt_speed)


func set_camera_mode(new_mode: Camera, snap: bool = false) -> void:
	if camera_mode != Camera.FIRST and new_mode == Camera.FIRST:
		last_zoom_val = curr_zoom
	
	camera_mode = new_mode
	if camera_mode != Camera.FIRST:
		reset_headbob()
	
	var holder_position := Vector3.ZERO
	var spring := 0.0
	if camera_mode == Camera.FIRST:
		holder_position = first_person_holder_position()
		cam_limit_down = cR.first_limit_down
		cam_limit_up = cR.first_limit_up
		visual_root.visible = ragdoll_view
	else:
		holder_position = third_person_holder_position()
		spring = curr_zoom
		cam_limit_down = cR.third_limit_down
		cam_limit_up = cR.third_limit_up
		visual_root.visible = true
	
	var pitch := clampf(rotation.x, cam_limit_up, cam_limit_down)
	var duration: float = 0.0 if snap else cR.camera_mode_blend_time
	blend_camera(holder_position, spring, pitch, duration, camera_mode != Camera.FIRST)


func begin_ragdoll_view() -> void:
	ragdoll_view = true
	if camera_mode != Camera.FIRST:
		return
	visual_root.visible = true
	blend_camera(position, cR.zoom_val, rotation.x, cR.camera_mode_blend_time, false)


func end_ragdoll_view() -> void:
	ragdoll_view = false
	set_camera_mode(camera_mode)


func first_person_holder_position() -> Vector3:
	var height: float = cR.first_cam_crouch_height if cR.pose == cR.Pose.CROUCHED else cR.first_cam_height
	return Vector3(0.0, height, 0.0)


func third_person_holder_position() -> Vector3:
	if camera_mode == Camera.THIRD_L:
		return Vector3(-cR.aim_cam_pos.x, cR.aim_cam_pos.y, 0.0)
	if camera_mode == Camera.THIRD_R:
		return Vector3(cR.aim_cam_pos.x, cR.aim_cam_pos.y, 0.0)
	return Vector3(0.0, cR.third_cam_height, 0.0)


func blend_camera(holder_position: Vector3, spring: float, pitch: float, duration: float, clear_roll: bool) -> void:
	if mode_tween != null and mode_tween.is_valid():
		mode_tween.kill()
	mode_tween = null
	
	if duration <= 0.0:
		position = holder_position
		spring_length = spring
		rotation.x = pitch
		if clear_roll:
			cam.rotation.z = 0.0
		return
	
	mode_tween = create_tween()
	mode_tween.set_parallel(true)
	mode_tween.tween_property(self, "position", holder_position, duration)
	mode_tween.tween_property(self, "spring_length", spring, duration)
	mode_tween.tween_property(self, "rotation:x", pitch, duration)
	if clear_roll:
		mode_tween.tween_property(cam, "rotation:z", 0.0, duration)


#region HANDLINGS
func zoom_handling(delta: float) -> void:
	var zoom_input: float = Input.get_axis(cR.cam_zoom_in_action, cR.cam_zoom_out_action)
	
	if zoom_input != 0.0:
		curr_zoom += zoom_input * cR.zoom_speed * delta
		curr_zoom = clamp(curr_zoom, cR.min_zoom_val, cR.max_zoom_val)
	
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
		headbob_fade_speed = 0.0
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
		# Cover the remaining offset in headbob_fade_out_time. The spring arm clears cam.position
		# every physics tick, so the fade has to live on headbob_offset and be rewritten each frame.
		if headbob_fade_speed <= 0.0:
			headbob_fade_speed = headbob_offset.length() / cR.headbob_fade_out_time
		headbob_offset = headbob_offset.move_toward(Vector2.ZERO, headbob_fade_speed * delta)
		headbob_weight = move_toward(headbob_weight, 0.0, delta / cR.headbob_fade_out_time)
		if headbob_offset.length() < 0.0005:
			reset_headbob()
	else:
		return


func reset_headbob() -> void:
	headbob_weight = 0.0
	headbob_time = 0.0
	bob_speed = 0.0
	headbob_fade_speed = 0.0
	headbob_offset = Vector2.ZERO
	cam.position.x = 0.0
	cam.position.y = 0.0


func trigger_camera_shake() -> void:
	if cR.shake_frequency <= 0:
		return
	shake_timer = cR.shake_duration
	shake_time = 0.0


func update_camera_shake(delta: float) -> void:
	if shake_timer <= 0.0 or cR.shake_frequency <= 0:
		cam_shake_offset = Vector3.ZERO
		if shake_timer <= 0.0:
			shake_time = 0.0
		return
	
	shake_timer -= delta
	shake_time += delta
	var amplitude: float = cR.shake_strength * clampf(shake_timer / cR.shake_duration, 0.0, 1.0)
	cam_shake_offset.y = amplitude * sin(shake_time * TAU * cR.shake_frequency)


func note_stair_step(world_delta_y: float) -> void:
	stair_offset_y -= world_delta_y


func apply_camera_offsets() -> void:
	# Reapplied every frame: the spring arm clears the camera between physics ticks.
	# The holder pitches, so the stair catch-up is world up expressed in local space.
	var local_stair: Vector3 = global_basis.inverse() * Vector3(0.0, stair_offset_y, 0.0)
	var spring_z: float = cam.position.z
	if _stair_wrote and cam.position.is_equal_approx(_stair_wrote_position):
		spring_z = _stair_spring_z
	_stair_spring_z = spring_z
	cam.position = Vector3(
		headbob_offset.x + cam_shake_offset.x + local_stair.x,
		headbob_offset.y + cam_shake_offset.y + local_stair.y,
		spring_z + local_stair.z
	)
	_stair_wrote_position = cam.position
	_stair_wrote = true
#endregion


func _on_pose_changed() -> void:
	if camera_mode != Camera.FIRST or ragdoll_view:
		return
	var duration: float = cR.crouching_speed if cR.pose == cR.Pose.CROUCHED else cR.standing_speed
	blend_camera(first_person_holder_position(), spring_length, rotation.x, duration, false)
