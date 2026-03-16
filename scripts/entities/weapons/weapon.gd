# Weapon — 武器基类（不可见 Node）
# 管理冷却时间，fire() 由子类实现
class_name Weapon
extends Node

var weapon_data: WeaponData = null
var owner_node: Node2D = null
var sprite: Sprite2D = null  # 漂浮精灵引用，由 WeaponManager 注入
var _cooldown: float = 0.0
var _level: int = 1

func initialize(data: WeaponData) -> void:
	weapon_data = data
	_cooldown = 0.0

func set_level(level: int) -> void:
	_level = level

func get_current_level() -> int:
	return _level

func get_damage() -> float:
	var base: float = weapon_data.damage_per_level[get_current_level() - 1]
	# 新被动：疾风连击（Kaze）— 连击伤害加成
	if GameData.new_passive_id == "swift_combo" and owner_node and owner_node.has_method("get_combo_damage_mult"):
		base *= owner_node.get_combo_damage_mult()
	# 新被动：血怒（Gorg）— 失血伤害加成
	if GameData.new_passive_id == "blood_rage" and owner_node and owner_node.has_method("get_blood_rage_mult"):
		base *= owner_node.get_blood_rage_mult()
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

## 获取发射位置（优先使用武器精灵位置，否则回退到角色位置）
func get_fire_position() -> Vector2:
	if sprite and is_instance_valid(sprite):
		return sprite.global_position
	if owner_node:
		return owner_node.global_position
	return Vector2.ZERO

func fire(_target: Node2D) -> void:
	pass  # 子类实现
