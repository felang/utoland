class_name UpgradeGenerator
extends RefCounted

## 按玩家等级返回稀有度权重，替换静态 RARITY_WEIGHTS/TOWER_RARITY_WEIGHTS
static func get_rarity_weights(player_level: int) -> Dictionary:
	if player_level <= 2:
		return {0: 1.0, 1: 0.3, 2: 0.0}
	elif player_level <= 4:
		return {0: 1.0, 1: 0.6, 2: 0.15}
	elif player_level <= 6:
		return {0: 1.0, 1: 0.8, 2: 0.3}
	else:
		return {0: 1.0, 1: 1.0, 2: 0.5}

## 合并的武器+塔升级选项生成器
## 从武器和塔的池子中加权随机抽取 3 个选项

func generate_options(exclude: Array[Dictionary] = []) -> Array[Dictionary]:
	var pool: Array[Dictionary] = _build_pool(exclude)
	_apply_weights(pool)
	# 加权随机抽取（轮盘赌算法）
	var result: Array[Dictionary] = []
	for _i in mini(pool.size(), 3):
		if pool.is_empty():
			break
		var total_weight: float = 0.0
		for opt in pool:
			total_weight += opt["_weight"]
		var roll: float = randf() * total_weight
		var cumulative: float = 0.0
		var selected_idx: int = 0
		for j in pool.size():
			cumulative += pool[j]["_weight"]
			if roll <= cumulative:
				selected_idx = j
				break
		var selected: Dictionary = pool[selected_idx].duplicate()
		selected.erase("_weight")
		result.append(selected)
		pool.remove_at(selected_idx)
	return result

func get_refresh_cost(refresh_count: int) -> int:
	if refresh_count == 0:
		return 0
	return 5 * refresh_count

func _build_pool(exclude: Array[Dictionary]) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var exclude_keys: Array[String] = []
	for ex in exclude:
		exclude_keys.append(ex.get("type", "") + ":" + ex.get("id", ""))
	# 武器池
	for weapon_id: String in GameConfig.weapons:
		if ("weapon:" + weapon_id) in exclude_keys:
			continue
		var current_level: int = GameData.owned_weapons.get(weapon_id, 0)
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		if current_level == 0:
			pool.append({
				"type": "weapon", "id": weapon_id,
				"target_level": 1, "is_new": true, "current_level": 0,
				"_weight": get_rarity_weights(GameData.current_level).get(wd.rarity, 1.0)
			})
		elif current_level < wd.max_level:
			pool.append({
				"type": "weapon", "id": weapon_id,
				"target_level": current_level + 1, "is_new": false,
				"current_level": current_level, "_weight": get_rarity_weights(GameData.current_level).get(wd.rarity, 1.0)
			})
	# 塔池
	for tower_id: String in GameConfig.towers:
		if ("tower:" + tower_id) in exclude_keys:
			continue
		var current_level: int = GameData.owned_towers.get(tower_id, 0)
		var td: TowerData = GameConfig.towers[tower_id]
		if current_level == 0:
			pool.append({
				"type": "tower", "id": tower_id,
				"target_level": 1, "is_new": true, "current_level": 0,
				"_weight": get_rarity_weights(GameData.current_level).get(td.rarity, 1.0)
			})
		elif current_level < td.max_level:
			pool.append({
				"type": "tower", "id": tower_id,
				"target_level": current_level + 1, "is_new": false,
				"current_level": current_level, "_weight": get_rarity_weights(GameData.current_level).get(td.rarity, 1.0)
			})
	return pool

func _apply_weights(pool: Array[Dictionary]) -> void:
	var weapon_count: int = GameData.owned_weapons.size()
	var tower_count: int = GameData.owned_towers.size()
	for opt in pool:
		if opt["type"] == "tower" and tower_count < weapon_count:
			opt["_weight"] *= 1.5
		elif opt["type"] == "weapon" and weapon_count < tower_count:
			opt["_weight"] *= 1.5
		if opt["is_new"]:
			opt["_weight"] *= 1.2
