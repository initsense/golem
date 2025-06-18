extends CharacterBody3D


@export var look_sensitivity: float = 0.003
@export var controller_look_sensitivity: float = 0.05

@export var jump_velocity: float = 10.0
@export var auto_bhop: bool = true

# HEADBOB
const HEADBOB_MOVE_AMOUNT: float = 0.06
const HEADBOB_FREQUENCY: float = 2.4
var headbob_time: float = 0.0

# GROUND
@export var walk_speed: float = 7.0
@export var sprint_speed: float = 8.5
@export var ground_accel: float = 14.0
@export var ground_decel: float = 10.0
@export var ground_friction: float = 6.0

# AIR
@export var air_cap: float = 0.85 # Can surf steeper ramps if this is higher, makes it easier to stick and bhop.
@export var air_accel: float = 800.0
@export var air_move_speed: float = 500.0

# SWIM
@export var swim_up_speed: float = 10.0


var wish_dir: Vector3 = Vector3.ZERO
var cam_aligned_wish_dir: Vector3 = Vector3.ZERO

const CROUCH_TRANSLATE: float = 0.7
const CROUCH_JUMP_ADD: float = CROUCH_TRANSLATE * 0.9
var is_crouched: bool = false

var noclip_speed_mult: float = 3.0
var noclip: bool = false

const MAX_STEP_HEIGHT: float  = 0.5
var _snapped_to_stairs_last_frame: bool= false
var _last_frame_was_on_floor = -INF


func get_move_speed() -> float:
	if is_crouched:
		return walk_speed * 0.8
	return sprint_speed if Input.is_action_pressed("sprint") else walk_speed


func _ready():
	# Everything in the WorldModel will be on the second visual layer.
	# By deselecting the Camera3D's second layer we can hide what's inside WorldModel.
	for child in %WorldModel.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)
	pass


