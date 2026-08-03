# Copyright © 2023-2026 Cory Petkovsek, Roope Palmroos, and Contributors.
# Vegetation Auto-Populator for Terrain3D. Groups mesh assets and scatters them across
# painted regions using per-group noise, then reuses Terrain3DInstancer's brush-style
# randomization (see src/terrain_3d_instancer.cpp add_instances) so results look consistent
# with hand-painted instances.
extends Node

const VegetationGroup: Script = preload("res://addons/terrain_3d/menu/vegetation_group.gd")
const VegetationGroups: Script = preload("res://addons/terrain_3d/menu/vegetation_groups.gd")

var plugin: EditorPlugin
var window: Window
var group_list: ItemList
var inspector: VBoxContainer
var sea_level_label: Label
var manual_sea_level: SpinBox
var status_label: Label
var populate_button: Button
var clear_button: Button

var groups_resource: VegetationGroups
var selected_group_index: int = -1
var _busy: bool = false


func populate_popup() -> void:
	if not plugin.terrain:
		return
	if window == null:
		_build_ui()
	_load_groups()
	_refresh_group_list()
	_update_sea_level_display()
	EditorInterface.popup_dialog_centered_ratio(window, 0.65)


## ---------------------------------------------------------------- UI setup


func _build_ui() -> void:
	window = Window.new()
	window.title = "Terrain3D - Auto-Populate Vegetation"
	window.size = Vector2i(920, 620)
	window.set_unparent_when_invisible(true)
	window.close_requested.connect(func() -> void:
		_save_groups()
		window.hide())
	window.window_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_save_groups()
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

	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 220
	root.add_child(split)

	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(220, 0)
	split.add_child(left)
	group_list = ItemList.new()
	group_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	group_list.item_selected.connect(_on_group_selected)
	left.add_child(group_list)
	var btn_row: HBoxContainer = HBoxContainer.new()
	left.add_child(btn_row)
	var add_btn: Button = Button.new()
	add_btn.text = "Add"
	add_btn.pressed.connect(_on_add_group)
	btn_row.add_child(add_btn)
	var dup_btn: Button = Button.new()
	dup_btn.text = "Duplicate"
	dup_btn.pressed.connect(_on_duplicate_group)
	btn_row.add_child(dup_btn)
	var remove_btn: Button = Button.new()
	remove_btn.text = "Remove"
	remove_btn.pressed.connect(_on_remove_group)
	btn_row.add_child(remove_btn)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)
	inspector = VBoxContainer.new()
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.add_theme_constant_override("separation", 4)
	scroll.add_child(inspector)

	root.add_child(HSeparator.new())

	var bottom: HBoxContainer = HBoxContainer.new()
	root.add_child(bottom)
	sea_level_label = Label.new()
	bottom.add_child(sea_level_label)
	manual_sea_level = SpinBox.new()
	manual_sea_level.min_value = -1000.0
	manual_sea_level.max_value = 1000.0
	manual_sea_level.step = 0.1
	manual_sea_level.visible = false
	bottom.add_child(manual_sea_level)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	status_label = Label.new()
	bottom.add_child(status_label)
	populate_button = Button.new()
	populate_button.text = "Auto-Populate"
	populate_button.pressed.connect(_on_populate_pressed)
	bottom.add_child(populate_button)
	clear_button = Button.new()
	clear_button.text = "Clear Vegetation"
	clear_button.pressed.connect(_on_clear_pressed)
	bottom.add_child(clear_button)


