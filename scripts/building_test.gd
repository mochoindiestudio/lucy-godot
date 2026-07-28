extends Node3D

## Drives the item-focus camera and cross-lighting for the building scale
## test ground. Left/right arrows step through _items, ordered by each
## item's actual X position rather than scene child order, so the lineup
## still steps left-to-right correctly even after an item is repositioned
## in the editor. Camera framing is derived from each item's own world-space
## visual bounds, so it moves closer for small props and further back for
## large buildings instead of using one fixed distance for everything.

## How much of the frame height/width an item's bounds should occupy; > 1.0
## backs the camera off further to leave breathing room around the item.
const CAMERA_FIT_MARGIN := 1.2
## Camera never gets closer than this, even to a tiny prop, to avoid
## clipping into it.
const CAMERA_MIN_DISTANCE := 1.5
## Fraction up the item's own height (from its base) that the camera aims
## at, so the shot centers on the item rather than its feet.
const LOOK_AT_HEIGHT_FRACTION := 0.5

const TRANSITION_TIME := 0.8
const LIGHT_FADE_TIME := TRANSITION_TIME / 2.0
const LIGHT_ENERGY := 4.0

## The rig below (offsets and range) is tuned for an item this tall; each
## focused item scales the whole rig by its own height / REFERENCE_HEIGHT,
## so lighting closes in on small props and spreads out over big buildings
## instead of using one fixed geometry for everything.
const REFERENCE_HEIGHT := 1.0
const LIGHT_HEIGHT := 3.2
const LIGHT_FORWARD_OFFSET := -1.0
const LIGHT_SIDE_OFFSET := 1.4
const LIGHT_CROSS_OFFSET := 0.6
const LIGHT_TARGET_HEIGHT := 0.3
const LIGHT_TARGET_FORWARD := 0.4
const SPOT_RANGE_BASE := 6.0

## Subtle hand-held sway applied on top of the framed camera shot.
@export_group("Handheld Camera Shake")
@export var shake_enabled := true
@export_range(0.0, 0.05, 0.001, "suffix:m") var shake_position_amount := 0.008
@export_range(0.0, 3.0, 0.01, "suffix:deg") var shake_rotation_amount := 0.25
@export_range(0.0, 3.0, 0.01) var shake_speed := 0.6

@onready var _camera: Camera3D = $Camera3D
@onready var _light_warm: SpotLight3D = $SpotLightWarm
@onready var _light_cool: SpotLight3D = $SpotLightCool
@onready var _ui: Control = $UI/BuildingShowcaseUI

## Every showcased item is tagged with the "showcase_item" group (see
## building_test.tscn); sorting by X here means the lineup always steps
## left-to-right in whatever order the items actually sit in the scene.
@onready var _items: Array[Node3D] = _sorted_by_x(get_tree().get_nodes_in_group("showcase_item"))

var _focus_index := 0
var _is_transitioning := false

## The clean, tween-driven camera shot, before shake is layered on top.
var _camera_base_transform := Transform3D()
var _shake_time := 0.0
## One noise per axis, each with a distinct seed, so the axes wander independently.
var _position_noise: Array[FastNoiseLite] = []
var _rotation_noise: Array[FastNoiseLite] = []

func _ready() -> void:
	_position_noise = [_make_shake_noise(1), _make_shake_noise(2), _make_shake_noise(3)]
	_rotation_noise = [_make_shake_noise(4), _make_shake_noise(5), _make_shake_noise(6)]

	var focused := _items[_focus_index]
	_camera_base_transform = _camera_transform_for(focused)
	_camera.global_transform = _camera_base_transform
	_position_lights(focused)
	_light_warm.light_energy = LIGHT_ENERGY
	_light_cool.light_energy = LIGHT_ENERGY
	_ui.show_item(focused)

func _process(delta: float) -> void:
	if not shake_enabled:
		_camera.transform = _camera_base_transform
		return
	_shake_time += delta
	_camera.transform = _camera_base_transform * _handheld_offset()

