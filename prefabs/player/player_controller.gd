extends CharacterBody3D

## Third-person player controller for Lucy: camera-relative movement with
## smooth acceleration, mouse-orbit camera, and a raycast-based ground check.

const IDLE_STATE := "idle"
const WALK_STATE := "walking"
const RUN_STATE := "running"

@export_group("Movement")
@export var walk_speed := 3.0
@export var sprint_speed := 6.0
@export var acceleration := 12.0
@export var deceleration := 16.0
@export var rotation_speed := 10.0

@export_group("Physics")
@export var gravity_multiplier := 1.0
@export var ground_ray_length := 0.6
@export var grounded_snap_velocity := -0.5

@export_group("Camera")
@export var mouse_sensitivity := 0.003
@export var pitch_min_deg := -40.0
@export var pitch_max_deg := 70.0
@export var spring_arm_length := 4.0
@export var spring_arm_margin := 0.2

@export_group("Firefly Light")
@export var shine_cost := 10.0
@export var flicker_enabled := true
@export var flicker_speed := 6.0
@export var flicker_intensity := 0.35

@onready var _ground_ray: RayCast3D = $GroundRayCast
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
## Rotated to face the movement direction. Lucy's own model orientation
## (correcting for her FBX rig's forward axis) is set independently on the
## nested Lucy node and is never touched here.
@onready var _facing: Node3D = $Facing
@onready var _lucy: Node3D = $Facing/Lucy
@onready var _love_light: LoveLight = $Facing/LoveLight
@onready var _energy: EnergyComponent = $Energy

var _current_anim_state := IDLE_STATE

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_spring_arm.spring_length = spring_arm_length
	_spring_arm.margin = spring_arm_margin
	_ground_ray.target_position = Vector3.DOWN * ground_ray_length
	_lucy.play_state(IDLE_STATE)
	_love_light.flicker_enabled = flicker_enabled
	_love_light.flicker_speed = flicker_speed
	_love_light.flicker_intensity = flicker_intensity

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		var pitch: float = _spring_arm.rotation.x - event.relative.y * mouse_sensitivity
		_spring_arm.rotation.x = clamp(
			pitch, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg)
		)
	elif event.is_action_pressed("ui_cancel"):
		_toggle_mouse_capture()
	elif event.is_action_pressed("shine_light"):
		_try_shine()
	elif event is InputEventMouseButton \
			and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Spends energy to light Lucy's firefly glow, if she has enough and it
## isn't already shining.
func _try_shine() -> void:
	if _love_light.is_active():
		return
	if _energy.try_spend(shine_cost):
		_love_light.activate()

func _toggle_mouse_capture() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_dir := _camera_relative_direction(input_dir)
	var is_sprinting := Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO
	var target_speed := sprint_speed if is_sprinting else walk_speed
	var target_velocity := move_dir * target_speed

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if move_dir != Vector3.ZERO else deceleration
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, rate * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if move_dir != Vector3.ZERO:
		var target_yaw := atan2(-move_dir.x, -move_dir.z)
		_facing.rotation.y = lerp_angle(_facing.rotation.y, target_yaw, rotation_speed * delta)

	move_and_slide()
	_update_animation_state(input_dir, is_sprinting)

func _apply_gravity(delta: float) -> void:
	if _ground_ray.is_colliding():
		velocity.y = grounded_snap_velocity
	else:
		var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
		velocity.y -= gravity * gravity_multiplier * delta

func _camera_relative_direction(input_dir: Vector2) -> Vector3:
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO
	var cam_basis := _camera_pivot.global_transform.basis
	return (cam_basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

func _update_animation_state(input_dir: Vector2, is_sprinting: bool) -> void:
	var next_state := IDLE_STATE
	if input_dir != Vector2.ZERO:
		next_state = RUN_STATE if is_sprinting else WALK_STATE
	if next_state != _current_anim_state:
		_current_anim_state = next_state
		_lucy.play_state(next_state)