func _row(p_parent: Control, p_label: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = p_label
	label.custom_minimum_size = Vector2(150, 0)
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


func _rebuild_mesh_scale_overrides(p_container: VBoxContainer, p_group: VegetationGroup,
		p_assets: Terrain3DAssets) -> void:
	for c: Node in p_container.get_children():
		p_container.remove_child(c)
		c.queue_free()
	for mesh_id: int in p_group.mesh_ids:
		var asset: Terrain3DMeshAsset = p_assets.get_mesh_asset(mesh_id)
		var label_text: String = "Mesh %d" % mesh_id
		if asset and not asset.name.is_empty():
			label_text = asset.name
		var row: HBoxContainer = _row(p_container, label_text)
		var scale_spin: SpinBox = _spin(1.0, 1000.0, 1.0,
				p_group.mesh_scale_overrides.get(mesh_id, 100.0))
		scale_spin.value_changed.connect(func(v: float) -> void:
			p_group.mesh_scale_overrides[mesh_id] = v)
		row.add_child(scale_spin)


func _section_label(p_parent: Control, p_text: String) -> void:
	p_parent.add_child(HSeparator.new())
	var label: Label = Label.new()
	label.text = p_text
	label.add_theme_font_size_override("font_size", 16)
	p_parent.add_child(label)


func _rebuild_inspector(p_group: VegetationGroup) -> void:
	for c: Node in inspector.get_children():
		inspector.remove_child(c)
		c.queue_free()
	if p_group == null:
		return
	var group: VegetationGroup = p_group

	var name_row: HBoxContainer = _row(inspector, "Name")
	var name_edit: LineEdit = LineEdit.new()
	name_edit.text = group.group_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(t: String) -> void:
		group.group_name = t
		if selected_group_index >= 0:
			group_list.set_item_text(selected_group_index, t))
	name_row.add_child(name_edit)

	var enabled_row: HBoxContainer = _row(inspector, "Enabled")
	var enabled_check: CheckBox = CheckBox.new()
	enabled_check.button_pressed = group.enabled
	enabled_check.toggled.connect(func(v: bool) -> void: group.enabled = v)
	enabled_row.add_child(enabled_check)

	_section_label(inspector, "Meshes in this Group")
	var mesh_list: ItemList = ItemList.new()
	mesh_list.custom_minimum_size = Vector2(0, 140)
	mesh_list.select_mode = ItemList.SELECT_MULTI
	var assets: Terrain3DAssets = plugin.terrain.assets
	for i: int in assets.get_mesh_count():
		var asset: Terrain3DMeshAsset = assets.get_mesh_asset(i)
		var label_text: String = "Mesh %d" % i
		if asset and not asset.name.is_empty():
			label_text = asset.name
		mesh_list.add_item(label_text)
		if group.mesh_ids.has(i):
			mesh_list.select(i, false)
	inspector.add_child(mesh_list)

	_section_label(inspector, "Per-Mesh Scale Overrides")
	var mesh_scale_container: VBoxContainer = VBoxContainer.new()
	inspector.add_child(mesh_scale_container)
	_rebuild_mesh_scale_overrides(mesh_scale_container, group, assets)

	mesh_list.multi_selected.connect(func(_index: int, _selected: bool) -> void:
		var ids: Array[int] = []
		for idx: int in mesh_list.get_selected_items():
			ids.push_back(idx)
		group.mesh_ids = ids
		_rebuild_mesh_scale_overrides(mesh_scale_container, group, assets))

	_section_label(inspector, "Placement")
	var spacing_row: HBoxContainer = _row(inspector, "Spacing (m)")
	var spacing_spin: SpinBox = _spin(0.1, 200.0, 0.1, group.spacing)
	spacing_spin.value_changed.connect(func(v: float) -> void: group.spacing = v)
	spacing_row.add_child(spacing_spin)

	var jitter_row: HBoxContainer = _row(inspector, "Jitter")
	var jitter_spin: SpinBox = _spin(0.0, 1.0, 0.05, group.jitter)
	jitter_spin.value_changed.connect(func(v: float) -> void: group.jitter = v)
	jitter_row.add_child(jitter_spin)

	var noise_scale_row: HBoxContainer = _row(inspector, "Noise Scale")
	var noise_scale_spin: SpinBox = _spin(0.0001, 1.0, 0.001, group.noise_scale)
	noise_scale_spin.value_changed.connect(func(v: float) -> void: group.noise_scale = v)
	noise_scale_row.add_child(noise_scale_spin)

	var noise_octaves_row: HBoxContainer = _row(inspector, "Noise Octaves")
	var noise_octaves_spin: SpinBox = _spin(1, 8, 1, group.noise_octaves)
	noise_octaves_spin.value_changed.connect(func(v: float) -> void: group.noise_octaves = int(v))
	noise_octaves_row.add_child(noise_octaves_spin)

	var noise_threshold_row: HBoxContainer = _row(inspector, "Noise Threshold")
	var noise_threshold_spin: SpinBox = _spin(-1.0, 1.0, 0.01, group.noise_threshold)
	noise_threshold_spin.value_changed.connect(func(v: float) -> void: group.noise_threshold = v)
	noise_threshold_row.add_child(noise_threshold_spin)

	var seed_row: HBoxContainer = _row(inspector, "Seed")
	var seed_spin: SpinBox = _spin(0, 999999999, 1, group.seed)
	seed_spin.value_changed.connect(func(v: float) -> void: group.seed = int(v))
	seed_row.add_child(seed_spin)
	var randomize_btn: Button = Button.new()
	randomize_btn.text = "Randomize"
	randomize_btn.pressed.connect(func() -> void:
		group.seed = randi()
		seed_spin.value = group.seed)
	seed_row.add_child(randomize_btn)

	_section_label(inspector, "Constraints")
	var slope_row: HBoxContainer = _row(inspector, "Slope Range (°)")
	var slope_min: SpinBox = _spin(0.0, 90.0, 1.0, group.slope_range.x)
	var slope_max: SpinBox = _spin(0.0, 90.0, 1.0, group.slope_range.y)
	slope_min.value_changed.connect(func(v: float) -> void:
		group.slope_range = Vector2(v, group.slope_range.y))
	slope_max.value_changed.connect(func(v: float) -> void:
		group.slope_range = Vector2(group.slope_range.x, v))
	slope_row.add_child(slope_min)
	slope_row.add_child(slope_max)

	var height_row: HBoxContainer = _row(inspector, "Height Range (m)")
	var height_min: SpinBox = _spin(-100000.0, 100000.0, 1.0, group.height_range.x)
	var height_max: SpinBox = _spin(-100000.0, 100000.0, 1.0, group.height_range.y)
	height_min.value_changed.connect(func(v: float) -> void:
		group.height_range = Vector2(v, group.height_range.y))
	height_max.value_changed.connect(func(v: float) -> void:
		group.height_range = Vector2(group.height_range.x, v))
	height_row.add_child(height_min)
	height_row.add_child(height_max)

	_section_label(inspector, "Scale")
	var fixed_scale_row: HBoxContainer = _row(inspector, "Fixed Scale (%)")
	var fixed_scale_spin: SpinBox = _spin(1.0, 1000.0, 1.0, group.fixed_scale)
	fixed_scale_spin.value_changed.connect(func(v: float) -> void: group.fixed_scale = v)
	fixed_scale_row.add_child(fixed_scale_spin)

	var random_scale_row: HBoxContainer = _row(inspector, "Random Scale ± (%)")
	var random_scale_spin: SpinBox = _spin(0.0, 99.0, 1.0, group.random_scale)
	random_scale_spin.value_changed.connect(func(v: float) -> void: group.random_scale = v)
	random_scale_row.add_child(random_scale_spin)

	_section_label(inspector, "Rotation")
	var fixed_spin_row: HBoxContainer = _row(inspector, "Fixed Spin (°, around Y)")
	var fixed_spin_spin: SpinBox = _spin(0.0, 360.0, 1.0, group.fixed_spin)
	fixed_spin_spin.value_changed.connect(func(v: float) -> void: group.fixed_spin = v)
	fixed_spin_row.add_child(fixed_spin_spin)

	var random_spin_row: HBoxContainer = _row(inspector, "Random Spin (°)")
	var random_spin_spin: SpinBox = _spin(0.0, 360.0, 1.0, group.random_spin)
	random_spin_spin.value_changed.connect(func(v: float) -> void: group.random_spin = v)
	random_spin_row.add_child(random_spin_spin)

	var fixed_tilt_row: HBoxContainer = _row(inspector, "Fixed Tilt (°)")
	var fixed_tilt_spin: SpinBox = _spin(-85.0, 85.0, 1.0, group.fixed_tilt)
	fixed_tilt_spin.value_changed.connect(func(v: float) -> void: group.fixed_tilt = v)
	fixed_tilt_row.add_child(fixed_tilt_spin)

	var random_tilt_row: HBoxContainer = _row(inspector, "Random Tilt ± (°)")
	var random_tilt_spin: SpinBox = _spin(0.0, 85.0, 1.0, group.random_tilt)
	random_tilt_spin.value_changed.connect(func(v: float) -> void: group.random_tilt = v)
	random_tilt_row.add_child(random_tilt_spin)

	var align_row: HBoxContainer = _row(inspector, "Align to Normal")
	var align_check: CheckBox = CheckBox.new()
	align_check.button_pressed = group.align_to_normal
	align_check.toggled.connect(func(v: bool) -> void: group.align_to_normal = v)
	align_row.add_child(align_check)

	var height_offset_row: HBoxContainer = _row(inspector, "Height Offset (m)")
	var height_offset_spin: SpinBox = _spin(-10.0, 10.0, 0.05, group.height_offset)
	height_offset_spin.value_changed.connect(func(v: float) -> void: group.height_offset = v)
	height_offset_row.add_child(height_offset_spin)

	var random_height_row: HBoxContainer = _row(inspector, "Random Height ± (m)")
	var random_height_spin: SpinBox = _spin(0.0, 10.0, 0.05, group.random_height)
	random_height_spin.value_changed.connect(func(v: float) -> void: group.random_height = v)
	random_height_row.add_child(random_height_spin)

	_section_label(inspector, "Color")
	var color_row: HBoxContainer = _row(inspector, "Vertex Color")
	var color_button: ColorPickerButton = ColorPickerButton.new()
	color_button.color = group.vertex_color
	color_button.custom_minimum_size = Vector2(60, 24)
	color_button.color_changed.connect(func(c: Color) -> void: group.vertex_color = c)
	color_row.add_child(color_button)

	var random_hue_row: HBoxContainer = _row(inspector, "Random Hue ± (°)")
	var random_hue_spin: SpinBox = _spin(0.0, 360.0, 1.0, group.random_hue)
	random_hue_spin.value_changed.connect(func(v: float) -> void: group.random_hue = v)
	random_hue_row.add_child(random_hue_spin)

	var random_darken_row: HBoxContainer = _row(inspector, "Random Darken (%)")
	var random_darken_spin: SpinBox = _spin(0.0, 100.0, 1.0, group.random_darken)
	random_darken_spin.value_changed.connect(func(v: float) -> void: group.random_darken = v)
	random_darken_row.add_child(random_darken_spin)


