extends Node2D

# 激光视觉效果 — Line2D 加粗 + 边缘渐变 + 淡出

var beam_duration: float = 0.08

@onready var line: Line2D = $Line2D

func _ready() -> void:
	beam_duration = GameConfig.weapons["laser"].beam_duration
	# 应用特效配置
	var fx: EffectConfigData = GameConfig.effects
	line.width = fx.laser_beam_width
	# 渐变：边缘红 → 中心白 → 边缘红
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, fx.laser_edge_color)
	gradient.add_point(0.5, fx.laser_core_color)
	gradient.set_color(gradient.get_point_count() - 1, fx.laser_edge_color)
	line.gradient = gradient

func fire(from: Vector2, to: Vector2) -> void:
	global_position = Vector2.ZERO
	line.clear_points()
	line.add_point(from)
	line.add_point(to)
	# 击中点闪光
	EffectsManager.spawn_hit_sparks(to, Color(1, 0.3, 0.3))
	var tween: Tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, beam_duration)
	tween.tween_callback(queue_free)
