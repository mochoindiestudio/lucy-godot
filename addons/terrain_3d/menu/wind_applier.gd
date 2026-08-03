# Copyright © 2023-2026 Cory Petkovsek, Roope Palmroos, and Contributors.
# Wind Applier for Terrain3D. Lets the user drag in tree/grass meshes, tune
# instance_wind.gdshader parameters against a live SubViewport preview, then
# permanently bake the wind material onto each mesh (per-surface, preserving
# existing textures). glTF-imported meshes are baked via a per-surface
# material override on their .import file (matching CommonTree_1.gltf.import);
# plain scene/mesh resources are rewritten in place.
extends Node

const WIND_SHADER: Shader = preload("res://addons/terrain_3d/extras/shaders/instance_wind.gdshader")
const WIND_NOISE_TEX: Texture2D = preload("res://addons/terrain_3d/extras/shaders/T_wind_noise.tres")

const TREE_PRESET: Dictionary = {
	"wind_direction": Vector2(1.0, 1.0),
	"wind_speed": 0.05,
	"wind_noise_scale": 0.1,
	"wind_strength": 0.05,
	"bend_curve": 8.0,
	"alpha_scissor_enabled": true,
	"alpha_scissor_threshold": 0.2,
}
const GRASS_PRESET: Dictionary = {
	"wind_direction": Vector2(1.0, 1.0),
	"wind_speed": 0.085,
	"wind_noise_scale": 0.015,
	"wind_strength": 0.04,
	"bend_curve": 1.0,
	"alpha_scissor_enabled": true,
	"alpha_scissor_threshold": 0.2,
}

var plugin: EditorPlugin
var window: Window

var params_box: VBoxContainer
var vertex_warning_label: Label
var mesh_list: ItemList
var tree_radio: CheckBox
var grass_radio: CheckBox
var status_label: Label
var apply_button: Button
var cancel_button: Button
var bg_toggle_btn: Button
var add_file_dialog: EditorFileDialog
var apply_confirm_dialog: ConfirmationDialog

var preview_viewport: SubViewport
var preview_camera: Camera3D
var preview_environment: Environment
var preview_root: Node3D

var entries: Array[MeshEntry] = []
var _selected_indices: Array[int] = []
var _preview_index: int = -1
var _preview_materials: Array[ShaderMaterial] = []
var _preview_missing_vertex_color: bool = false


func open_popup() -> void:
	if window == null:
		_build_ui()
	_refresh_mesh_list()
	var active_entry: MeshEntry = null
	if _preview_index >= 0 and _preview_index < entries.size():
		active_entry = entries[_preview_index]
	_rebuild_params_panel(active_entry, _preview_index)
	_sync_type_radios(active_entry)
	EditorInterface.popup_dialog_centered_ratio(window, 0.82)


## ---------------------------------------------------------------- UI setup


