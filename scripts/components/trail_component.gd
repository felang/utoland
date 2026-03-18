class_name TrailComponent
extends Node

@export var trail_color: Color = Color.WHITE
@export var trail_width: float = 2.0
@export var max_points: int = 4

var _trail: Line2D = null

func on_projectile_setup(_projectile: Node2D) -> void:
	if not _trail:
		_trail = Line2D.new()
		_trail.width = trail_width
		_trail.default_color = trail_color
		add_child(_trail)
	_trail.clear_points()
	_trail.visible = true

func _process(_delta: float) -> void:
	if not _trail or not _trail.visible:
		return
	var proj: Node2D = get_parent()
	if not proj:
		return
	_trail.add_point(_trail.to_local(proj.global_position))
	while _trail.get_point_count() > max_points:
		_trail.remove_point(0)

func reset() -> void:
	if _trail:
		_trail.clear_points()
		_trail.visible = false
