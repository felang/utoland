# ChainProjectile — 瞬时命中 + 链式跳跃伤害
class_name ChainProjectile
extends Node2D

var chain_count: int = 3
var chain_decay: float = 0.7
var chain_range: float = 150.0
var _damage: float = 0.0
var _visual_duration: float = 0.15

func _on_setup(_direction: Vector2) -> void:
	pass

func execute_chain(first_target: Node2D, damage: float) -> void:
	_damage = damage
	var targets: Array[Node2D] = [first_target]
	var current_damage: float = damage
	var current_target: Node2D = first_target
	if current_target.has_method("take_damage"):
		current_target.take_damage(current_damage)
	for _i in chain_count:
		current_damage *= chain_decay
		var next_target: Node2D = _find_next_target(current_target, targets)
		if not next_target:
			break
		targets.append(next_target)
		current_target = next_target
		if current_target.has_method("take_damage"):
			current_target.take_damage(current_damage)
	_draw_chain(targets)
	var timer: SceneTreeTimer = get_tree().create_timer(_visual_duration)
	timer.timeout.connect(queue_free)

func _find_next_target(from: Node2D, exclude: Array[Node2D]) -> Node2D:
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	var closest: Node2D = null
	var min_dist: float = chain_range
	for enemy in enemies:
		if enemy is Node2D and enemy not in exclude:
			var dist: float = from.global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy
	return closest

func _draw_chain(targets: Array[Node2D]) -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color(0.5, 0.8, 1.0, 0.9)
	line.top_level = true
	for t in targets:
		if is_instance_valid(t):
			line.add_point(t.global_position)
	add_child(line)
