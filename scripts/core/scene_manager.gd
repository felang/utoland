extends Node

const SCENES: Dictionary = {
	"start_menu":          "res://scenes/ui/start_menu.tscn",
	"character_selection": "res://scenes/ui/character_selection.tscn",
	"map_select":          "res://scenes/ui/map_select.tscn",
	"result":              "res://scenes/ui/result.tscn",
	"placement":           "res://scenes/levels/placement.tscn",
	"main":                "res://scenes/levels/main.tscn",
}

const FADE_DURATION: float = 0.3

var _fade_rect: ColorRect
var _is_transitioning: bool = false

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 200
	add_child(canvas)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_fade_rect)

func go_to(scene_name: String) -> void:
	assert(SCENES.has(scene_name), "未知场景: " + scene_name)
	if _is_transitioning:
		return
	_is_transitioning = true
	# 淡出
	var tween_out: Tween = create_tween()
	tween_out.tween_property(_fade_rect, "color:a", 1.0, FADE_DURATION)
	await tween_out.finished
	# 切换场景
	get_tree().change_scene_to_file(SCENES[scene_name])
	# 等一帧让新场景初始化
	await get_tree().process_frame
	# 淡入
	var tween_in: Tween = create_tween()
	tween_in.tween_property(_fade_rect, "color:a", 0.0, FADE_DURATION)
	await tween_in.finished
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