## ---------------------------------------------------------------- Group list


func _load_groups() -> void:
	groups_resource = VegetationGroups.load_or_create(plugin.terrain.data_directory)
	selected_group_index = -1 if groups_resource.groups.is_empty() else 0


func _save_groups() -> void:
	if groups_resource and plugin.terrain and not plugin.terrain.data_directory.is_empty():
		groups_resource.save(plugin.terrain.data_directory)


func _refresh_group_list() -> void:
	group_list.clear()
	for group: VegetationGroup in groups_resource.groups:
		var label: String = group.group_name
		if not group.enabled:
			label += " (disabled)"
		group_list.add_item(label)
	if selected_group_index >= 0 and selected_group_index < groups_resource.groups.size():
		group_list.select(selected_group_index)
		_rebuild_inspector(groups_resource.groups[selected_group_index])
	else:
		selected_group_index = -1
		_rebuild_inspector(null)


func _on_group_selected(p_index: int) -> void:
	selected_group_index = p_index
	_rebuild_inspector(groups_resource.groups[p_index])


func _on_add_group() -> void:
	var group: VegetationGroup = VegetationGroup.new()
	group.group_name = "Group %d" % (groups_resource.groups.size() + 1)
	group.seed = randi()
	groups_resource.groups.push_back(group)
	selected_group_index = groups_resource.groups.size() - 1
	_save_groups()
	_refresh_group_list()


