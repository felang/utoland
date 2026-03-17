class_name BounceOnHitComponent
extends Node

signal bounces_exhausted

@export var bounce_range: float = 150.0
@export var max_bounces: int = 1
var manages_lifecycle: bool = true

var _bounce_count: int = 0
var _hit_enemies: Array[Node2D] = []

func on_hit(target: Node2D, projectile: Node2D) -> void:
	# 防止同帧重叠敌人触发多次命中
	if target in _hit_enemies:
		return
	_hit_enemies.append(target)
	_bounce_count += 1
	# 命中后暂停碰撞检测，弹射重定向后再启用
	var hitbox = projectile.get_node_or_null("Hitbox") if projectile else null
	if _bounce_count > max_bounces:
		if projectile:
			projectile._should_destroy = true
		bounces_exhausted.emit()
		return
	var bounce_target: Node2D = _find_bounce_target(target.global_position)
	if bounce_target and projectile:
		projectile.direction = projectile.global_position.direction_to(bounce_target.global_position)
		# 短暂禁用再启用，避免弹射瞬间碰到相邻敌人
		if hitbox:
			hitbox.set_deferred("monitoring", false)
			projectile.get_tree().create_timer(0.05).timeout.connect(func() -> void:
				if is_instance_valid(hitbox):
					hitbox.monitoring = true
			)
	else:
		if projectile:
			projectile._should_destroy = true
		bounces_exhausted.emit()

func _find_bounce_target(from_pos: Vector2) -> Node2D:
	if not is_inside_tree():
		return null
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	var closest: Node2D = null
	var min_dist: float = bounce_range * bounce_range
	for enemy in enemies:
		if enemy in _hit_enemies:
			continue
		if not is_instance_valid(enemy):
			continue
		var dist: float = from_pos.distance_squared_to((enemy as Node2D).global_position)
		if dist < min_dist:
			min_dist = dist
			closest = enemy as Node2D
	return closest

func reset() -> void:
	_bounce_count = 0
	_hit_enemies.clear()
