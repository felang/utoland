class_name TowerRollManager
extends RefCounted

## Roll 塔管理器 — 替代旧 ShopManager
##
## 职责:
##   - 加载 TierWeightTable
##   - 按英雄等级 + 动态权重抽 3 个 tower_id

const TIER_WEIGHT_TABLE_PATH: String = "res://resources/shop/tier_weight_table.tres"

var _tier_table: TierWeightTable = null

func _init() -> void:
	_tier_table = load(TIER_WEIGHT_TABLE_PATH)

## 抽 3 个候选(可重复),按英雄等级 + 动态权重
func roll_three(player_level: int) -> Array:
	var result: Array = []
	for i in 3:
		var picked: String = _roll_one(player_level)
		if picked != "":
			result.append(picked)
	return result

func _roll_one(player_level: int) -> String:
	var tier_weights: Array = _tier_table.get_tier_weights(player_level) if _tier_table else [1.0, 0.0, 0.0, 0.0]
	# 第一步:按 Tier 权重选 Tier
	var picked_tier: int = _weighted_pick(tier_weights) + 1
	# 第二步:在该 Tier 内按基础权重 × 动态权重选塔
	var candidates: Array = _towers_of_tier(picked_tier)
	if candidates.is_empty():
		# 若该 Tier 无塔,降到 Tier 1 兜底
		candidates = _towers_of_tier(1)
		if candidates.is_empty():
			return ""
	var weights: Array = []
	var dynamic_mult: float = GameConfig.shop_config.dynamic_weight_multiplier
	for tower_id in candidates:
		var w: float = 1.0
		if _has_unleveled_deployed(tower_id):
			w *= dynamic_mult
		weights.append(w)
	var pick_idx: int = _weighted_pick(weights)
	return candidates[pick_idx]

func _towers_of_tier(tier: int) -> Array:
	var result: Array = []
	for tower_id: String in GameConfig.towers:
		var data: TowerData = GameConfig.towers[tower_id]
		if data and data.tier == tier:
			result.append(tower_id)
	return result

func _has_unleveled_deployed(tower_id: String) -> bool:
	# 已部署中存在 < Lv3 的同 id 塔时,加权
	for entry in InventoryManager.deployed_towers:
		if entry.id == tower_id and entry.level < 3:
			return true
	return false

func _weighted_pick(weights: Array) -> int:
	var total: float = 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return 0
	var r: float = randf() * total
	var acc: float = 0.0
	for i in weights.size():
		acc += weights[i]
		if r <= acc:
			return i
	return weights.size() - 1