func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return
	if event.is_action_pressed("ui_left"):
		_move_focus(1)
	elif event.is_action_pressed("ui_right"):
		_move_focus(-1)

## Left steps deeper into the lineup, right steps back; both stop at the ends.
func _move_focus(step: int) -> void:
	var target_index := _focus_index + step
	if target_index < 0 or target_index >= _items.size():
		return
	_focus_index = target_index
	_transition_to(_items[_focus_index])

func _transition_to(item: Node3D) -> void:
	_is_transitioning = true
	_ui.fade_name(0.0, LIGHT_FADE_TIME)

	var camera_tween := create_tween()
	camera_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_property(self, "_camera_base_transform", _camera_transform_for(item), TRANSITION_TIME)

	var light_tween := create_tween()
	light_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	light_tween.tween_property(_light_warm, "light_energy", 0.0, LIGHT_FADE_TIME)
	light_tween.parallel().tween_property(_light_cool, "light_energy", 0.0, LIGHT_FADE_TIME)
	light_tween.tween_callback(_position_lights.bind(item))
	light_tween.tween_property(_light_warm, "light_energy", LIGHT_ENERGY, LIGHT_FADE_TIME)
	light_tween.parallel().tween_property(_light_cool, "light_energy", LIGHT_ENERGY, LIGHT_FADE_TIME)

	await light_tween.finished
	_is_transitioning = false
	_ui.show_item(item)
	_ui.fade_name(1.0, LIGHT_FADE_TIME)

func _sorted_by_x(nodes: Array) -> Array[Node3D]:
	var items: Array[Node3D] = []
	for node in nodes:
		items.append(node as Node3D)
	items.sort_custom(func(a: Node3D, b: Node3D): return a.global_position.x < b.global_position.x)
	return items

## Frames the camera so the item's own world-space bounds fill roughly
## 1 / CAMERA_FIT_MARGIN of the view, whatever the item's actual size.
func _camera_transform_for(item: Node3D) -> Transform3D:
	var bounds := _world_bounds(item)
	var item_x := bounds.position.x + bounds.size.x * 0.5
	var center_z := bounds.position.z + bounds.size.z * 0.5

	var v_fov := deg_to_rad(_camera.fov)
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / viewport_size.y

	var distance_for_height := (bounds.size.y * 0.5) / tan(v_fov * 0.5)
	var distance_for_width := (bounds.size.x * 0.5) / (tan(v_fov * 0.5) * aspect)
	var clearance := maxf(maxf(distance_for_height, distance_for_width) * CAMERA_FIT_MARGIN, CAMERA_MIN_DISTANCE)

	## clearance is measured from the item's near face (the side closest to
	## the camera, which sits at -Z), not its center, so deep items like a
	## house don't end up with the camera clipping into their front wall.
	var near_z := bounds.position.z
	var eye_z := near_z - clearance

	var look_at_height := bounds.position.y + bounds.size.y * LOOK_AT_HEIGHT_FRACTION
	var eye := Vector3(item_x, look_at_height, eye_z)
	var look_at := Vector3(item_x, look_at_height, center_z)
	return Transform3D(Basis(), eye).looking_at(look_at, Vector3.UP)

## The item's full visual bounds in world space, gathered from every
## VisualInstance3D under it (an item may be several meshes deep, e.g. the
## windmill's tower + rotor).
func _world_bounds(item: Node3D) -> AABB:
	var extent := [Vector3(INF, INF, INF), Vector3(-INF, -INF, -INF)]
	_accumulate_world_bounds(item, extent)
	return AABB(extent[0], extent[1] - extent[0])

