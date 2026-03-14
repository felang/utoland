# Weapon — 武器基类（不可见 Node）
# 管理冷却时间，fire() 由子类实现
class_name Weapon
extends Node

var weapon_data: WeaponData = null
var owner_node: Node2D = null
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
	# 羁绊 2 档：伤害倍率加成（assault / boost 回退）
	if GameData._synergy_manager:
		var synergy_bonus: float = GameData._synergy_manager.get_damage_mult_bonus(weapon_data.id)
		base *= (1.0 + synergy_bonus)
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
		# Assault 3: 狂热 — 攻速翻倍（冷却减半）
		if _is_frenzy_active():
			speed_mult *= 2.0
		_cooldown = get_fire_rate() / speed_mult

func fire(_target: Node2D) -> void:
	pass  # 子类实现


## 查询狂热是否激活
func _is_frenzy_active() -> bool:
	if not is_inside_tree():
		return false
	var processors: Array[Node] = get_tree().get_nodes_in_group("synergy_processor")
	if processors.size() > 0:
		var processor: SynergyEffectProcessor = processors[0] as SynergyEffectProcessor
		if processor:
			return processor.is_frenzy_active()
	return false
