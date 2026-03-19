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
var use_lead_shot: bool = false

var _base_damage: float = 0.0
var _base_cooldown: float = 1.0
var _cooldown_remaining: float = 0.0
var _target_finder: TargetFinderComponent = null
var _fire_point: Marker2D = null

func _ready() -> void:
	# TargetFinder 和攻击组件都在 Pivot 下（兄弟节点）
	_target_finder = get_parent().get_node_or_null("TargetFinderComponent")
	# FirePoint 在 WeaponOffset 下
	var offset = get_parent().get_node_or_null("WeaponOffset")
	if offset:
		_fire_point = offset.get_node_or_null("FirePoint")

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
		# 无目标时钳制冷却为 0，防止 SHOP 阶段积累深度负值导致开战瞬间齐射
		_cooldown_remaining = 0.0
		return
	# 实际距离校验：get_overlapping_bodies 返回上一物理帧结果，目标可能已离开范围
	if _target_finder.global_position.distance_to(target.global_position) > _target_finder.detect_range:
		_cooldown_remaining = 0.0
		return
	_execute_attack(target)
	_cooldown_remaining = get_final_cooldown()

func get_final_damage() -> float:
	return _base_damage * damage_multiplier

func get_final_cooldown() -> float:
	if speed_multiplier <= 0.0:
		return _base_cooldown
	return _base_cooldown / speed_multiplier

func _calculate_direction(fire_pos: Vector2, target_pos: Vector2, target_velocity: Vector2, proj_speed: float) -> Vector2:
	if use_lead_shot and target_velocity.length_squared() > 0.0:
		var distance: float = fire_pos.distance_to(target_pos)
		var flight_time: float = distance / proj_speed
		var predicted_pos: Vector2 = target_pos + target_velocity * flight_time
		return fire_pos.direction_to(predicted_pos)
	return fire_pos.direction_to(target_pos)

func _execute_attack(target: Node2D) -> void:
	if not projectile_data:
		return
	var fire_pos: Vector2
	if _fire_point:
		fire_pos = _fire_point.global_position
	else:
		fire_pos = get_parent().global_position
	var target_velocity: Vector2 = target.velocity if "velocity" in target else Vector2.ZERO
	var direction: Vector2 = _calculate_direction(fire_pos, target.global_position, target_velocity, projectile_data.speed)
	var damage: float = get_final_damage()
	var proj_target: Node2D = null if use_lead_shot else target
	var proj: Node2D = SceneFactory.create_projectile(projectile_data, damage, fire_pos, direction, proj_target)
	if on_projectile_created.is_valid():
		on_projectile_created.call(proj)
	projectile_spawned.emit(proj)
	attack_executed.emit(target, proj)
	AudioManager.play(sfx_id)
