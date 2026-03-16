class_name ShopManager
extends RefCounted

## 商店管理器 — 负责商店刷新、物品购买

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
			GameData.shop_slots.append({
				id = item_id,
				type = _get_item_type(item_id),
				cost = config.item_cost,
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

## 购买武器（直接装备）
func buy_weapon(slot_index: int) -> bool:
	var slot: Dictionary = _validate_slot(slot_index)
	if slot.is_empty() or slot.type != "weapon":
		return false
	var success: bool = GameData.buy_and_equip_weapon(slot.id, slot.cost)
	if success:
		GameData.shop_slots[slot_index] = {}
	return success

## 获取塔购买信息（不扣款）
func get_tower_slot(slot_index: int) -> Dictionary:
	var slot: Dictionary = _validate_slot(slot_index)
	if slot.is_empty() or slot.type != "tower":
		return {}
	return slot

## 确认塔购买（放置成功后调用）
func confirm_tower_purchase(slot_index: int, grid_pos: Vector2i) -> int:
	var slot: Dictionary = _validate_slot(slot_index)
	if slot.is_empty():
		return 0
	var deploy_id: int = GameData.buy_and_place_tower(slot.id, slot.cost, grid_pos)
	if deploy_id > 0:
		GameData.shop_slots[slot_index] = {}
	return deploy_id

func _validate_slot(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= GameData.shop_slots.size():
		return {}
	var slot: Dictionary = GameData.shop_slots[slot_index]
	if slot.is_empty():
		return {}
	if GameData.coins < slot.cost:
		return {}
	if not GameData.can_deploy():
		return {}
	return slot

func _generate_random_slot() -> Dictionary:
	var config: ShopConfig = GameConfig.shop_config
	var pool: Array[String] = _get_all_items()
	if pool.is_empty():
		return {}
	var item_id: String = pool[randi() % pool.size()]
	return {
		id = item_id,
		type = _get_item_type(item_id),
		cost = config.item_cost,
	}

func _get_all_items() -> Array[String]:
	var pool: Array[String] = []
	for id: String in GameConfig.weapons:
		pool.append(id)
	for id: String in GameConfig.towers:
		pool.append(id)
	return pool

func _has_item(item_id: String) -> bool:
	return GameConfig.weapons.has(item_id) or GameConfig.towers.has(item_id)

func _get_item_type(item_id: String) -> String:
	if GameConfig.weapons.has(item_id):
		return "weapon"
	return "tower"