func _accumulate_world_bounds(node: Node, extent: Array) -> void:
	## GeometryInstance3D (meshes) only; Light3D is also a VisualInstance3D
	## but its "aabb" is its light range, not surface geometry, and would
	## blow the fit out to fit a lamp's light radius instead of its body.
	## A skinned mesh's own AABB is its bind-pose bounds in the mesh's local
	## space and stays tiny regardless of the actual rig scale (skinning
	## happens through the skeleton's bone poses, not the mesh node's
	## transform), so it's skipped in favor of the Skeleton3D case below.
	var is_skinned_mesh := node is MeshInstance3D and not (node as MeshInstance3D).skeleton.is_empty()
	if node is GeometryInstance3D and not is_skinned_mesh:
		var world_aabb: AABB = node.global_transform * node.get_aabb()
		extent[0] = extent[0].min(world_aabb.position)
		extent[1] = extent[1].max(world_aabb.position + world_aabb.size)
	## Bone joint positions stand in for the mesh bounds of whatever is
	## skinned to this skeleton, since the true skinned AABB isn't otherwise
	## available without evaluating the skin deformation itself.
	if node is Skeleton3D:
		var skeleton: Skeleton3D = node
		for i in skeleton.get_bone_count():
			var joint := skeleton.global_transform * skeleton.get_bone_global_pose(i).origin
			extent[0] = extent[0].min(joint)
			extent[1] = extent[1].max(joint)
	for child in node.get_children():
		_accumulate_world_bounds(child, extent)

## Two spots above opposite shoulders, each aimed past the item's centerline
## toward the other side, so their beams cross over the item. Every offset
## and the spot range scale with the item's own height, and the forward
## offsets anchor off its near face/center in Z rather than a flat 0, so a
## deep item like a house still gets lit from clear of its front wall.
func _position_lights(item: Node3D) -> void:
	var bounds := _world_bounds(item)
	var scale := bounds.size.y / REFERENCE_HEIGHT
	var item_x := bounds.position.x + bounds.size.x * 0.5
	var near_z := bounds.position.z
	var center_z := bounds.position.z + bounds.size.z * 0.5
	var base_y := bounds.position.y

	var eye_y := base_y + LIGHT_HEIGHT * scale
	var eye_z := near_z + LIGHT_FORWARD_OFFSET * scale
	var target_y := base_y + LIGHT_TARGET_HEIGHT * scale
	var target_z := center_z + LIGHT_TARGET_FORWARD * scale
	var side_offset := LIGHT_SIDE_OFFSET * scale
	var cross_offset := LIGHT_CROSS_OFFSET * scale

	_light_warm.global_transform = _spot_transform(
		Vector3(item_x - side_offset, eye_y, eye_z), Vector3(item_x + cross_offset, target_y, target_z)
	)
	_light_cool.global_transform = _spot_transform(
		Vector3(item_x + side_offset, eye_y, eye_z), Vector3(item_x - cross_offset, target_y, target_z)
	)

	var spot_range := SPOT_RANGE_BASE * scale
	_light_warm.spot_range = spot_range
	_light_cool.spot_range = spot_range

func _spot_transform(eye: Vector3, look_at: Vector3) -> Transform3D:
	return Transform3D(Basis(), eye).looking_at(look_at, Vector3.UP)

func _make_shake_noise(seed_value: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.0
	return noise

## A small local-space offset (position sway + rotation wobble) sampled from
## smooth noise, composed on top of _camera_base_transform each frame.
func _handheld_offset() -> Transform3D:
	var t := _shake_time * shake_speed
	var position_offset := Vector3(
		_position_noise[0].get_noise_1d(t),
		_position_noise[1].get_noise_1d(t),
		_position_noise[2].get_noise_1d(t)
	) * shake_position_amount
	var rotation_offset := Vector3(
		_rotation_noise[0].get_noise_1d(t),
		_rotation_noise[1].get_noise_1d(t),
		_rotation_noise[2].get_noise_1d(t)
	) * deg_to_rad(shake_rotation_amount)
	return Transform3D(Basis.from_euler(rotation_offset), position_offset)