func _on_duplicate_group() -> void:
	if selected_group_index < 0:
		return
	var src: VegetationGroup = groups_resource.groups[selected_group_index]
	var dup: VegetationGroup = src.duplicate(true)
	dup.group_name += " Copy"
	groups_resource.groups.insert(selected_group_index + 1, dup)
	selected_group_index += 1
	_save_groups()
	_refresh_group_list()


func _on_remove_group() -> void:
	if selected_group_index < 0:
		return
	groups_resource.groups.remove_at(selected_group_index)
	selected_group_index = clampi(selected_group_index - 1, -1, groups_resource.groups.size() - 1)
	_save_groups()
	_refresh_group_list()


## ---------------------------------------------------------------- Sea level


func _get_sea_level(p_terrain: Terrain3D) -> float:
	var mat: Material = p_terrain.ocean_material if p_terrain.ocean_enabled else null
	if mat is ShaderMaterial and mat.shader:
		var v: Variant = mat.get_shader_parameter("sea_level")
		if v == null:
			v = RenderingServer.shader_get_parameter_default(mat.shader.get_rid(), "sea_level")
		if v != null:
			return float(v)
	return manual_sea_level.value


func _update_sea_level_display() -> void:
	var terrain: Terrain3D = plugin.terrain
	var has_ocean: bool = terrain.ocean_enabled and terrain.ocean_material is ShaderMaterial
	manual_sea_level.visible = not has_ocean
	if has_ocean:
		sea_level_label.text = "Sea Level: %.2f (from Ocean Material)" % _get_sea_level(terrain)
	else:
		sea_level_label.text = "Sea Level (manual):"


