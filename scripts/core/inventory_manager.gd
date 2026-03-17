extends Node

# 装备与经济管理（武器、塔、金币、商店栏位、合成）

var coins: int = GameConfig.PLAYER["initial_coins"]
var deployed_weapons: Array[Dictionary] = []
var deployed_towers: Array[Dictionary] = []
var shop_slots: Array[Dictionary] = []
var is_first_shop_visit: bool = true
var _recommended_weapon: String = ""
var _recommended_tower: String = ""
var _next_deploy_id: int = 1

func get_population_used() -> int:
	return deployed_weapons.size() + deployed_towers.size()

func can_deploy() -> bool:
	return get_population_used() < PlayerProgression.get_population_cap()

func can_buy_item(item_id: String, item_level: int) -> bool:
	if can_deploy():
		return true
	# 人口满，检查是否能触发合成（已有 >= 2 个同 id 同 level）
	var count: int = 0
	for w in deployed_weapons:
		if w.id == item_id and w.level == item_level:
			count += 1
	for t in deployed_towers:
		if t.id == item_id and t.level == item_level:
			count += 1
	return count >= 2

func buy_and_equip_weapon(weapon_id: String, cost: int) -> bool:
	if not can_buy_item(weapon_id, 1):
		return false
	if coins < cost:
		return false
	coins -= cost
	deployed_weapons.append({id = weapon_id, level = 1})
	var item := {id = weapon_id, type = "weapon", level = 1}
	EventBus.item_purchased.emit(item)
	EventBus.coins_changed.emit(-cost, coins)
	_check_merge(weapon_id, 1)
	return true

func buy_and_place_tower(tower_id: String, cost: int, grid_pos: Vector2i) -> int:
	if not can_buy_item(tower_id, 1):
		return 0
	if coins < cost:
		return 0
	coins -= cost
	var deploy_id: int = _next_deploy_id
	_next_deploy_id += 1
	deployed_towers.append({id = tower_id, level = 1, grid_pos = grid_pos, deploy_id = deploy_id})
	var item := {id = tower_id, type = "tower", level = 1}
	EventBus.item_purchased.emit(item)
	EventBus.coins_changed.emit(-cost, coins)
	_check_merge(tower_id, 1)
	return deploy_id

func move_tower(deploy_id: int, new_grid_pos: Vector2i) -> bool:
	if new_grid_pos.x < 0 or new_grid_pos.x >= GameConfig.MAP_GRID_WIDTH:
		return false
	if new_grid_pos.y < 0 or new_grid_pos.y >= GameConfig.MAP_GRID_HEIGHT:
		return false
	var tower_index := -1
	for i in range(deployed_towers.size()):
		if deployed_towers[i].deploy_id == deploy_id:
			tower_index = i
			break
	if tower_index == -1:
		return false
	for i in range(deployed_towers.size()):
		if i != tower_index and deployed_towers[i].grid_pos == new_grid_pos:
			return false
	var old_pos: Vector2i = deployed_towers[tower_index].grid_pos
	deployed_towers[tower_index].grid_pos = new_grid_pos
	EventBus.tower_moved.emit(deploy_id, old_pos, new_grid_pos)
	return true

func sell_from_deployed_weapon(deploy_index: int) -> int:
	if deploy_index < 0 or deploy_index >= deployed_weapons.size():
		return 0
	var entry: Dictionary = deployed_weapons[deploy_index]
	deployed_weapons.remove_at(deploy_index)
	var item := {id = entry.id, type = "weapon", level = entry.level}
	return _apply_sell(item)

func sell_from_deployed_tower(deploy_id: int) -> int:
	var tower_index := -1
	for i in range(deployed_towers.size()):
		if deployed_towers[i].deploy_id == deploy_id:
			tower_index = i
			break
	if tower_index == -1:
		return 0
	var entry: Dictionary = deployed_towers[tower_index]
	deployed_towers.remove_at(tower_index)
	var item := {id = entry.id, type = "tower", level = entry.level}
	return _apply_sell(item)

func _apply_sell(item: Dictionary) -> int:
	var data: Resource
	if item.type == "weapon":
		data = GameConfig.weapons[item.id]
	else:
		data = GameConfig.towers[item.id]
	var refund: int = data.sell_price_per_level[item.level - 1]
	coins += refund
	EventBus.item_sold.emit(item, refund)
	EventBus.coins_changed.emit(refund, coins)
	return refund

func _check_merge(item_id: String, item_level: int) -> void:
	if item_level >= 3:
		return
	var all_items: Array[Dictionary] = _collect_items_by_id_level(item_id, item_level)
	if all_items.size() < 3:
		return
	var consumed: int = 0
	var item_type: String = ""
	var kept_tower_pos: Vector2i = Vector2i.ZERO
	var kept_tower_deploy_id: int = 0
	# 从 deployed_weapons 回收
	var i: int = deployed_weapons.size() - 1
	while i >= 0 and consumed < 3:
		if deployed_weapons[i].id == item_id and deployed_weapons[i].level == item_level:
			item_type = "weapon"
			deployed_weapons.remove_at(i)
			consumed += 1
		i -= 1
	# 从 deployed_towers 回收
	i = deployed_towers.size() - 1
	while i >= 0 and consumed < 3:
		if deployed_towers[i].id == item_id and deployed_towers[i].level == item_level:
			item_type = "tower"
			if kept_tower_deploy_id == 0:
				kept_tower_pos = deployed_towers[i].grid_pos
				kept_tower_deploy_id = deployed_towers[i].deploy_id
			deployed_towers.remove_at(i)
			consumed += 1
		i -= 1
	# 合成品留在 deployed 中
	var new_level: int = item_level + 1
	if item_type == "weapon":
		deployed_weapons.append({id = item_id, level = new_level})
	elif item_type == "tower":
		deployed_towers.append({id = item_id, level = new_level, grid_pos = kept_tower_pos, deploy_id = kept_tower_deploy_id})
	EventBus.item_merged.emit(item_id, new_level)
	_check_merge(item_id, new_level)

func _collect_items_by_id_level(item_id: String, item_level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in deployed_weapons:
		if item.id == item_id and item.level == item_level:
			result.append(item)
	for item in deployed_towers:
		if item.id == item_id and item.level == item_level:
			result.append(item)
	return result

func reset() -> void:
	# 必须在 PlayerState.reset() 之后调用
	var char_data: CharacterData = GameConfig.characters[PlayerState.current_character]
	coins = GameConfig.PLAYER["initial_coins"] + char_data.starting_gold
	assert(coins >= 6, "初始金币必须 >= 6")
	deployed_weapons = []
	deployed_towers = []
	shop_slots = []
	is_first_shop_visit = true
	_recommended_weapon = char_data.recommended_weapon
	_recommended_tower = char_data.recommended_tower
	_next_deploy_id = 1
	if char_data.starting_weapon != "":
		deployed_weapons.append({id = char_data.starting_weapon, level = 1})
