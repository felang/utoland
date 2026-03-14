class_name ShopManager
extends RefCounted

## 商店管理器 — 负责商店刷新、物品购买、稀有度权重池
##
## 由商店场景实例化（非 Autoload）。
## 直接读写 GameData 状态，通过 EventBus 发布事件。

func refresh_shop(is_first: bool = false) -> void:
	var config: ShopConfig = GameConfig.shop_config
	GameData.shop_slots = []
	var guaranteed_ids: Array[String] = []
	if is_first:
		if GameData._recommended_weapon != "" and _has_item(GameData._recommended_weapon):
			guaranteed_ids.append(GameData._recommended_weapon)
		if GameData._recommended_tower != "" and _has_item(GameData._recommended_tower):
			guaranteed_ids.append(GameData._recommended_tower)
	for i in config.slot_count:
		if i < guaranteed_ids.size():
			var item_id: String = guaranteed_ids[i]
			var item_data: Resource = _get_item_data(item_id)
			GameData.shop_slots.append({
				id = item_id,
				type = _get_item_type(item_id),
				rarity = item_data.rarity,
				cost = config.cost_by_rarity[item_data.rarity],
			})
		else:
			GameData.shop_slots.append(_generate_random_slot())

func manual_refresh() -> bool:
	var config: ShopConfig = GameConfig.shop_config
	if GameData.coins < config.refresh_cost:
		return false
	GameData.coins -= config.refresh_cost
	EventBus.coins_changed.emit(-config.refresh_cost, GameData.coins)
	refresh_shop()
	return true

func buy_item(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= GameData.shop_slots.size():
		return false
	var slot: Dictionary = GameData.shop_slots[slot_index]
	if slot.is_empty():
		return false
	if GameData.coins < slot.cost:
		return false
	if not GameData.can_buy():
		return false
	GameData.coins -= slot.cost
	var item := {id = slot.id, type = slot.type, level = 1}
	GameData.bag.append(item)
	GameData.shop_slots[slot_index] = {}
	EventBus.item_purchased.emit(item)
	EventBus.coins_changed.emit(-slot.cost, GameData.coins)
	# 触发合成检查
	GameData._check_merge(slot.id, 1)
	return true

func _generate_random_slot() -> Dictionary:
	var config: ShopConfig = GameConfig.shop_config
	var weights: PackedFloat32Array = config.rarity_weights[GameData.player_level - 1]
	var rarity: int = _weighted_random_rarity(weights)
	var pool: Array[String] = _get_pool_by_rarity(rarity)
	if pool.is_empty():
		return {}
	var item_id: String = pool[randi() % pool.size()]
	var item_data: Resource = _get_item_data(item_id)
	return {
		id = item_id,
		type = _get_item_type(item_id),
		rarity = rarity,
		cost = config.cost_by_rarity[rarity],
	}

func _weighted_random_rarity(weights: PackedFloat32Array) -> int:
	var total: float = 0.0
	for w in weights:
		total += w
	var roll: float = randf() * total
	var cumulative: float = 0.0
	for i in weights.size():
		cumulative += weights[i]
		if roll < cumulative:
			return i
	return 0

func _get_pool_by_rarity(rarity: int) -> Array[String]:
	var pool: Array[String] = []
	for id: String in GameConfig.weapons:
		if GameConfig.weapons[id].rarity == rarity:
			pool.append(id)
	for id: String in GameConfig.towers:
		if GameConfig.towers[id].rarity == rarity:
			pool.append(id)
	return pool

func _has_item(item_id: String) -> bool:
	return GameConfig.weapons.has(item_id) or GameConfig.towers.has(item_id)

func _get_item_data(item_id: String) -> Resource:
	if GameConfig.weapons.has(item_id):
		return GameConfig.weapons[item_id]
	if GameConfig.towers.has(item_id):
		return GameConfig.towers[item_id]
	push_error("未知物品 ID: " + item_id)
	return null

func _get_item_type(item_id: String) -> String:
	if GameConfig.weapons.has(item_id):
		return "weapon"
	return "tower"