## ---------------------------------------------------------------- Populate / Clear


func _on_populate_pressed() -> void:
	if not _busy:
		_populate()


func _on_clear_pressed() -> void:
	if not _busy:
		_clear()


func _set_busy(p_busy: bool) -> void:
	_busy = p_busy
	populate_button.disabled = p_busy
	clear_button.disabled = p_busy


func _build_instance_transform(p_position: Vector3, p_terrain_normal: Vector3,
		p_group: VegetationGroup, p_rng: RandomNumberGenerator, p_mesh_scale_pct: float) -> Array:
	var t: Transform3D = Transform3D()
	var normal: Vector3 = Vector3.UP
	if p_group.align_to_normal:
		normal = p_terrain_normal
		if not normal.is_finite():
			normal = Vector3.UP
		else:
			normal = normal.normalized()
			var z_axis: Vector3 = Vector3(0.0, 0.0, 1.0)
			var x_axis: Vector3 = -z_axis.cross(normal)
			if x_axis.length_squared() > 0.001:
				t.basis = Basis(x_axis, normal, z_axis).orthonormalized()
	var spin: float = deg_to_rad(p_group.fixed_spin + p_group.random_spin * p_rng.randf())
	if absf(spin) > 0.001:
		t.basis = t.basis.rotated(normal, spin)
	var tilt_deg: float = p_group.fixed_tilt + p_group.random_tilt * (2.0 * p_rng.randf() - 1.0)
	var tilt: float = deg_to_rad(tilt_deg)
	if absf(tilt) > 0.001:
		t.basis = t.basis.rotated(t.basis.x, tilt)
	var scale_pct: float = p_group.fixed_scale + p_group.random_scale * (2.0 * p_rng.randf() - 1.0)
	scale_pct *= p_mesh_scale_pct * 0.01
	var t_scale: float = clampf(scale_pct * 0.01, 0.01, 10.0)
	t = t.scaled(Vector3.ONE * t_scale)
	var offset: float = p_group.height_offset + p_group.random_height * (2.0 * p_rng.randf() - 1.0)
	var final_position: Vector3 = p_position + t.basis.y * offset
	t = t.translated(final_position)
	var col: Color = p_group.vertex_color
	col.v = clampf(col.v - (p_group.random_darken * 0.01) * p_rng.randf(), 0.0, 1.0)
	col.h = fmod(col.h + (p_group.random_hue / 360.0) * (2.0 * p_rng.randf() - 1.0), 1.0)
	return [t, col]


