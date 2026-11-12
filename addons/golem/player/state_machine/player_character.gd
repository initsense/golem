extends CharacterBody3D

const StairStep := preload("res://addons/golem/player/state_machine/stair_step.gd")
const WallClimb := preload("res://addons/golem/player/state_machine/wall_climb.gd")
const LedgeClimb := preload("res://addons/golem/player/state_machine/ledge_climb.gd")


@export_category("Camera")

@export_group("Position")
## Eye height of the first-person camera, in meters.
@export var first_cam_height : float = 1.5
## Eye height of the third-person camera, in meters.
@export var third_cam_height : float = 1.5
## Aim-camera offset from the player: x is sideways meters, y is height in meters.
@export var aim_cam_pos : Vector2 = Vector2(1.6, 0.8)
## Seconds to blend holder position, distance, and pitch when the camera mode changes.
@export_range(0.0, 2.0, 0.01, "suffix:s") var camera_mode_blend_time : float = 0.25

@export_group("Crouch")
enum Pose {
	STANDING,
	CROUCHED
	}
## First-person eye height while crouched, in meters.
@export var first_cam_crouch_height: float = 0.4
## Seconds to blend the camera up to standing height.
@export_range(0.05, 2.0, 0.01, "suffix:s") var standing_speed: float = 0.2
## Seconds to blend the camera down to crouch height.
@export_range(0.05, 2.0, 0.01, "suffix:s") var crouching_speed: float = 0.2

@onready var pose: Pose = Pose.STANDING
## Movement speed while crouched, in meters per second.
@export var crouch_speed: float = 1.6
const CROUCH_TRANSLATE: float = 0.7
const CROUCH_JUMP_ADD: float = CROUCH_TRANSLATE * 0.9
@onready var original_capsule_height = %CollisionCapsule.shape.height

@export_group("Head bob")
## Enables the first-person head bob while walking or running.
@export var can_headbob: bool = true
## Head-bob distance from rest, in meters, before speed scaling.
@export var headbob_amplitude : float = 0.03
## Head-bob cycles per second at a speed scale of 1.
@export var headbob_frequency : float = 2.3
## Seconds for the head bob to ease in after movement starts.
@export_range(0.05, 5.0, 0.05, "suffix:s") var headbob_fade_in_time : float = 1.0
## Seconds for the camera to ease back to rest after movement stops.
@export_range(0.05, 5.0, 0.05, "suffix:s") var headbob_fade_out_time : float = 0.35

@export_group("Side tilt")
## Enables first-person camera roll while strafing.
@export var can_tilt: bool = true
## Maximum camera roll, in radians, at full strafe input.
@export_range(0.0, 0.1, 0.005) var tilt_value: float = 0.02
## How quickly the roll follows the strafe input.
@export_range(0.0, 20.0, 0.1) var tilt_speed: float = 4.0

@export_group("Camera movement")
## Mouse look multiplier. Higher values turn the camera faster.
@export_range(0.0, 0.005, 0.0005) var mouse_sens : float = 0.002
## Not applied. Reserved look-speed value with no current effect.
@export_range(0.0, 20.0, 0.01) var pan_rotation_val : float = 2.0
@export_subgroup("First person limits")
## Lowest first-person look angle. Negative looks up.
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var first_limit_up : float = -1.4
## Highest first-person look angle. Positive looks down.
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var first_limit_down : float = 1.4
@export_subgroup("Third person limits")
## Lowest third-person look angle. Negative looks up.
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var third_limit_up : float = -1.4
## Highest third-person look angle. Positive looks down.
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var third_limit_down : float = 0.8

@export_group("FOV")
## Enables manual FOV keys and the walk/run FOV widen.
@export var can_change_fov: bool = true
## Resting camera field of view, in degrees.
@export var cam_fov: float = 90.0
## Degrees per second while an FOV key is held.
@export var fov_speed: float = 32.0
## Lowest field of view the keys can reach, in degrees.
@export var min_fov: float = 30.0
## Highest field of view the keys can reach, in degrees.
@export var max_fov: float = 150.0
## Extra degrees added to the field of view while walking.
@export var walk_fov_increase: float = 4.0
## Extra degrees added to the field of view while running.
@export var run_fov_increase: float = 10.0
## How quickly the field of view widens while walking.
@export var walk_fov_increase_speed: float = 2.0
## How quickly the field of view widens while running.
@export var run_fov_increase_speed: float = 2.0
## How quickly the field of view returns to rest.
@export var reset_fov_speed: float = 2.0

