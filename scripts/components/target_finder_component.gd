class_name TargetFinderComponent
extends Node

enum TargetStrategy { NEAREST, LOWEST_HP, HIGHEST_HP, RANDOM }

signal target_changed(new_target: Node2D)

@export var detect_range: float = 100.0
@export var strategy: TargetStrategy = TargetStrategy.NEAREST

var _current_target: Node2D = null
var _detect_area: Area2D = null
var _collision_shape: CollisionShape2D = null

func _ready() -> void:
	_detect_area = Area2D.new()
	_detect_area.name = "DetectArea"
	_detect_area.collision_layer = 0
	_detect_area.collision_mask = 2  # enemies layer
	_detect_area.monitoring = true
	_detect_area.monitorable = false
	_collision_shape = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = detect_range
	_collision_shape.shape = shape
	_detect_area.add_child(_collision_shape)
	add_child(_detect_area)

func set_range(new_range: float) -> void:
	detect_range = new_range
	if _collision_shape and _collision_shape.shape:
		(_collision_shape.shape as CircleShape2D).radius = new_range

func get_target() -> Node2D:
	if not _detect_area:
		return null
	var bodies: Array[Node2D] = _detect_area.get_overlapping_bodies()
	if bodies.is_empty():
		_update_target(null)
		return null

	var result: Node2D = null
	match strategy:
		TargetStrategy.NEAREST:
			result = _find_nearest(bodies)
		TargetStrategy.LOWEST_HP:
			result = _find_lowest_hp(bodies)
		TargetStrategy.HIGHEST_HP:
			result = _find_highest_hp(bodies)
		TargetStrategy.RANDOM:
			result = bodies.pick_random()

	_update_target(result)
	return result

func _update_target(new_target: Node2D) -> void:
	if new_target != _current_target:
		_current_target = new_target
		target_changed.emit(new_target)

func _find_nearest(bodies: Array[Node2D]) -> Node2D:
	var closest: Node2D = null
	var min_dist: float = INF
	var origin: Vector2 = global_position
	for body in bodies:
		if not is_instance_valid(body):
			continue
		var dist: float = origin.distance_squared_to(body.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = body
	return closest

func _find_lowest_hp(bodies: Array[Node2D]) -> Node2D:
	var result: Node2D = null
	var min_hp: float = INF
	for body in bodies:
		if not is_instance_valid(body):
			continue
		var health = body.get_node_or_null("HealthComponent")
		if health and health.current_hp < min_hp:
			min_hp = health.current_hp
			result = body
	return result

func _find_highest_hp(bodies: Array[Node2D]) -> Node2D:
	var result: Node2D = null
	var max_hp: float = -1.0
	for body in bodies:
		if not is_instance_valid(body):
			continue
		var health = body.get_node_or_null("HealthComponent")
		if health and health.current_hp > max_hp:
			max_hp = health.current_hp
			result = body
	return result