func _build_ui() -> void:
	window = Window.new()
	window.title = "Terrain3D - Apply Wind to Meshes"
	window.size = Vector2i(1200, 760)
	window.set_unparent_when_invisible(true)
	window.close_requested.connect(func() -> void: window.hide())
	window.window_input.connect(func(p_event: InputEvent) -> void:
		if p_event is InputEventKey and p_event.pressed and p_event.keycode == KEY_ESCAPE:
			window.hide())
	add_child(window)

	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var top_split: HSplitContainer = HSplitContainer.new()
	top_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_split.split_offset = 320
	root.add_child(top_split)

	var left_scroll: ScrollContainer = ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(320, 0)
	top_split.add_child(left_scroll)
	params_box = VBoxContainer.new()
	params_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	params_box.add_theme_constant_override("separation", 4)
	left_scroll.add_child(params_box)

	var right_panel: VBoxContainer = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_split.add_child(right_panel)

	var preview_toolbar: HBoxContainer = HBoxContainer.new()
	right_panel.add_child(preview_toolbar)
	var preview_label: Label = Label.new()
	preview_label.text = "Live Preview"
	preview_toolbar.add_child(preview_label)
	var preview_spacer: Control = Control.new()
	preview_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_toolbar.add_child(preview_spacer)
	bg_toggle_btn = Button.new()
	bg_toggle_btn.toggle_mode = true
	bg_toggle_btn.button_pressed = true
	bg_toggle_btn.toggled.connect(_on_bg_toggle_toggled)
	preview_toolbar.add_child(bg_toggle_btn)

	var preview_container: SubViewportContainer = SubViewportContainer.new()
	preview_container.stretch = true
	preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(preview_container)

	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(800, 600)
	preview_viewport.own_world_3d = true
	preview_viewport.transparent_bg = false
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_container.add_child(preview_viewport)

	preview_environment = Environment.new()
	preview_environment.background_mode = Environment.BG_COLOR
	preview_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	preview_environment.ambient_light_color = Color(1.0, 1.0, 1.0)
	preview_environment.ambient_light_energy = 0.6

	preview_camera = Camera3D.new()
	preview_camera.current = true
	preview_camera.environment = preview_environment
	preview_camera.position = Vector3(2.0, 2.0, 2.0)
	preview_camera.look_at(Vector3.ZERO, Vector3.UP)
	preview_viewport.add_child(preview_camera)

	var preview_light: DirectionalLight3D = DirectionalLight3D.new()
	preview_light.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	preview_light.light_energy = 1.1
	preview_viewport.add_child(preview_light)

	preview_root = Node3D.new()
	preview_viewport.add_child(preview_root)

	_on_bg_toggle_toggled(bg_toggle_btn.button_pressed)

	root.add_child(HSeparator.new())

	var mesh_section: VBoxContainer = VBoxContainer.new()
	mesh_section.custom_minimum_size = Vector2(0, 220)
	root.add_child(mesh_section)

	var mesh_toolbar: HBoxContainer = HBoxContainer.new()
	mesh_section.add_child(mesh_toolbar)
	var mesh_label: Label = Label.new()
	mesh_label.text = "Meshes (drag & drop .glb/.gltf/.tscn/.res/.tres, or use Add Files)"
	mesh_toolbar.add_child(mesh_label)
	var mesh_spacer: Control = Control.new()
	mesh_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mesh_toolbar.add_child(mesh_spacer)
	var add_files_btn: Button = Button.new()
	add_files_btn.text = "Add Files..."
	add_files_btn.pressed.connect(func() -> void: add_file_dialog.popup_centered_ratio(0.6))
	mesh_toolbar.add_child(add_files_btn)
	var remove_btn: Button = Button.new()
	remove_btn.text = "Remove Selected"
	remove_btn.pressed.connect(_on_remove_selected_pressed)
	mesh_toolbar.add_child(remove_btn)
	var type_label: Label = Label.new()
	type_label.text = "  Set Type:"
	mesh_toolbar.add_child(type_label)
	var type_group: ButtonGroup = ButtonGroup.new()
	tree_radio = CheckBox.new()
	tree_radio.text = "Tree"
	tree_radio.button_group = type_group
	tree_radio.pressed.connect(_on_type_radio_pressed.bind("tree"))
	mesh_toolbar.add_child(tree_radio)
	grass_radio = CheckBox.new()
	grass_radio.text = "Grass"
	grass_radio.button_group = type_group
	grass_radio.pressed.connect(_on_type_radio_pressed.bind("grass"))
	mesh_toolbar.add_child(grass_radio)

	mesh_list = MeshDropList.new()
	mesh_list.custom_minimum_size = Vector2(0, 160)
	mesh_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mesh_list.select_mode = ItemList.SELECT_MULTI
	mesh_list.files_dropped.connect(_on_files_dropped)
	mesh_list.multi_selected.connect(func(_p_index: int, _p_selected: bool) -> void: _on_mesh_selection_changed())
	mesh_list.item_selected.connect(func(_p_index: int) -> void: _on_mesh_selection_changed())
	mesh_list.empty_clicked.connect(func(_p_pos: Vector2, _p_button: int) -> void: _on_mesh_selection_changed())
	mesh_section.add_child(mesh_list)

	add_file_dialog = EditorFileDialog.new()
	add_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
	add_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	add_file_dialog.set_filters(PackedStringArray([
		"*.glb, *.gltf, *.tscn, *.res, *.tres ; Meshes and Scenes",
	]))
	add_file_dialog.files_selected.connect(_on_files_dropped)
	window.add_child(add_file_dialog)

	root.add_child(HSeparator.new())

	var bottom: HBoxContainer = HBoxContainer.new()
	root.add_child(bottom)
	status_label = Label.new()
	bottom.add_child(status_label)
	var bottom_spacer: Control = Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(bottom_spacer)
	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(func() -> void: window.hide())
	bottom.add_child(cancel_button)
	apply_button = Button.new()
	apply_button.text = "Apply"
	apply_button.pressed.connect(_on_apply_pressed)
	bottom.add_child(apply_button)

	apply_confirm_dialog = ConfirmationDialog.new()
	apply_confirm_dialog.title = "Apply Wind Shader"
	apply_confirm_dialog.get_ok_button().text = "Back Up && Apply"
	apply_confirm_dialog.add_button("Apply Without Backup", true, "no_backup")
	apply_confirm_dialog.confirmed.connect(func() -> void: _run_apply(true))
	apply_confirm_dialog.custom_action.connect(func(p_action: StringName) -> void:
		if p_action == "no_backup":
			apply_confirm_dialog.hide()
			_run_apply(false))
	window.add_child(apply_confirm_dialog)

	_rebuild_params_panel(null, -1)


