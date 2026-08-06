extends CanvasLayer
## Lightweight performance overlay: FPS, frame/physics time, memory, and
## render stats. Independent of the player-facing UI (ui/hud.gd) -- an
## autoload so it's available in any scene. Toggled with the
## toggle_dev_hud action (F9). Godot doesn't expose true system CPU/GPU
## utilization percentages cross-platform, so CPU is shown as frame time
## against a 60fps budget and GPU as video memory + draw call counts,
## the standard proxies for an in-engine debug overlay.

const TARGET_FRAME_TIME_MS: float = 1000.0 / 60.0
const BYTES_PER_MEBIBYTE: float = 1024.0 * 1024.0

@onready var _label: Label = $StatsLabel


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_dev_hud"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	_label.text = _build_stats_text()


func _build_stats_text() -> String:
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var frame_time_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_time_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var cpu_budget_percent := (frame_time_ms / TARGET_FRAME_TIME_MS) * 100.0
	var static_mem_mb := OS.get_static_memory_usage() / BYTES_PER_MEBIBYTE
	var video_mem_mb := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / BYTES_PER_MEBIBYTE
	var texture_mem_mb := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / BYTES_PER_MEBIBYTE
	var buffer_mem_mb := Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / BYTES_PER_MEBIBYTE
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objects := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	return (
		"FPS: %d  (%.2f ms/frame)\n" +
		"CPU frame budget: %.0f%% of 60fps\n" +
		"Physics: %.2f ms\n" +
		"Memory (RAM): %.1f MB\n" +
		"Video memory (GPU): %.1f MB\n" +
		"  Textures: %.1f MB  |  Buffers: %.1f MB\n" +
		"Draw calls: %d  |  Objects: %d  |  Primitives: %d"
	) % [
		fps, frame_time_ms,
		cpu_budget_percent,
		physics_time_ms,
		static_mem_mb,
		video_mem_mb,
		texture_mem_mb, buffer_mem_mb,
		draw_calls, objects, primitives,
	]