@export_group("Shake")
## Shakes the camera once when landing from a fall.
@export var can_landing_shake: bool = true
## Landing-shake distance, in meters.
@export var shake_strength : float = 0.06
## Landing-shake length, in seconds. Amplitude fades across this time.
@export var shake_duration : float = 0.1
## Landing-shake cycles per second. Zero disables the oscillation.
@export var shake_frequency: int = 3

@export_group("Zoom")
## Enables the third-person zoom keys.
@export var can_change_zoom: bool = true
## Starting third-person camera distance, in meters.
@export var zoom_val : float = 3.0
## Meters per second while a zoom key is held.
@export var zoom_speed : float = 4.0
## Farthest third-person camera distance, in meters.
@export var max_zoom_val : float = 10.0
## Nearest third-person camera distance, in meters.
@export var min_zoom_val : float = 2.0


@export_category("Movement")

#movement variables
var move_speed : float
var move_accel : float
var move_deccel : float
var move_dir_relative: Vector2
var move_dir : Vector2
var target_angle : float
var last_input_dir : Vector2
var last_frame_position : Vector3
var last_frame_velocity : Vector3
var was_on_floor : bool = false
var stair_floor_hold: float = 0.0
var walk_or_run : String = "WalkState" #keep in memory if play char was walking or running before being in the air
## A jump that started crouched stands at takeoff. Landing stands again if crouch was pressed in the air.
var uncrouch_on_land: bool = false

@export_group("Walk")
## Ground walk speed, in meters per second.
@export var walk_speed : float = 5.0
## How quickly walking reaches walk speed.
@export var walk_accel : float = 8.0
## How quickly walking slows to a stop.
@export var walk_deccel : float = 7.5

@export_group("Run")
## Ground run speed, in meters per second. A directed jump in the run gait aims for this speed.
@export var run_speed : float = 10.0
## How quickly running reaches run speed.
@export var run_accel : float = 3.5
## How quickly running slows to a stop.
@export var run_deccel : float = 6.5
## When enabled, one press toggles running. Otherwise the run key must be held.
@export var can_continuous_run : bool = false

@export_group("Jump")
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
## Jump apex height, in meters.
@export var jump_height : float = 5.0
## Seconds to rise from the ground to the jump apex.
@export var jump_time_to_peak : float = 0.7
## Seconds to fall from the jump apex back to the ground.
@export var jump_time_to_descent : float = 0.4
@onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
## Seconds after a jump before another jump is allowed.
@export var jump_cooldown : float = 0.2
var jump_cooldown_ref : float
## Extra jumps allowed before landing. Zero means ground jumps only.
@export var nb_jumps_in_air_allowed : int = 0
var nb_jumps_in_air_allowed_ref : int
var jump_buff_on : bool = false
var buffered_jump : bool = false
## Seconds after walking off a ledge during which a jump is still allowed.
@export var coyote_jump_cooldown : float = 0.2
var coyote_jump_cooldown_ref : float = 0.2
var coyote_jump_on : bool = false
## Keeps jumping if you keep the key pressed.
@export var can_auto_jump : bool = false
 
@export_group("In air")
@onready var fall_gravity : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0
## Zeroes horizontal speed on a wall hit while in the air.
@export var can_hit_wall_cut_velocity : bool = false

@export_group("Stairs")
## Steps up and down low ledges instead of stopping on the riser.
@export var can_climb_stairs: bool = true
## Tallest ledge, in meters, that still counts as a step.
@export var step_height: float = 0.5
## Steepest floor angle, in degrees, that a step can land on.
@export_range(0.0, 89.0, 1.0) var step_max_slope_degrees: float = 40.0
## How quickly the camera catches the body after a stair snap.
@export_range(0.0, 30.0, 0.1) var stair_camera_catchup: float = 8.0

