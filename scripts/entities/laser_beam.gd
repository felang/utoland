extends Node2D

# 激光视觉效果 — Line2D 显示 + Tween 淡出
# 只负责视觉，伤害在 player.gd 中通过射线查询结算

var beam_duration: float = 0.08

@onready var line: Line2D = $Line2D

func _ready() -> void:
	beam_duration = GameConfig.WEAPONS["laser"]["beam_duration"]

func fire(from: Vector2, to: Vector2) -> void:
	global_position = Vector2.ZERO
	line.clear_points()
	line.add_point(from)
	line.add_point(to)
	var tween: Tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, beam_duration)
	tween.tween_callback(queue_free)
