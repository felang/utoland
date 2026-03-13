# FlameProjectile — 持续型锥形伤害，由 FlamethrowerWeapon 维持
class_name FlameProjectile
extends Node2D

var flame_damage: float = 3.0
var flame_range: float = 100.0
var cone_angle: float = 45.0
var _tick_interval: float = 0.1
var _tick_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if not visible:
		return
	_tick_timer -= delta
	if _tick_timer <= 0:
		_tick_timer = _tick_interval
		_deal_damage()

func _deal_damage() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	var half_angle: float = deg_to_rad(cone_angle / 2.0)
	var forward: Vector2 = Vector2.RIGHT.rotated(rotation)
	for enemy in enemies:
		if enemy is Node2D:
			var to_enemy: Vector2 = enemy.global_position - global_position
			var dist: float = to_enemy.length()
			if dist <= flame_range and dist > 0:
				var angle: float = forward.angle_to(to_enemy.normalized())
				if absf(angle) <= half_angle:
					if enemy.has_method("take_damage"):
						enemy.take_damage(flame_damage)

func update_direction(target_pos: Vector2) -> void:
	var dir: Vector2 = target_pos - global_position
	if dir.length() > 0:
		rotation = dir.angle()
