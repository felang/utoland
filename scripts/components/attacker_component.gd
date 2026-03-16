class_name AttackerComponent
extends Node

enum AttackMode { RANGED, MELEE }

signal attack_fired(target: Node2D, projectile_data: ProjectileData)
signal melee_triggered(target: Node2D, melee_config: MeleeConfig)
signal target_changed(new_target: Node2D)

# 配置
var attack_mode: AttackMode = AttackMode.RANGED
var base_damage: float = 0.0
var attack_range: float = 0.0
var base_cooldown: float = 1.0
var projectile_data: ProjectileData = null
var melee_config: MeleeConfig = null

# 外部注入
var target_finder: Callable  ## func(range: float) -> Node2D
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0

# 内部状态
var _cooldown_remaining: float = 0.0
var _current_target: Node2D = null

func init_attacker(
	p_damage: float,
	p_range: float,
	p_cooldown: float,
	p_mode: AttackMode,
	p_projectile_data: ProjectileData,
	p_melee_config: MeleeConfig
) -> void:
	base_damage = p_damage
	attack_range = p_range
	base_cooldown = p_cooldown
	attack_mode = p_mode
	projectile_data = p_projectile_data
	melee_config = p_melee_config
	_cooldown_remaining = 0.0

func update_stats(p_damage: float, p_range: float, p_cooldown: float) -> void:
	base_damage = p_damage
	attack_range = p_range
	base_cooldown = p_cooldown

func get_final_damage() -> float:
	return base_damage * damage_multiplier

func get_final_cooldown() -> float:
	if speed_multiplier <= 0.0:
		return base_cooldown
	return base_cooldown / speed_multiplier

func tick(delta: float) -> void:
	_cooldown_remaining -= delta
	if _cooldown_remaining > 0.0:
		return
	if not target_finder.is_valid():
		return
	var target: Node2D = target_finder.call(attack_range)
	if target != _current_target:
		_current_target = target
		target_changed.emit(target)
	if target == null:
		return
	_cooldown_remaining = get_final_cooldown()
	_execute_attack(target)

func _execute_attack(target: Node2D) -> void:
	match attack_mode:
		AttackMode.RANGED:
			attack_fired.emit(target, projectile_data)
		AttackMode.MELEE:
			melee_triggered.emit(target, melee_config)
