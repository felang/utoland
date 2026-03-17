class_name RangedAttackComponent
extends Node

signal attack_executed(target: Node2D, projectile: Node2D)
signal projectile_spawned(proj: Node2D)

var attack_config: AttackConfigData = null
var projectile_data: ProjectileData = null
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var on_projectile_created: Callable  # 可选回调
var sfx_id: String = "shoot"

var _base_damage: float = 0.0
var _base_cooldown: float = 1.0
var _cooldown_remaining: float = 0.0
var _target_finder: TargetFinderComponent = null
var _fire_point: Marker2D = null

func _ready() -> void:
	# TargetFinder 在 Pivot 下（parent 的 parent），攻击组件在 Offset 下
	var pivot = get_parent().get_parent() if get_parent() else null
	_target_finder = pivot.get_node_or_null("TargetFinderComponent") if pivot else null
	# FirePoint 是兄弟节点（都在 WeaponOffset 下）
	_fire_point = get_parent().get_node_or_null("FirePoint")

func set_level(level: int) -> void:
	if not attack_config:
		return
	var idx: int = level - 1
	if idx < attack_config.damage_per_level.size():
		_base_damage = attack_config.damage_per_level[idx]
	if idx < attack_config.fire_rate_per_level.size():
		_base_cooldown = attack_config.fire_rate_per_level[idx]
	if _target_finder and idx < attack_config.attack_range_per_level.size():
		_target_finder.set_range(attack_config.attack_range_per_level[idx])

func tick(delta: float) -> void:
	_cooldown_remaining -= delta
	if _cooldown_remaining > 0.0:
		return
	if not _target_finder:
		return
	var target: Node2D = _target_finder.get_target()
	if not target or not is_instance_valid(target):
		return
	_execute_attack(target)
	_cooldown_remaining = get_final_cooldown()

func get_final_damage() -> float:
	return _base_damage * damage_multiplier

func get_final_cooldown() -> float:
	if speed_multiplier <= 0.0:
		return _base_cooldown
	return _base_cooldown / speed_multiplier

func _execute_attack(target: Node2D) -> void:
	if not projectile_data:
		return
	var fire_pos: Vector2
	if _fire_point:
		fire_pos = _fire_point.global_position
	else:
		fire_pos = get_parent().global_position
	var direction: Vector2 = fire_pos.direction_to(target.global_position)
	var damage: float = get_final_damage()
	var proj: Node2D = SceneFactory.create_projectile(projectile_data, damage, fire_pos, direction)
	if on_projectile_created.is_valid():
		on_projectile_created.call(proj)
	projectile_spawned.emit(proj)
	attack_executed.emit(target, proj)
	AudioManager.play(sfx_id)
