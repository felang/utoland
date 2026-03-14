# Weapon — 武器基类（不可见 Node）
# 管理冷却时间，fire() 由子类实现
class_name Weapon
extends Node

var weapon_data: WeaponData = null
var owner_node: Node2D = null
var _cooldown: float = 0.0

func initialize(data: WeaponData) -> void:
	weapon_data = data
	_cooldown = 0.0

func get_current_level() -> int:
	return GameData.owned_weapons.get(weapon_data.id, 1)

func get_damage() -> float:
	var base: float = weapon_data.damage_per_level[get_current_level() - 1]
	# 角色被动：低血量伤害加成（仅影响武器伤害，不影响塔伤害）
	if GameData.character_passive_type == Enums.PassiveType.DAMAGE_ON_LOW_HP:
		if owner_node and owner_node.has_node("HealthComponent"):
			var hp: HealthComponent = owner_node.get_node("HealthComponent")
			if hp.current_hp / hp.max_hp < 0.3:
				base *= (1.0 + GameData.character_passive_value)
	return base

func get_fire_rate() -> float:
	return weapon_data.fire_rate_per_level[get_current_level() - 1]

func get_weapon_range() -> float:
	return weapon_data.weapon_range_per_level[get_current_level() - 1]

func tick(delta: float, target: Node2D) -> void:
	_cooldown -= delta
	if _cooldown <= 0.0 and target:
		fire(target)
		var speed_mult: float = GameData.player_stats.get(Enums.Stat.ATTACK_SPEED_MULT, 1.0)
		_cooldown = get_fire_rate() / speed_mult

func fire(_target: Node2D) -> void:
	pass  # 子类实现