@export_group("Ledges")
## Hops onto a ledge when a jump reaches it. Walking into the face does not.
@export var can_climb_ledges: bool = true
## Highest lip above the feet, in meters, that a jump can still hop onto.
@export var ledge_max_height: float = 1.5
var ledge_pulling: bool = false
var ledge_block_wall_cut: bool = false
var ledge_jump_launched: bool = false
var ledge_elapsed: float = 0.0
var ledge_start: Vector3 = Vector3.ZERO
var ledge_target: Vector3 = Vector3.ZERO
var ledge_face_normal: Vector3 = Vector3.FORWARD

@export_group("Walls")
## A jump into a wall climbs briefly, then the lift fades.
@export var can_climb_walls: bool = true
## Extra rise, in meters, if you stay on the face for the whole climb.
@export var wall_climb_height: float = 1.2
## Seconds before the wall lift is gone.
@export var wall_climb_time: float = 0.4
var wall_climbing: bool = false
var wall_climb_armed: bool = false
var wall_climb_spent: bool = false
var wall_climb_elapsed: float = 0.0


@export_category("Model")

@export_group("Rotation")
## How quickly the model turns toward its facing direction, in radians per second.
@export var model_rot_speed : float
## When enabled, the model faces the camera while aiming left or right.
@export var can_follow_cam_pos_when_aimed : bool = false

@export_group("Ragdoll")
## Not applied. The body follows the ragdoll hips instead of this gravity.
@export var ragdoll_gravity : float
## When enabled, ragdoll can only start and stop while standing on the floor.
@export var can_ragdoll_on_floor_only : bool = false


#region KEYBINDINGS
@export_category("Keybinding")

@export_group("Movement")
## Input action name for moving forward.
@export var moveForwardAction : String = ""
## Input action name for moving backward.
@export var moveBackwardAction : String = ""
## Input action name for moving left.
@export var moveLeftAction : String = ""
## Input action name for moving right.
@export var moveRightAction : String = ""
## Input action name for running.
@export var runAction : String = ""
## Input action name for jumping.
@export var jumpAction : String = ""

@export_group("Camera")
## Input action name that toggles captured mouse look.
@export var mouse_mode_action : String = "toggle_mouse_mode"
## Input action name that moves the third-person camera closer.
@export var cam_zoom_in_action : String = "zoom_in"
## Input action name that moves the third-person camera farther.
@export var cam_zoom_out_action : String = "zoom_out"
## Input action name that narrows the field of view.
@export var cam_fov_decrease : String = "fov_decrease"
## Input action name that widens the field of view.
@export var cam_fov_increase : String = "fov_increase"
#endregion


#region REFERENCE VARIABLES
@onready var visual_root = %VisualRoot
@onready var godot_plush_skin = %GodotPlushSkin
@onready var particles_manager = %ParticlesManager
@onready var cam_holder = %CamHolder
@onready var state_machine = $StateMachine
@onready var debug_hud = %DebugHUD
@onready var foot_step_audio = %FootStepAudio
@onready var impact_audio = %ImpactAudio
@onready var wave_audio = %WaveAudio
@onready var collision_capsule = %CollisionCapsule
@onready var floor_check : RayCast3D = %FloorRaycast

# particles variables
@onready var movement_dust = %MovementDust
@onready var jump_particles = preload("res://addons/golem/player/vfx/jump_particles.tscn")
@onready var land_particles = preload("res://addons/golem/player/vfx/land_particles.tscn")
#endregion


signal pose_changed


func _ready():
	#set move variables, and value references
	move_speed = walk_speed
	move_accel = walk_accel
	move_deccel = walk_deccel
	
	jump_cooldown_ref = jump_cooldown
	nb_jumps_in_air_allowed_ref = nb_jumps_in_air_allowed
	coyote_jump_cooldown_ref = coyote_jump_cooldown
	
	#set char model audios effects
	godot_plush_skin.footstep.connect(func(intensity : float = 1.0):
		foot_step_audio.volume_db = linear_to_db(intensity)
		foot_step_audio.play()
		)


