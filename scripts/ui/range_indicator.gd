extends Node2D
class_name RangeIndicator
# 攻击范围圈指示器

const FILL_COLOR = Color(0.3, 0.5, 1.0, 0.1)
const BORDER_COLOR = Color(0.3, 0.5, 1.0, 0.4)
const BORDER_WIDTH = 1.5
const ARC_SEGMENTS = 64  # 弧线平滑度

var radius: float = 0.0

func set_range(value: float) -> void:
	radius = value
	visible = radius > 0.0
	queue_redraw()

func hide_range() -> void:
	set_range(0.0)

func _draw() -> void:
	if radius <= 0.0:
		return
	draw_circle(Vector2.ZERO, radius, FILL_COLOR)
	draw_arc(Vector2.ZERO, radius, 0, TAU, ARC_SEGMENTS, BORDER_COLOR, BORDER_WIDTH)