func _row(p_parent: Control, p_label: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = p_label
	label.custom_minimum_size = Vector2(190, 0)
	row.add_child(label)
	p_parent.add_child(row)
	return row


func _spin(p_min: float, p_max: float, p_step: float, p_value: float) -> SpinBox:
	var sb: SpinBox = SpinBox.new()
	sb.min_value = p_min
	sb.max_value = p_max
	sb.step = p_step
	sb.value = p_value
	sb.allow_greater = true
	sb.allow_lesser = true
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sb


## ---------------------------------------------------------------- Params panel


func _rebuild_params_panel(p_entry: MeshEntry, p_index: int) -> void:
	for c: Node in params_box.get_children():
		params_box.remove_child(c)
		c.queue_free()

	if p_entry == null:
		var hint: Label = Label.new()
		hint.text = "Add meshes below, select one, then tune its wind settings here."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD
		params_box.add_child(hint)
		return

	var name_label: Label = Label.new()
	name_label.text = "%s (%s)" % [p_entry.display_name, p_entry.type.capitalize()]
	name_label.add_theme_font_size_override("font_size", 16)
	params_box.add_child(name_label)

	vertex_warning_label = Label.new()
	vertex_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vertex_warning_label.modulate = Color(1.0, 0.75, 0.3)
	vertex_warning_label.text = "This mesh has no baked wind-weight vertex colors. A height-based approximation is used for preview/bake instead of authored root-to-tip data. glTF-imported meshes can't have this baked back into their geometry -- vertex-paint it in your 3D tool for correct results."
	vertex_warning_label.visible = _preview_missing_vertex_color
	params_box.add_child(vertex_warning_label)

	params_box.add_child(HSeparator.new())

	var dir_row: HBoxContainer = _row(params_box, "Wind Direction (X, Z)")
	var dir_x: SpinBox = _spin(-1.0, 1.0, 0.05, p_entry.params.wind_direction.x)
	var dir_z: SpinBox = _spin(-1.0, 1.0, 0.05, p_entry.params.wind_direction.y)
	dir_x.value_changed.connect(func(v: float) -> void:
		p_entry.params.wind_direction = Vector2(v, p_entry.params.wind_direction.y)
		_apply_live_param(p_index, "wind_direction", p_entry.params.wind_direction))
	dir_z.value_changed.connect(func(v: float) -> void:
		p_entry.params.wind_direction = Vector2(p_entry.params.wind_direction.x, v)
		_apply_live_param(p_index, "wind_direction", p_entry.params.wind_direction))
	dir_row.add_child(dir_x)
	dir_row.add_child(dir_z)

	var speed_row: HBoxContainer = _row(params_box, "Wind Speed")
	var speed_spin: SpinBox = _spin(0.0, 5.0, 0.005, p_entry.params.wind_speed)
	speed_spin.value_changed.connect(func(v: float) -> void:
		p_entry.params.wind_speed = v
		_apply_live_param(p_index, "wind_speed", v))
	speed_row.add_child(speed_spin)

	var noise_scale_row: HBoxContainer = _row(params_box, "Wind Noise Scale")
	var noise_scale_spin: SpinBox = _spin(0.0001, 2.0, 0.001, p_entry.params.wind_noise_scale)
	noise_scale_spin.value_changed.connect(func(v: float) -> void:
		p_entry.params.wind_noise_scale = v
		_apply_live_param(p_index, "wind_noise_scale", v))
	noise_scale_row.add_child(noise_scale_spin)

	var strength_row: HBoxContainer = _row(params_box, "Wind Strength")
	var strength_spin: SpinBox = _spin(0.0, 5.0, 0.005, p_entry.params.wind_strength)
	strength_spin.value_changed.connect(func(v: float) -> void:
		p_entry.params.wind_strength = v
		_apply_live_param(p_index, "wind_strength", v))
	strength_row.add_child(strength_spin)

	var bend_row: HBoxContainer = _row(params_box, "Bend Curve")
	var bend_spin: SpinBox = _spin(0.5, 8.0, 0.1, p_entry.params.bend_curve)
	bend_spin.value_changed.connect(func(v: float) -> void:
		p_entry.params.bend_curve = v
		_apply_live_param(p_index, "bend_curve", v))
	bend_row.add_child(bend_spin)

	params_box.add_child(HSeparator.new())

	var scissor_row: HBoxContainer = _row(params_box, "Alpha Scissor")
	var scissor_check: CheckBox = CheckBox.new()
	scissor_check.button_pressed = p_entry.params.alpha_scissor_enabled
	scissor_check.toggled.connect(func(v: bool) -> void:
		p_entry.params.alpha_scissor_enabled = v
		_apply_live_param(p_index, "alpha_scissor_enabled", v))
	scissor_row.add_child(scissor_check)

	var threshold_row: HBoxContainer = _row(params_box, "Alpha Scissor Threshold")
	var threshold_spin: SpinBox = _spin(0.0, 1.0, 0.01, p_entry.params.alpha_scissor_threshold)
	threshold_spin.value_changed.connect(func(v: float) -> void:
		p_entry.params.alpha_scissor_threshold = v
		_apply_live_param(p_index, "alpha_scissor_threshold", v))
	threshold_row.add_child(threshold_spin)

	params_box.add_child(HSeparator.new())

	var reset_btn: Button = Button.new()
	reset_btn.text = "Reset to %s Defaults" % p_entry.type.capitalize()
	reset_btn.pressed.connect(func() -> void:
		var preset: Dictionary = TREE_PRESET if p_entry.type == "tree" else GRASS_PRESET
		p_entry.params = preset.duplicate(true)
		_rebuild_params_panel(p_entry, p_index)
		_update_preview(p_index))
	params_box.add_child(reset_btn)


func _apply_live_param(p_index: int, p_key: String, p_value: Variant) -> void:
	if p_index != _preview_index:
		return
	for mat: ShaderMaterial in _preview_materials:
		mat.set_shader_parameter(p_key, p_value)


func _on_bg_toggle_toggled(p_pressed: bool) -> void:
	bg_toggle_btn.text = "Dark Background" if p_pressed else "Light Background"
	preview_environment.background_color = Color(0.1607843, 0.1607843, 0.1607843) if p_pressed \
			else Color(0.9215686, 0.9215686, 0.9215686)


## ---------------------------------------------------------------- Mesh list


func _on_files_dropped(p_files: PackedStringArray) -> void:
	for file: String in p_files:
		var already_added: bool = false
		for entry: MeshEntry in entries:
			if entry.path == file:
				already_added = true
				break
		if already_added:
			continue
		var entry: MeshEntry = MeshEntry.new()
		entry.path = file
		entry.display_name = file.get_file().get_basename()
		entry.type = "tree"
		entry.params = TREE_PRESET.duplicate(true)
		entries.append(entry)
	_refresh_mesh_list()


func _refresh_mesh_list() -> void:
	mesh_list.clear()
	for entry: MeshEntry in entries:
		mesh_list.add_item("%s  [%s]" % [entry.display_name, entry.type.capitalize()])
	for idx: int in _selected_indices:
		if idx >= 0 and idx < entries.size():
			mesh_list.select(idx, false)


func _on_mesh_selection_changed() -> void:
	var selected: PackedInt32Array = mesh_list.get_selected_items()
	_selected_indices.clear()
	for idx: int in selected:
		_selected_indices.append(idx)
	if _selected_indices.is_empty():
		_preview_index = -1
	elif not _selected_indices.has(_preview_index):
		_preview_index = _selected_indices[-1]
	var active_entry: MeshEntry = null
	if _preview_index >= 0 and _preview_index < entries.size():
		active_entry = entries[_preview_index]
	_rebuild_params_panel(active_entry, _preview_index)
	_update_preview(_preview_index)
	_sync_type_radios(active_entry)


func _sync_type_radios(p_entry: MeshEntry) -> void:
	tree_radio.set_pressed_no_signal(p_entry != null and p_entry.type == "tree")
	grass_radio.set_pressed_no_signal(p_entry != null and p_entry.type == "grass")


func _on_type_radio_pressed(p_type: String) -> void:
	if _selected_indices.is_empty():
		return
	var preset: Dictionary = TREE_PRESET if p_type == "tree" else GRASS_PRESET
	for idx: int in _selected_indices:
		if idx < 0 or idx >= entries.size():
			continue
		var entry: MeshEntry = entries[idx]
		entry.type = p_type
		entry.params = preset.duplicate(true)
	_refresh_mesh_list()
	if _preview_index in _selected_indices:
		_rebuild_params_panel(entries[_preview_index], _preview_index)
		_update_preview(_preview_index)


func _on_remove_selected_pressed() -> void:
	var indices: Array = _selected_indices.duplicate()
	indices.sort()
	indices.reverse()
	for idx: int in indices:
		if idx >= 0 and idx < entries.size():
			entries.remove_at(idx)
	_selected_indices.clear()
	_preview_index = -1
	_update_preview(-1)
	_rebuild_params_panel(null, -1)
	_sync_type_radios(null)
	_refresh_mesh_list()


## ---------------------------------------------------------------- Live preview


func _update_preview(p_index: int) -> void:
	for c: Node in preview_root.get_children():
		preview_root.remove_child(c)
		c.queue_free()
	_preview_materials.clear()
	_preview_missing_vertex_color = false
	if p_index < 0 or p_index >= entries.size():
		return

	var entry: MeshEntry = entries[p_index]
	var res: Resource = load(entry.path)
	var node: Node3D = null
	if res is PackedScene:
		var inst: Node = (res as PackedScene).instantiate()
		if inst is Node3D:
			node = inst
		else:
			node = Node3D.new()
			node.add_child(inst)
	elif res is Mesh:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = res
		node = mi
	else:
		status_label.text = "Cannot preview %s" % entry.path
		return

	preview_root.add_child(node)
	_preview_materials = _apply_preview_materials(node, entry)
	if vertex_warning_label:
		vertex_warning_label.visible = _preview_missing_vertex_color
	_frame_camera(node)


func _apply_preview_materials(p_root: Node3D, p_entry: MeshEntry) -> Array[ShaderMaterial]:
	var created: Array[ShaderMaterial] = []
	for mi: MeshInstance3D in _find_mesh_instances(p_root):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		if mesh is ArrayMesh and not _mesh_has_vertex_color(mesh):
			_preview_missing_vertex_color = true
			mesh = _ensure_wind_weight(mesh)
			mi.mesh = mesh
		for i: int in mesh.get_surface_count():
			var src_mat: Material = mi.get_active_material(i)
			var tex: Dictionary = _extract_textures(src_mat)
			var wind_mat: ShaderMaterial = _build_wind_material(p_entry.params, tex.albedo, tex.normal)
			mi.set_surface_override_material(i, wind_mat)
			created.append(wind_mat)
	return created


func _frame_camera(p_node: Node3D) -> void:
	var mesh_instances: Array[MeshInstance3D] = _find_mesh_instances(p_node)
	if mesh_instances.is_empty():
		return
	var aabb: AABB = AABB()
	var first: bool = true
	for mi: MeshInstance3D in mesh_instances:
		var world_aabb: AABB = mi.global_transform * mi.get_aabb()
		if first:
			aabb = world_aabb
			first = false
		else:
			aabb = aabb.merge(world_aabb)
	var center: Vector3 = aabb.get_center()
	var radius: float = maxf(aabb.get_longest_axis_size() * 0.5, 0.25)
	var dir: Vector3 = Vector3(1.0, 0.6, 1.0).normalized()
	preview_camera.global_position = center + dir * radius * 2.5
	preview_camera.look_at(center, Vector3.UP)
	preview_camera.near = 0.02
	preview_camera.far = radius * 30.0 + 20.0


func _find_mesh_instances(p_node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if p_node is MeshInstance3D:
		result.append(p_node)
	for child: Node in p_node.get_children():
		result.append_array(_find_mesh_instances(child))
	return result


func _mesh_has_vertex_color(p_mesh: Mesh) -> bool:
	if not (p_mesh is ArrayMesh):
		return true
	var array_mesh: ArrayMesh = p_mesh
	for i: int in array_mesh.get_surface_count():
		var arrays: Array = array_mesh.surface_get_arrays(i)
		if arrays[Mesh.ARRAY_COLOR] == null:
			return false
	return true


func _ensure_wind_weight(p_mesh: ArrayMesh) -> ArrayMesh:
	if _mesh_has_vertex_color(p_mesh):
		return p_mesh
	var aabb: AABB = p_mesh.get_aabb()
	var min_y: float = aabb.position.y
	var height: float = maxf(aabb.size.y, 0.0001)
	var new_mesh: ArrayMesh = ArrayMesh.new()
	for i: int in p_mesh.get_surface_count():
		var arrays: Array = p_mesh.surface_get_arrays(i)
		if arrays[Mesh.ARRAY_COLOR] == null:
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = PackedColorArray()
			colors.resize(verts.size())
			for v: int in verts.size():
				var w: float = clampf((verts[v].y - min_y) / height, 0.0, 1.0)
				colors[v] = Color(w, w, w, 1.0)
			arrays[Mesh.ARRAY_COLOR] = colors
		var surface_index: int = new_mesh.get_surface_count()
		new_mesh.add_surface_from_arrays(p_mesh.surface_get_primitive_type(i), arrays)
		new_mesh.surface_set_material(surface_index, p_mesh.surface_get_material(i))
		var surface_name: String = p_mesh.surface_get_name(i)
		if surface_name != "":
			new_mesh.surface_set_name(surface_index, surface_name)
	return new_mesh


func _extract_textures(p_material: Material) -> Dictionary:
	var albedo: Texture2D = null
	var normal: Texture2D = null
	if p_material is BaseMaterial3D:
		var base_mat: BaseMaterial3D = p_material
		albedo = base_mat.albedo_texture
		if base_mat.normal_enabled:
			normal = base_mat.normal_texture
	return {"albedo": albedo, "normal": normal}


func _build_wind_material(p_params: Dictionary, p_albedo: Texture2D, p_normal: Texture2D) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = WIND_SHADER
	mat.set_shader_parameter("albedo", Color(1.0, 1.0, 1.0, 1.0))
	mat.set_shader_parameter("albedo_texture", p_albedo)
	mat.set_shader_parameter("roughness", 1.0)
	mat.set_shader_parameter("alpha_scissor_enabled", p_params.alpha_scissor_enabled)
	mat.set_shader_parameter("alpha_scissor_threshold", p_params.alpha_scissor_threshold)
	mat.set_shader_parameter("normal_enabled", p_normal != null)
	mat.set_shader_parameter("normal_texture", p_normal)
	mat.set_shader_parameter("wind_noise", WIND_NOISE_TEX)
	mat.set_shader_parameter("wind_direction", p_params.wind_direction)
	mat.set_shader_parameter("wind_speed", p_params.wind_speed)
	mat.set_shader_parameter("wind_noise_scale", p_params.wind_noise_scale)
	mat.set_shader_parameter("wind_strength", p_params.wind_strength)
	mat.set_shader_parameter("bend_curve", p_params.bend_curve)
	return mat


## ---------------------------------------------------------------- Apply / bake


func _on_apply_pressed() -> void:
	if entries.is_empty():
		return
	apply_confirm_dialog.dialog_text = ("This will permanently rewrite materials (and, where needed, " +
			"vertex data) on %d mesh(es), replacing whatever they currently use.\n\n" +
			"Back up the originals first?") % entries.size()
	apply_confirm_dialog.popup_centered()


func _run_apply(p_do_backup: bool) -> void:
	apply_button.disabled = true
	cancel_button.disabled = true
	var success_count: int = 0
	for entry: MeshEntry in entries:
		status_label.text = "Applying wind to %s..." % entry.display_name
		if _bake_entry(entry, p_do_backup):
			success_count += 1
		await get_tree().process_frame
	EditorInterface.get_resource_filesystem().scan()
	status_label.text = "Applied wind to %d of %d mesh(es)." % [success_count, entries.size()]
	apply_button.disabled = false
	cancel_button.disabled = false


func _bake_entry(p_entry: MeshEntry, p_do_backup: bool) -> bool:
	var ext: String = p_entry.path.get_extension().to_lower()
	if ext == "glb" or ext == "gltf":
		return _bake_gltf_entry(p_entry, p_do_backup)
	return _bake_direct_entry(p_entry, p_do_backup)


func _bake_gltf_entry(p_entry: MeshEntry, p_do_backup: bool) -> bool:
	var import_path: String = p_entry.path + ".import"
	if not FileAccess.file_exists(import_path):
		push_warning("Terrain3D Wind Applier: no .import file found for %s, skipping." % p_entry.path)
		return false
	var res: Resource = load(p_entry.path)
	if not (res is PackedScene):
		push_warning("Terrain3D Wind Applier: %s did not load as a scene, skipping." % p_entry.path)
		return false
	var inst: Node = (res as PackedScene).instantiate()
	var mesh_instances: Array[MeshInstance3D] = _find_mesh_instances(inst)
	if mesh_instances.is_empty():
		inst.queue_free()
		push_warning("Terrain3D Wind Applier: no meshes found in %s, skipping." % p_entry.path)
		return false

	if p_do_backup:
		_backup_file(import_path)

	var cf: ConfigFile = ConfigFile.new()
	if cf.load(import_path) != OK:
		inst.queue_free()
		push_warning("Terrain3D Wind Applier: could not read %s, skipping." % import_path)
		return false
	var subresources: Dictionary = cf.get_value("params", "_subresources", {})
	if not subresources.has("materials"):
		subresources["materials"] = {}
	var materials_dict: Dictionary = subresources["materials"]

	var out_dir: String = p_entry.path.get_base_dir() + "/wind_materials"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var applied_any: bool = false
	var missing_vertex_color: bool = false
	for mi: MeshInstance3D in mesh_instances:
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		if not _mesh_has_vertex_color(mesh):
			missing_vertex_color = true
		for i: int in mesh.get_surface_count():
			var src_mat: Material = mi.get_active_material(i)
			var mat_name: String = _sanitize(src_mat.resource_name) if src_mat and src_mat.resource_name != "" \
					else "Surface_%d" % i
			var tex: Dictionary = _extract_textures(src_mat)
			var wind_mat: ShaderMaterial = _build_wind_material(p_entry.params, tex.albedo, tex.normal)
			var save_path: String = "%s/%s_%s_wind.tres" % [out_dir, _sanitize(p_entry.display_name), mat_name]
			if ResourceSaver.save(wind_mat, save_path) != OK:
				push_warning("Terrain3D Wind Applier: failed to save %s" % save_path)
				continue
			var use_path: String = save_path
			var uid: int = ResourceLoader.get_resource_uid(save_path)
			if uid != ResourceUID.INVALID_ID:
				use_path = ResourceUID.id_to_text(uid)
			materials_dict[mat_name] = {
				"use_external/enabled": true,
				"use_external/path": use_path,
				"use_external/fallback_path": save_path,
			}
			applied_any = true

	inst.queue_free()
	if not applied_any:
		return false

	subresources["materials"] = materials_dict
	cf.set_value("params", "_subresources", subresources)
	if cf.save(import_path) != OK:
		push_warning("Terrain3D Wind Applier: failed to write %s" % import_path)
		return false

	EditorInterface.get_resource_filesystem().reimport_files([p_entry.path])
	if missing_vertex_color:
		push_warning(("Terrain3D Wind Applier: %s has no baked wind-weight vertex colors; " +
				"the whole mesh will sway uniformly. Vertex-paint root (black) to tip (white) " +
				"in your 3D tool for correct results.") % p_entry.path)
	return true


func _bake_direct_entry(p_entry: MeshEntry, p_do_backup: bool) -> bool:
	var res: Resource = load(p_entry.path)
	if res == null:
		push_warning("Terrain3D Wind Applier: could not load %s, skipping." % p_entry.path)
		return false
	if p_do_backup:
		_backup_file(p_entry.path)

	if res is PackedScene:
		var inst: Node = (res as PackedScene).instantiate()
		for mi: MeshInstance3D in _find_mesh_instances(inst):
			_bake_mesh_instance(mi, p_entry.params)
		var packed: PackedScene = PackedScene.new()
		packed.pack(inst)
		var err: Error = ResourceSaver.save(packed, p_entry.path)
		inst.queue_free()
		if err != OK:
			push_warning("Terrain3D Wind Applier: failed to save %s" % p_entry.path)
			return false
		return true

	if res is ArrayMesh:
		var new_mesh: ArrayMesh = _ensure_wind_weight(res)
		for i: int in new_mesh.get_surface_count():
			var src_mat: Material = new_mesh.surface_get_material(i)
			var tex: Dictionary = _extract_textures(src_mat)
			var wind_mat: ShaderMaterial = _build_wind_material(p_entry.params, tex.albedo, tex.normal)
			new_mesh.surface_set_material(i, wind_mat)
		var err: Error = ResourceSaver.save(new_mesh, p_entry.path)
		if err != OK:
			push_warning("Terrain3D Wind Applier: failed to save %s" % p_entry.path)
			return false
		return true

	push_warning("Terrain3D Wind Applier: unsupported resource type for %s, skipping." % p_entry.path)
	return false


func _bake_mesh_instance(p_mi: MeshInstance3D, p_params: Dictionary) -> void:
	var mesh: Mesh = p_mi.mesh
	if mesh == null:
		return
	if mesh is ArrayMesh:
		var new_mesh: ArrayMesh = _ensure_wind_weight(mesh)
		p_mi.mesh = new_mesh
		mesh = new_mesh
	for i: int in mesh.get_surface_count():
		var src_mat: Material = p_mi.get_active_material(i)
		var tex: Dictionary = _extract_textures(src_mat)
		var wind_mat: ShaderMaterial = _build_wind_material(p_params, tex.albedo, tex.normal)
		p_mi.set_surface_override_material(i, wind_mat)


func _sanitize(p_name: String) -> String:
	var result: String = p_name
	for ch: String in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", " "]:
		result = result.replace(ch, "_")
	return result


func _backup_file(p_path: String) -> void:
	var backup_path: String = _unique_backup_path(p_path)
	DirAccess.copy_absolute(ProjectSettings.globalize_path(p_path), ProjectSettings.globalize_path(backup_path))


func _unique_backup_path(p_path: String) -> String:
	var base: String = p_path.get_basename()
	var ext: String = p_path.get_extension()
	var candidate: String = "%s_backup.%s" % [base, ext]
	var n: int = 1
	while FileAccess.file_exists(candidate):
		candidate = "%s_backup%d.%s" % [base, n, ext]
		n += 1
	return candidate


## ---------------------------------------------------------------- Inner classes


class MeshEntry:
	var path: String = ""
	var display_name: String = ""
	var type: String = "tree"
	var params: Dictionary = {}


class MeshDropList extends ItemList:
	signal files_dropped(files: PackedStringArray)
	const VALID_EXTENSIONS: PackedStringArray = ["glb", "gltf", "tscn", "res", "tres"]


	func _can_drop_data(_p_at_position: Vector2, p_data: Variant) -> bool:
		if typeof(p_data) == TYPE_DICTIONARY and p_data.has("files"):
			for file: String in p_data.files:
				if VALID_EXTENSIONS.has(file.get_extension().to_lower()):
					return true
		return false


	func _drop_data(_p_at_position: Vector2, p_data: Variant) -> void:
		var files: PackedStringArray = []
		for file: String in p_data.files:
			if VALID_EXTENSIONS.has(file.get_extension().to_lower()):
				files.append(file)
		if not files.is_empty():
			files_dropped.emit(files)