func _process(delta: float):
	modify_model_orientation(delta)
	display_properties()


func _physics_process(delta: float) -> void:
	modify_physics_properties()
	StairStep.apply(self, delta)
	WallClimb.apply(self, delta)
	LedgeClimb.apply(self, delta)
	move_and_slide()
	#print(move_speed)


func display_properties():
	#display play char properties
	debug_hud.display_curr_state(state_machine.curr_state_name)
	debug_hud.display_velocity(velocity.length())
	debug_hud.display_nb_jumps_in_air_allowed(nb_jumps_in_air_allowed)
	debug_hud.display_jump_buffer(jump_buff_on)
	debug_hud.display_coyote_time(coyote_jump_cooldown)


func modify_model_orientation(delta : float):
	#manage the model rotation depending on the camera mode + char parameters
	
	var dir_target_angle : float
	
	#follow mode (model must follow the camera rotation)
	#if the cam is in angled/aim mode
	if ( cam_holder.camera_mode in [cam_holder.Camera.THIRD_L, cam_holder.Camera.THIRD_R]
	and can_follow_cam_pos_when_aimed and not godot_plush_skin.ragdoll ):
		#get cam rotation on the y axis (+ PI to invert half circle, and be sure that the model is correctly oriented)
		dir_target_angle = (cam_holder.cam.global_rotation.y) + PI
		#rotate the model on the y axis
		visual_root.rotation.y = rotate_toward(visual_root.rotation.y, dir_target_angle, model_rot_speed * delta)
	
	#free mode (the model orientation is independant to the camera one)
	if (cam_holder.camera_mode in [cam_holder.Camera.THIRD, cam_holder.Camera.FIRST] or not can_follow_cam_pos_when_aimed) and move_dir != Vector2.ZERO:
		#get char move direction
		dir_target_angle = -move_dir.orthogonal().angle()
		#rotate the model on the y axis
		visual_root.rotation.y = rotate_toward(visual_root.rotation.y, dir_target_angle, model_rot_speed * delta)


func modify_physics_properties():
	last_frame_position = position #get play char position every frame
	last_frame_velocity = velocity #get play char velocity every frame
	was_on_floor = not is_on_floor() #get if play char is on floor or not


func apply_air_move(delta: float) -> void:
	if not move_dir or is_on_floor():
		return
	var target_speed := walk_speed
	var accel := walk_accel
	if walk_or_run == "RunState":
		target_speed = run_speed
		accel = run_accel
	var target := Vector3(move_dir.x, 0.0, move_dir.y) * target_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var steered := horizontal.lerp(target, clampf(accel * delta, 0.0, 1.0))
	velocity.x = steered.x
	velocity.z = steered.z


func apply_gravity(delta : float):
	if velocity.y >= 0.0:
		velocity.y -= jump_gravity * delta
	else:
		velocity.y -= fall_gravity * delta


func squash_and_strech(value : float, timing : float):
	#create a tween that simulate a compression of the model (squash and strech ones)
	#maily used to accentuate game feel/juice
	#call the squash_and_strech function of the model (it's this function that actually squash and strech the model)
	var sasTween : Tween = create_tween()
	sasTween.set_ease(Tween.EASE_OUT)
	sasTween.tween_property(godot_plush_skin, "squash_and_stretch", value, timing)
	sasTween.tween_property(godot_plush_skin, "squash_and_stretch", 1.0, timing * 1.8)


func toggle_crouch(state_speed: float) -> void:
	if pose == Pose.STANDING:
		pose = Pose.CROUCHED
		move_speed = crouch_speed
		walk_or_run = "WalkState"
		print("crouched")
	elif pose == Pose.CROUCHED:
		pose = Pose.STANDING
		move_speed = state_speed
		print("standing")
	emit_signal("pose_changed")


func release_crouch_on_land() -> void:
	if not uncrouch_on_land:
		return
	uncrouch_on_land = false
	if pose != Pose.CROUCHED:
		return
	pose = Pose.STANDING
	emit_signal("pose_changed")