# We use the unhandled input in order to NOT interfere with the UI. 
# This is to prevent the InitCharacter from stealing the UI input.
func _unhandled_input(event):
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * look_sensitivity)
			%Camera3D.rotate_x(-event.relative.y * look_sensitivity)
			%Camera3D.rotation.x = clamp(%Camera3D.rotation.x, deg_to_rad(-90), deg_to_rad(90))
			
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			noclip_speed_mult = min(100.0, noclip_speed_mult * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			noclip_speed_mult = max(0.1, noclip_speed_mult * 0.9)


func _headbob_effect(delta: float):
	# Headbob proportional to the player's velocity.
	headbob_time += delta * self.velocity.length()
	%Camera3D.transform.origin = Vector3(
		cos(headbob_time * HEADBOB_FREQUENCY * 0.5) * HEADBOB_MOVE_AMOUNT, # Side to side movement.
		sin(headbob_time * HEADBOB_FREQUENCY) * HEADBOB_MOVE_AMOUNT, # Up and down movement. 0.5 is omitted in order to make it faster.
		0
	)

# Smoothly interpolated controller look with acceleration and deceleration.
# TODO: Map it to the analog stick.
var _cur_controller_look = Vector2()


func _handle_controller_look_input(delta: float):
	var target_look = Input.get_vector("look_left", "look_right", "look_down", "look_up").normalized()
	
	if target_look.length() < _cur_controller_look.length():
		_cur_controller_look = target_look
	else:
		_cur_controller_look = _cur_controller_look.lerp(target_look, 5.0 * delta)
	
	rotate_y(-_cur_controller_look.y * controller_look_sensitivity) # Turn left and right.
	%Camera3D.rotate_x(_cur_controller_look.y * controller_look_sensitivity) # Look up and down.
	%Camera3D.rotation.x = clamp(%Camera3D.rotation.x, deg_to_rad(-90), deg_to_rad(90))


func _process(delta: float):
	_handle_controller_look_input(delta)


var _saved_camera_global_pos = null
func _save_camera_pos_for_smoothing():
	if _saved_camera_global_pos == null:
		_saved_camera_global_pos = %CameraSmooth.global_position


func _push_away_rigid_bodies():
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_collider() is RigidBody3D:
			var push_dir = -c.get_normal()
			# How much velocity the object need sto increase to match player velocity in the push direction.
			var velocity_diff_in_push_dir = self.velocity.dot(push_dir) - c.get_collider().linear_velocity.dot(push_dir)
			# Only count velocity towards push dir, away from character.
			velocity_diff_in_push_dir = max(0., velocity_diff_in_push_dir)
			# Objects with more mass than us should be harder to push. But doesn't really make sense to push faster than we are going.
			const MY_APPROX_MASS_KG = 80.0
			var mass_ratio = min(1., MY_APPROX_MASS_KG / c.get_collider().mass)
			# Don't push object from above/below
			push_dir.y = 0
			# Adjust to your needs.
			var push_force = mass_ratio * 5.0
			c.get_collider().apply_impulse(push_dir * velocity_diff_in_push_dir * push_force, c.get_position() - c.get_collider().global_position)
					
func _slide_camera_smooth_back_to_origin(delta):
	if _saved_camera_global_pos == null: return
	%CameraSmooth.global_position.y = _saved_camera_global_pos.y
	%CameraSmooth.position.y = clampf(%CameraSmooth.position.y, -0.7, 0.7)
	var move_amount = max(self.velocity.length() * delta, walk_speed / 2 * delta)
	%CameraSmooth.position.y = move_toward(%CameraSmooth.position.y, 0.0, move_amount)
	_saved_camera_global_pos = %CameraSmooth.global_position
	
	if %CameraSmooth.position.y == 0:
		_saved_camera_global_pos = null # Stop smoothing.
	
func _snap_down_to_stairs_check() -> void:
	var did_snap := false
	var floor_below: bool = %StairsBelowRayCast3D.is_colliding and not is_surface_too_steep(%StairsBelowRayCast3D.get_collision_normal())
	var was_on_floor_last_frame = Engine.get_physics_frames() - _last_frame_was_on_floor == 1
	
	if not is_on_floor() and velocity.y <= 0 and (was_on_floor_last_frame or _snapped_to_stairs_last_frame) and floor_below:
		var body_test_result = PhysicsTestMotionResult3D.new()
		if _run_body_test_motion(self.global_transform, Vector3(0, -MAX_STEP_HEIGHT, 0), body_test_result):
			_save_camera_pos_for_smoothing()
			var translate_y = body_test_result.get_travel().y
			self.position.y += translate_y
			apply_floor_snap()
			did_snap = true
	_snapped_to_stairs_last_frame = did_snap


func _snap_up_stairs_check(delta) -> bool:
	if not is_on_floor() and not _snapped_to_stairs_last_frame: return false
	# Don't snap stairs if trying to jump, also no need to check for stairs ahead if not moving
	if self.velocity.y > 0 or (self.velocity * Vector3(1,0,1)).length() == 0: return false
	var expected_move_motion = self.velocity * Vector3(1,0,1) * delta
	var step_pos_with_clearance = self.global_transform.translated(expected_move_motion + Vector3(0, MAX_STEP_HEIGHT * 2, 0))
	# Run a body_test_motion slightly above the pos we expect to move to, towards the floor.
	# We give some clearance above to ensure there's ample room for the player.
	# If it hits a step <= MAX_STEP_HEIGHT, we can teleport the player on top of the step
	# along with their intended motion forward.
	var down_check_result = KinematicCollision3D.new()
	if (self.test_move(step_pos_with_clearance, Vector3(0,-MAX_STEP_HEIGHT*2,0), down_check_result)
	and (down_check_result.get_collider().is_class("StaticBody3D") or down_check_result.get_collider().is_class("CSGShape3D"))):
		var step_height = ((step_pos_with_clearance.origin + down_check_result.get_travel()) - self.global_position).y
		# Note I put the step_height <= 0.01 in just because I noticed it prevented some physics glitchiness
		# 0.02 was found with trial and error. Too much and sometimes get stuck on a stair. Too little and can jitter if running into a ceiling.
		# The normal character controller (both jolt & default) seems to be able to handled steps up of 0.1 anyway
		if step_height > MAX_STEP_HEIGHT or step_height <= 0.01 or (down_check_result.get_position() - self.global_position).y > MAX_STEP_HEIGHT: return false
		%StairsAheadRayCast3D.global_position = down_check_result.get_position() + Vector3(0, MAX_STEP_HEIGHT, 0) + expected_move_motion.normalized() * 0.1
		%StairsAheadRayCast3D.force_raycast_update()
		if %StairsAheadRayCast3D.is_colliding() and not is_surface_too_steep(%StairsAheadRayCast3D.get_collision_normal()):
			_save_camera_pos_for_smoothing()
			self.global_position = step_pos_with_clearance.origin + down_check_result.get_travel()
			apply_floor_snap()
			_snapped_to_stairs_last_frame = true
			return true
	return false

func _handle_noclip(delta) -> bool:
	if Input.is_action_just_pressed("_noclip") and OS.has_feature("debug"): # has_feature is an interesting tool to know if you're on different platforms or more.
		noclip = not noclip
		noclip_speed_mult = 3.0
	
	$CollisionShape3D.disabled = noclip # Equivalent to self.get_node("CollisionShape3D")
	
	if not noclip:
		return false
		
	var speed = get_move_speed() * noclip_speed_mult
	if Input.is_action_pressed("sprint"):
		speed *= 3.0
		
	self.velocity = cam_aligned_wish_dir * speed # GMOD style noclipping!
	global_position += self.velocity * delta
	
	return true

@onready var _original_capsule_height = $CollisionShape3D.shape.height
func _handle_crouch(delta) -> void:
	var was_crouched_last_frame = is_crouched
	# Prevents clipping by testing the move of the player in tight places before doing it explicitly.
	if Input.is_action_pressed("crouch"):
		is_crouched = true
	elif is_crouched and not self.test_move(self.global_transform, Vector3(0, CROUCH_TRANSLATE, 0)):
		is_crouched = false
	
	# Allow for crouch to heighten/extend a jump
	var translate_y_if_possible := 0.0
	if was_crouched_last_frame != is_crouched and not is_on_floor() and not _snapped_to_stairs_last_frame:
		translate_y_if_possible = CROUCH_JUMP_ADD if is_crouched else -CROUCH_JUMP_ADD
	# Make sure not to get the player stuck in floor/ceiling during crouch jumps.
	if translate_y_if_possible != 0.0:
		var result = KinematicCollision3D.new()
		self.test_move(self.global_transform, Vector3(0, translate_y_if_possible, 0), result)
		self.position.y += result.get_travel().y
		%Head.position.y -= result.get_travel().y
		%Head.position.y = clampf(%Head.position.y, -CROUCH_TRANSLATE, 0)
		
	%Head.position.y = move_toward(%Head.position.y, -CROUCH_TRANSLATE if is_crouched else 0, 7.0 * delta)
	$CollisionShape3D.shape.height = _original_capsule_height - CROUCH_TRANSLATE if is_crouched else _original_capsule_height
	$CollisionShape3D.position.y = $CollisionShape3D.shape.height / 2

# Returns true if the player is in water, don't run normal air/ground physics in that case.
func _handle_water_physics(delta) -> bool:
	if get_tree().get_nodes_in_group("water_area").all(func(area): return not area.overlaps_body(self)):
		return false
	
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * 0.1 * delta
	
	self.velocity += cam_aligned_wish_dir * get_move_speed() * delta
	
	if Input.is_action_pressed("jump"):
		self.velocity.y += swim_up_speed * delta
	
	# Dampen velocity when in water
	self.velocity = self.velocity.lerp(Vector3.ZERO, 2 * delta)
	
	return true

func clip_velocity(normal: Vector3, overbounce: float, delta: float) -> void:
	# When strafing into wall + gravity, velocity will be pointing much in the opposite direction of the normal.
	# With this we will back up and off of the wall, cancelling out our strafe + graviity, allowing surf.
	var backoff := self.velocity.dot(normal) * overbounce
	
	# Prevents getting stuck in ceilings!
	if backoff >= 0: return
	
	var change := normal * backoff
	self.velocity -= change
	
	# Second iteration to make sure the player is not still moving through the plane.
	var adjust := self.velocity.dot(normal)
	if adjust < 0.0:
		self.velocity -= normal * adjust

func is_surface_too_steep(normal: Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > self.floor_max_angle

func _run_body_test_motion(from: Transform3D, motion: Vector3, result = null) -> bool:
	if not result: result = PhysicsTestMotionResult3D.new()
	var params = PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	
	return PhysicsServer3D.body_test_motion(self.get_rid(), params, result)

func _handle_air_physics(delta: float) -> void:
	self.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir) # How fast is the player moving in the direction it wants to move.
	
	var capped_speed = min((air_move_speed * wish_dir).length(), air_cap) 	# Wish speed capped to air_cap.
	
	var add_speed_till_cap = capped_speed - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = air_accel * air_move_speed * delta
		accel_speed = min(accel_speed, add_speed_till_cap) # Makes sure that velocity isn't increased past the speed cap.
		self.velocity += accel_speed * wish_dir
		
	if is_on_wall():
		# Floating mode is much better and less jittery for surf when the surface is too steep.
		if is_surface_too_steep(get_wall_normal()):
			self.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		else:
			self.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
		clip_velocity(get_wall_normal(), 1, delta) # Allows surf
	
func _handle_ground_physics(delta: float) -> void:
	# Similar to the air movement. Acceleration and friction on the ground.
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	var add_speed_till_cap = get_move_speed() - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = ground_accel * delta * get_move_speed()
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * wish_dir
		
	# Apply friction
	var control = max(self.velocity.length(), ground_decel)
	var drop = control * ground_friction * delta # How much should the velocity drop at each frame.
	var new_speed = max(self.velocity.length() - drop, 0.0)
	if self.velocity.length() > 0:
		new_speed /= self.velocity.length()
	self.velocity *= new_speed
	
	_headbob_effect(delta)

func _physics_process(delta: float) -> void:
	if is_on_floor(): _last_frame_was_on_floor = Engine.get_physics_frames()
	
	var input_dir = Input.get_vector("left", "right", "up", "down").normalized()
	# We map the direction to the x and z because, of course, Input is a 2D Vector.
	# Depending on which way the character is facing, input directions may have to be negated.
	# Anything multiplied by the basis gets rotated and scaled to the whatever transform we are using.
	# In this case it rotates the input direction so that it's relative to the character.
	wish_dir = self.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)
	# Multiplying the input dir with the camera basis allows it to respond to up and down movement.
	cam_aligned_wish_dir = %Camera3D.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y) 
	
	_handle_crouch(delta)

	if not _handle_noclip(delta):
		if not _handle_water_physics(delta):
			if is_on_floor() or _snapped_to_stairs_last_frame:
				if Input.is_action_just_pressed("jump") or (auto_bhop and Input.is_action_pressed("jump")): # Continuous jumping or not.
					self.velocity.y = jump_velocity
				_handle_ground_physics(delta)
			else:
				_handle_air_physics(delta)
		
		if not _snap_up_stairs_check(delta):
			# Because _snap_up_stairs_check moves the body manually, don't call move_and_slide
			# This should be fine since we ensure with the body_test_motion that it doesn't 
			# collide with anything except the stairs it's moving up to.
			# _push_away_rigid_bodies() 
			_push_away_rigid_bodies() # Call before move_and_slide()
			move_and_slide()
			_snap_down_to_stairs_check()
	
	_slide_camera_smooth_back_to_origin(delta)
