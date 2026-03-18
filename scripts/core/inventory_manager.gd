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

func can_buy_item(item_id: String, _item_level: int) -> bool:
	return can_deploy()

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
	if all_items.size() < 2:
		return
	var consumed: int = 0
	var item_type: String = ""
	var kept_tower_pos: Vector2i = Vector2i.ZERO
	var kept_tower_deploy_id: int = 0
	# 从 deployed_weapons 回收
	var i: int = deployed_weapons.size() - 1
	while i >= 0 and consumed < 2:
		if deployed_weapons[i].id == item_id and deployed_weapons[i].level == item_level:
			item_type = "weapon"
			deployed_weapons.remove_at(i)
			consumed += 1
		i -= 1
	# 从 deployed_towers 回收
	i = deployed_towers.size() - 1
	while i >= 0 and consumed < 2:
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

## 手动合成武器：保留 weapon_index 位置原地升级，移除配对武器
func merge_weapon(weapon_index: int) -> bool:
	if weapon_index < 0 or weapon_index >= deployed_weapons.size():
		return false
	var entry: Dictionary = deployed_weapons[weapon_index]
	var item_id: String = entry.id
	var item_level: int = entry.level
	if item_level >= 3:
		return false
	# 寻找另一个同 id 同 level 的武器
	var pair_index: int = -1
	for i in range(deployed_weapons.size()):
		if i != weapon_index and deployed_weapons[i].id == item_id and deployed_weapons[i].level == item_level:
			pair_index = i
			break
	if pair_index == -1:
		return false
	# 移除配对武器，保留 weapon_index 位置原地升级
	deployed_weapons.remove_at(pair_index)
	# pair_index 在前时，weapon_index 会偏移
	var actual_index: int = weapon_index if pair_index > weapon_index else weapon_index - 1
	deployed_weapons[actual_index].level = item_level + 1
	EventBus.item_merged.emit(item_id, item_level + 1)
	return true

## 手动合成塔：deploy_id 为被点击的塔，保留其 grid_pos 和 deploy_id，移除另一个配对塔
func merge_tower(deploy_id: int) -> bool:
	# 找到被点击的塔索引
	var clicked_index: int = -1
	for i in range(deployed_towers.size()):
		if deployed_towers[i].deploy_id == deploy_id:
			clicked_index = i
			break
	if clicked_index == -1:
		return false
	var entry: Dictionary = deployed_towers[clicked_index]
	var item_id: String = entry.id
	var item_level: int = entry.level
	if item_level >= 3:
		return false
	# 寻找另一个同 id 同 level 的塔
	var pair_index: int = -1
	for i in range(deployed_towers.size()):
		if i != clicked_index and deployed_towers[i].id == item_id and deployed_towers[i].level == item_level:
			pair_index = i
			break
	if pair_index == -1:
		return false
	# 移除配对塔，保留 clicked_index 位置升级（保留 grid_pos 和 deploy_id）
	deployed_towers.remove_at(pair_index)
	var actual_index: int = clicked_index if pair_index > clicked_index else clicked_index - 1
	deployed_towers[actual_index].level = item_level + 1
	EventBus.item_merged.emit(item_id, item_level + 1)
	return true

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