func _populate() -> void:
	var terrain: Terrain3D = plugin.terrain
	if not terrain or not terrain.data:
		return
	if groups_resource.groups.is_empty():
		push_warning("Terrain3D: No vegetation groups defined.")
		return
	_save_groups()
	_set_busy(true)

	var sea_level: float = _get_sea_level(terrain)
	var region_size: int = int(terrain.region_size)
	var vertex_spacing: float = terrain.vertex_spacing
	var region_world_size: float = region_size * vertex_spacing
	var region_locations: Array = terrain.data.get_region_locations()

	var prev_tool: int = plugin.editor.get_tool()
	var prev_op: int = plugin.editor.get_operation()
	plugin.editor.set_tool(Terrain3DEditor.INSTANCER)
	plugin.editor.set_operation(Terrain3DEditor.ADD)
	plugin.editor.start_operation(Vector3.ZERO)

	for region_index: int in region_locations.size():
		var region_loc: Vector2i = region_locations[region_index]
		var region_count: int = region_locations.size()
		status_label.text = "Populating region %d/%d..." % [region_index + 1, region_count]
		var origin_x: float = region_loc.x * region_world_size
		var origin_z: float = region_loc.y * region_world_size

		for group: VegetationGroup in groups_resource.groups:
			if not group.enabled or group.mesh_ids.is_empty() or group.spacing <= 0.0:
				continue
			var noise: FastNoiseLite = FastNoiseLite.new()
			noise.seed = group.seed
			noise.frequency = group.noise_scale
			noise.fractal_octaves = clampi(group.noise_octaves, 1, 8)
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = group.seed ^ hash(region_loc)

			var xforms_by_mesh: Dictionary = {}
			var z: float = origin_z
			while z < origin_z + region_world_size:
				var x: float = origin_x
				while x < origin_x + region_world_size:
					var cx: float = x
					var cz: float = z
					x += group.spacing
					var jitter_amount: float = group.spacing * group.jitter * 0.5
					var jx: float = cx + rng.randf_range(-1.0, 1.0) * jitter_amount
					var jz: float = cz + rng.randf_range(-1.0, 1.0) * jitter_amount
					if noise.get_noise_2d(jx, jz) < group.noise_threshold:
						continue
					var sample_pos: Vector3 = Vector3(jx, 0.0, jz)
					var h: float = terrain.data.get_height(sample_pos)
					var out_of_height_range: bool = h < group.height_range.x or h > group.height_range.y
					if is_nan(h) or h < sea_level or out_of_height_range:
						continue
					var normal: Vector3 = terrain.data.get_normal(sample_pos)
					var slope_deg: float = 0.0
					if normal.is_finite():
						slope_deg = rad_to_deg(normal.angle_to(Vector3.UP))
					if slope_deg < group.slope_range.x or slope_deg > group.slope_range.y:
						continue
					sample_pos.y = h
					var mesh_id: int = group.mesh_ids[rng.randi() % group.mesh_ids.size()]
					var mesh_scale_pct: float = group.mesh_scale_overrides.get(mesh_id, 100.0)
					var result: Array = _build_instance_transform(sample_pos, normal, group, rng, mesh_scale_pct)
					if not xforms_by_mesh.has(mesh_id):
						xforms_by_mesh[mesh_id] = { "xforms": [], "colors": [] }
					xforms_by_mesh[mesh_id].xforms.push_back(result[0])
					xforms_by_mesh[mesh_id].colors.push_back(result[1])
				z += group.spacing

			for mesh_id: int in xforms_by_mesh:
				var accum: Dictionary = xforms_by_mesh[mesh_id]
				if accum.xforms.size() > 0:
					terrain.instancer.add_transforms(mesh_id, accum.xforms, accum.colors)
		await get_tree().process_frame

	plugin.editor.stop_operation()
	plugin.editor.set_tool(prev_tool)
	plugin.editor.set_operation(prev_op)
	terrain.instancer.update_mmis()

	status_label.text = "Done."
	_set_busy(false)


func _clear() -> void:
	var terrain: Terrain3D = plugin.terrain
	if not terrain or not terrain.instancer:
		return
	var mesh_ids: Dictionary = {}
	for group: VegetationGroup in groups_resource.groups:
		for mesh_id: int in group.mesh_ids:
			mesh_ids[mesh_id] = true
	if mesh_ids.is_empty():
		return
	_set_busy(true)
	status_label.text = "Clearing..."

	var prev_tool: int = plugin.editor.get_tool()
	var prev_op: int = plugin.editor.get_operation()
	plugin.editor.set_tool(Terrain3DEditor.INSTANCER)
	plugin.editor.set_operation(Terrain3DEditor.SUBTRACT)
	plugin.editor.start_operation(Vector3.ZERO)
	for mesh_id: int in mesh_ids:
		terrain.instancer.clear_by_mesh(mesh_id)
	plugin.editor.stop_operation()
	plugin.editor.set_tool(prev_tool)
	plugin.editor.set_operation(prev_op)
	terrain.instancer.update_mmis()

	status_label.text = "Cleared."
	_set_busy(false)
