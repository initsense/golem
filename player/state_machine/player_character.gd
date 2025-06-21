extends CharacterBody3D


@export_category("Camera")

@export_group("Position")
@export var first_cam_height : float = 1.5
@export var third_cam_height : float = 1.5
@export var aim_cam_pos : Vector2 = Vector2(1.6, 0.8)

@export_group("Crouch")
enum Pose {
	STANDING,
	CROUCHED
	}
@export var first_cam_crouch_height: float = 0.6
@export var standing_speed: float = 0.1
@export var crouching_speed: float = 0.1

@onready var pose: Pose = Pose.STANDING
@export var crouch_speed: float = 1.6
const CROUCH_TRANSLATE: float = 0.7
const CROUCH_JUMP_ADD: float = CROUCH_TRANSLATE * 0.9
@onready var original_capsule_height = %CollisionCapsule.shape.height

@export_group("Head bob")
@export var headbob_amplitude : float = 0.03
@export var headbob_frequency : float = 2.3

@export_group("Camera movement")
@export_range(0.0, 0.005, 0.0005) var mouse_sens : float = 0.002
@export_range(0.0, 20.0, 0.01) var pan_rotation_val : float = 2.0
@export_subgroup("First person limits")
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var first_limit_up : float = -1.4
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var first_limit_down : float = 1.4
@export_subgroup("Third person limits")
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var third_limit_up : float = -1.4
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var third_limit_down : float = 0.8

@export_group("FOV")
@export var cam_fov : float = 90
@export var fov_speed : float = 32.0
@export var min_fov : float = 30.0
@export var max_fov : float = 150.0

@export_group("Zoom")
@export var zoom_val : float = 3.0
@export var zoom_speed : float = 4.0
@export var max_zoom_val : float = 8.0
@export var min_zoom_val : float = 1.0


@export_category("Movement")

#movement variables
var move_speed : float
var move_accel : float
var move_deccel : float
var move_dir : Vector2
var target_angle : float
var last_input_dir : Vector2
var last_frame_position : Vector3
var last_frame_velocity : Vector3
var was_on_floor : bool = false
var walk_or_run : String = "WalkState" #keep in memory if play char was walking or running before being in the air

@export_group("Walk")
@export var walk_speed : float = 5.0
@export var walk_accel : float = 8.0
@export var walk_deccel : float = 7.5

@export_group("Run")
@export var run_speed : float = 10.0
@export var run_accel : float = 3.5
@export var run_deccel : float = 6.5
@export var continious_run : bool = false #if true, doesn't need to keep run button on to run

@export_group("Jump")
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@export var jump_height : float = 5.0
@export var jump_time_to_peak : float = 0.7
@export var jump_time_to_descent : float = 0.4
@onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
var has_cut_jump : bool = false
@export var jump_cut_multiplier : float = 0.5
@export var jump_cooldown : float = 0.2
var jump_cooldown_ref : float
@export var nb_jumps_in_air_allowed : int = 1
var nb_jumps_in_air_allowed_ref : int
var jump_buff_on : bool = false
var buffered_jump : bool = false
@export var coyote_jump_cooldown : float
var coyote_jump_cooldown_ref : float = 0.2
var coyote_jump_on : bool = false
@export var auto_jump : bool = false
 
@export_group("In air")
@onready var fall_gravity : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0
@export var in_air_move_speed : Array[Curve]
@export var in_air_accel : Array[Curve]
@export var hit_wall_cut_velocity : bool = false


@export_category("Model")

@export_group("Rotation")
@export var model_rot_speed : float
@export var follow_cam_pos_when_aimed : bool = false

@export_group("Ragdoll")
@export var ragdoll_gravity : float
@export var ragdoll_on_floor_only : bool = false


#region KEYBINDINGS
@export_category("Keybinding")

@export_group("Movement")
@export var moveForwardAction : String = ""
@export var moveBackwardAction : String = ""
@export var moveLeftAction : String = ""
@export var moveRightAction : String = ""
@export var runAction : String = ""
@export var jumpAction : String = ""

@export_group("Camera")
@export var mouse_mode_action : String = "toggle_mouse_mode"
@export var cam_zoom_in_action : String = "zoom_in"
@export var cam_zoom_out_action : String = "zoom_out"
@export var cam_fov_decrease : String = "fov_decrease"
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
@onready var jump_particles = preload("res://player/vfx/jump_particles.tscn")
@onready var land_particles = preload("res://player/vfx/land_particles.tscn")
#endregion


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


func _physics_process(_delta : float):
	modify_physics_properties()
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
	and follow_cam_pos_when_aimed and not godot_plush_skin.ragdoll ):
		#get cam rotation on the y axis (+ PI to invert half circle, and be sure that the model is correctly oriented)
		dir_target_angle = (cam_holder.cam.global_rotation.y) + PI
		#rotate the model on the y axis
		visual_root.rotation.y = rotate_toward(visual_root.rotation.y, dir_target_angle, model_rot_speed * delta)
	
	#free mode (the model orientation is independant to the camera one)
	if (cam_holder.camera_mode in [cam_holder.Camera.THIRD, cam_holder.Camera.FIRST] or not follow_cam_pos_when_aimed) and move_dir != Vector2.ZERO:
		#get char move direction
		dir_target_angle = -move_dir.orthogonal().angle()
		#rotate the model on the y axis
		visual_root.rotation.y = rotate_toward(visual_root.rotation.y, dir_target_angle, model_rot_speed * delta)


func modify_physics_properties():
	last_frame_position = position #get play char position every frame
	last_frame_velocity = velocity #get play char velocity every frame
	was_on_floor = not is_on_floor() #get if play char is on floor or not


func apply_gravity(delta : float):
	if velocity.y >= 0.0:
		velocity.y -= jump_gravity * delta
	elif velocity.y < 0.0 and velocity.y > -1.0:
		velocity.y -= (fall_gravity / 6) * delta
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
		print("crouched")
	elif pose == Pose.CROUCHED:
		pose = Pose.STANDING
		move_speed = state_speed
		print("standing")
