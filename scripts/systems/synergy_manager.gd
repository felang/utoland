class_name SynergyManager
extends RefCounted

## 羁绊管理器 — 统计标签数量、计算激活档位、触发羁绊变化信号

# 单位 ID -> 标签的查找表
var _tag_lookup: Dictionary = {}


func _init() -> void:
	_build_tag_lookup()


## 构建单位 ID -> tag 的查找表（武器、塔、角色）
func _build_tag_lookup() -> void:
	_tag_lookup.clear()
	for id: String in GameConfig.weapons:
		var data: WeaponData = GameConfig.weapons[id]
		if data.tag != "":
			_tag_lookup[id] = data.tag
	for id: String in GameConfig.towers:
		var data: TowerData = GameConfig.towers[id]
		if data.tag != "":
			_tag_lookup[id] = data.tag
	for id: String in GameConfig.characters:
		var data: CharacterData = GameConfig.characters[id]
		if data.tag != "":
			_tag_lookup[id] = data.tag


## 获取单位的标签
func get_tag(unit_id: String) -> String:
	return _tag_lookup.get(unit_id, "")


## 统计当前阵容中各标签的数量
func count_tags() -> Dictionary:
	var counts: Dictionary = {}
	# 角色贡献 1 个标签
	var char_tag: String = get_tag(GameData.current_character)
	if char_tag != "":
		counts[char_tag] = counts.get(char_tag, 0) + 1
	# 已上阵武器各贡献 1 个标签
	for weapon: Dictionary in GameData.deployed_weapons:
		var tag: String = get_tag(weapon.id)
		if tag != "":
			counts[tag] = counts.get(tag, 0) + 1
	# 已布置塔各贡献 1 个标签
	for tower: Dictionary in GameData.deployed_towers:
		var tag: String = get_tag(tower.id)
		if tag != "":
			counts[tag] = counts.get(tag, 0) + 1
	return counts


## 根据数量计算激活的档位（0/2/3/5）
func _calculate_tier(count: int) -> int:
	# 默认阈值 [2, 3, 5]
	var thresholds := PackedInt32Array([2, 3, 5])
	var tier: int = 0
	# 从高到低检查，取最高满足的档位
	for i in range(thresholds.size() - 1, -1, -1):
		if count >= thresholds[i]:
			tier = thresholds[i]
			break
	return tier


## 重新计算羁绊状态并更新 GameData
func recalculate() -> void:
	var new_counts: Dictionary = count_tags()
	var old_tiers: Dictionary = GameData.synergy_active_tiers.duplicate()
	var new_tiers: Dictionary = {}
	# 计算所有标签的新档位
	for tag: String in new_counts:
		var tier: int = _calculate_tier(new_counts[tag])
		if tier > 0:
			new_tiers[tag] = tier
	# 更新 GameData
	GameData.synergy_tag_counts = new_counts
	GameData.synergy_active_tiers = new_tiers
	# 检测变化并发射信号
	# 检查新增或变化的标签
	for tag: String in Enums.Tag.ALL:
		var old_tier: int = old_tiers.get(tag, 0)
		var new_tier: int = new_tiers.get(tag, 0)
		if old_tier != new_tier:
			EventBus.synergy_changed.emit(tag, old_tier, new_tier)


## 检查指定标签是否达到 3 档
func is_tier3_active(tag: String) -> bool:
	return GameData.synergy_active_tiers.get(tag, 0) >= 3


# ===== 2 档效果查询 =====

## 无内在 boost 机制的单位列表（boost 标签激活时回退为伤害加成）
const _BOOST_FALLBACK_UNITS: PackedStringArray = ["pea_shooter", "thorn", "laser"]


## 获取单位的伤害倍率加成（assault 2 档 / boost 回退）
func get_damage_mult_bonus(unit_id: String) -> float:
	var tag: String = get_tag(unit_id)
	if tag == "":
		return 0.0
	# assault 标签：2 档 damage_mult 加成
	if tag == Enums.Tag.ASSAULT and GameData.synergy_active_tiers.get(tag, 0) >= 2:
		var synergy: SynergyData = GameConfig.synergies.get(tag)
		if synergy and synergy.tier2_stat == "damage_mult":
			return synergy.tier2_value
	# boost 标签：无内在 boost 机制的单位回退为伤害加成
	if tag == Enums.Tag.BOOST and GameData.synergy_active_tiers.get(tag, 0) >= 2:
		if unit_id in _BOOST_FALLBACK_UNITS:
			var synergy: SynergyData = GameConfig.synergies.get(tag)
			if synergy:
				return synergy.tier2_value
	return 0.0


## 获取控制持续时间加成（control 2 档）
func get_control_duration_bonus() -> float:
	if GameData.synergy_active_tiers.get(Enums.Tag.CONTROL, 0) >= 2:
		var synergy: SynergyData = GameConfig.synergies.get(Enums.Tag.CONTROL)
		if synergy:
			return synergy.tier2_value
	return 0.0


## 获取范围伤害范围加成（blast 2 档）
func get_aoe_range_bonus() -> float:
	if GameData.synergy_active_tiers.get(Enums.Tag.BLAST, 0) >= 2:
		var synergy: SynergyData = GameConfig.synergies.get(Enums.Tag.BLAST)
		if synergy:
			return synergy.tier2_value
	return 0.0


## 获取增益效果强度加成（boost 2 档）
func get_boost_strength_bonus() -> float:
	if GameData.synergy_active_tiers.get(Enums.Tag.BOOST, 0) >= 2:
		var synergy: SynergyData = GameConfig.synergies.get(Enums.Tag.BOOST)
		if synergy:
			return synergy.tier2_value
	return 0.0
