extends Node

# 角色系统
var current_character: String = Enums.Character.DORA
var character_max_hp: float = 0.0
var character_speed: float = 0.0
var character_damage_mult: float = 1.0
var character_attack_speed_mult: float = 1.0
var character_passive_type: String = ""
var character_passive_value: float = 0.0
var coin_drop_mult: float = 1.0

var selected_map: String = Enums.Map.FOREST
var player_stats: Dictionary = {
	Enums.Stat.MAX_HP: 100.0,
	Enums.Stat.HP_MULT: 1.0,
	Enums.Stat.DAMAGE_MULT: 1.0,
	Enums.Stat.ATTACK_SPEED_MULT: 1.0,
	Enums.Stat.TOWER_MULT: 1.0
}
var coins: int = GameConfig.PLAYER["initial_coins"]
var current_wave: int = 0
var pending_heal: int = 0

## 种群等级（商店升级购买）
var player_level: int = 1

## 背包 [{id, type, level}]，最多 bag_capacity 个
var bag: Array[Dictionary] = []

## 已上阵武器 [{id, level}]
var deployed_weapons: Array[Dictionary] = []

## 已布置塔 [{id, level, grid_pos}]
var deployed_towers: Array[Dictionary] = []

## 商店栏位 [{id, type, rarity, cost}] x4
var shop_slots: Array[Dictionary] = []

## 推荐武器/塔 ID（商店首次访问保证出现）
var _recommended_weapon: String = ""
var _recommended_tower: String = ""

## 是否首次访问商店
var is_first_shop_visit: bool = true

## 里程碑效果保留字段（初期不使用，后续 milestones 写入）
var pierce_count: int = 0
var multishot_active: bool = false
var multishot_damage_mult: float = 1.0
var split_count: int = 0
var split_damage_mult: float = 0.5
var bullet_speed_mult: float = 1.0
var weapon_range_mult: float = 1.0
var crit_chance: float = 0.0
var crit_damage_mult: float = 2.0

## ===== 本局统计 =====
var total_kills: int = 0
var total_coins_earned: int = 0
var total_damage_taken: float = 0.0
var max_kill_streak: int = 0
var current_kill_streak: int = 0

const _DEFAULTS: Dictionary = {
	"current_wave": 0,
	"pending_heal": 0,
	"player_level": 1,
	"bag": [],
	"deployed_weapons": [],
	"deployed_towers": [],
	"shop_slots": [],
	"is_first_shop_visit": true,
	"pierce_count": 0,
	"multishot_active": false,
	"multishot_damage_mult": 1.0,
	"split_count": 0,
	"split_damage_mult": 0.5,
	"bullet_speed_mult": 1.0,
	"weapon_range_mult": 1.0,
	"crit_chance": 0.0,
	"crit_damage_mult": 2.0,
	"total_kills": 0,
	"total_coins_earned": 0,
	"total_damage_taken": 0.0,
	"max_kill_streak": 0,
	"current_kill_streak": 0,
}

func _ready() -> void:
	init_character(current_character)

func init_character(character_id: String) -> void:
	if not GameConfig.characters.has(character_id):
		push_error("未知角色: " + character_id)
		character_id = Enums.Character.DORA
	current_character = character_id
	var char_data: CharacterData = GameConfig.characters[character_id]
	character_max_hp = char_data.max_hp
	character_speed = char_data.speed
	character_damage_mult = char_data.damage_mult
	character_attack_speed_mult = char_data.attack_speed_mult
	character_passive_type = char_data.passive_type
	character_passive_value = char_data.passive_value
	# 金币掉落倍率（coin_bonus 被动）
	if character_passive_type == Enums.PassiveType.COIN_BONUS:
		coin_drop_mult = 1.0 + character_passive_value
	else:
		coin_drop_mult = 1.0

func reset() -> void:
	init_character(current_character)
	var char_data: CharacterData = GameConfig.characters[current_character]
	selected_map = Enums.Map.FOREST
	player_stats = {
		Enums.Stat.MAX_HP: character_max_hp,
		Enums.Stat.HP_MULT: 1.0,
		Enums.Stat.DAMAGE_MULT: character_damage_mult,
		Enums.Stat.ATTACK_SPEED_MULT: character_attack_speed_mult,
		Enums.Stat.TOWER_MULT: 1.0
	}
	coins = GameConfig.PLAYER["initial_coins"] + char_data.starting_gold
	assert(coins >= 6, "初始金币必须 >= 6")
	# 批量重置
	for key: String in _DEFAULTS:
		var val: Variant = _DEFAULTS[key]
		if val is Array or val is Dictionary:
			set(key, val.duplicate())
		else:
			set(key, val)
	# 从角色配置初始化推荐武器/塔
	_recommended_weapon = char_data.recommended_weapon
	_recommended_tower = char_data.recommended_tower

# ===== 种群系统 =====

func get_population_cap() -> int:
	var config: ShopConfig = GameConfig.shop_config
	return config.population_per_level[player_level - 1]

func get_population_used() -> int:
	return deployed_weapons.size() + deployed_towers.size()

func get_bag_count() -> int:
	return bag.size()

func can_deploy() -> bool:
	return get_population_used() < get_population_cap()

func can_buy() -> bool:
	var config: ShopConfig = GameConfig.shop_config
	return bag.size() < config.bag_capacity

# ===== 等级升级 =====

func buy_level_up() -> bool:
	var config: ShopConfig = GameConfig.shop_config
	if player_level >= config.population_per_level.size():
		return false
	var cost: int = config.level_up_costs[player_level - 1]
	if coins < cost:
		return false
	coins -= cost
	player_level += 1
	EventBus.player_level_changed.emit(player_level)
	EventBus.coins_changed.emit(-cost, coins)
	return true

# ===== 部署/撤回 =====

func deploy_weapon(bag_index: int) -> bool:
	if not can_deploy():
		return false
	if bag_index < 0 or bag_index >= bag.size():
		return false
	var item: Dictionary = bag[bag_index]
	if item.type != "weapon":
		return false
	bag.remove_at(bag_index)
	deployed_weapons.append({id = item.id, level = item.level})
	EventBus.item_deployed.emit(item)
	return true

func undeploy_weapon(deploy_index: int) -> void:
	if deploy_index < 0 or deploy_index >= deployed_weapons.size():
		return
	var item: Dictionary = deployed_weapons[deploy_index]
	deployed_weapons.remove_at(deploy_index)
	bag.append({id = item.id, type = "weapon", level = item.level})
	EventBus.item_undeployed.emit(item)

func deploy_tower(bag_index: int, grid_pos: Vector2i) -> bool:
	if not can_deploy():
		return false
	if bag_index < 0 or bag_index >= bag.size():
		return false
	var item: Dictionary = bag[bag_index]
	if item.type != "tower":
		return false
	bag.remove_at(bag_index)
	deployed_towers.append({id = item.id, level = item.level, grid_pos = grid_pos})
	EventBus.item_deployed.emit(item)
	return true

func undeploy_tower(deploy_index: int) -> void:
	if deploy_index < 0 or deploy_index >= deployed_towers.size():
		return
	var item: Dictionary = deployed_towers[deploy_index]
	deployed_towers.remove_at(deploy_index)
	bag.append({id = item.id, type = "tower", level = item.level})
	EventBus.item_undeployed.emit(item)

# ===== 出售 =====

func sell_from_bag(bag_index: int) -> int:
	if bag_index < 0 or bag_index >= bag.size():
		return 0
	var item: Dictionary = bag[bag_index]
	bag.remove_at(bag_index)
	return _apply_sell(item)

func sell_from_deployed_weapon(deploy_index: int) -> int:
	if deploy_index < 0 or deploy_index >= deployed_weapons.size():
		return 0
	var entry: Dictionary = deployed_weapons[deploy_index]
	deployed_weapons.remove_at(deploy_index)
	var item := {id = entry.id, type = "weapon", level = entry.level}
	return _apply_sell(item)

func sell_from_deployed_tower(deploy_index: int) -> int:
	if deploy_index < 0 or deploy_index >= deployed_towers.size():
		return 0
	var entry: Dictionary = deployed_towers[deploy_index]
	deployed_towers.remove_at(deploy_index)
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

# ===== 合成系统 =====

func _check_merge(item_id: String, item_level: int) -> void:
	if item_level >= 3:
		return
	var all_items: Array[Dictionary] = _collect_items_by_id_level(item_id, item_level)
	if all_items.size() < 3:
		return
	# 回收 3 个物品（优先从 bag 取，再从 deployed 取）
	var consumed: int = 0
	var item_type: String = ""
	# 从 bag 回收
	var i: int = bag.size() - 1
	while i >= 0 and consumed < 3:
		if bag[i].id == item_id and bag[i].level == item_level:
			item_type = bag[i].type
			bag.remove_at(i)
			consumed += 1
		i -= 1
	# 从 deployed_weapons 回收
	i = deployed_weapons.size() - 1
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
			deployed_towers.remove_at(i)
			consumed += 1
		i -= 1
	# 生成合成品
	var new_level: int = item_level + 1
	bag.append({id = item_id, type = item_type, level = new_level})
	EventBus.item_merged.emit(item_id, new_level)
	# 递归检查
	_check_merge(item_id, new_level)

func _collect_items_by_id_level(item_id: String, item_level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in bag:
		if item.id == item_id and item.level == item_level:
			result.append(item)
	for item in deployed_weapons:
		if item.id == item_id and item.level == item_level:
			result.append(item)
	for item in deployed_towers:
		if item.id == item_id and item.level == item_level:
			result.append(item)
	return result

# ===== 统计 =====

func record_kill() -> void:
	total_kills += 1
	current_kill_streak += 1
	if current_kill_streak > max_kill_streak:
		max_kill_streak = current_kill_streak

func reset_kill_streak() -> void:
	current_kill_streak = 0

func record_damage_taken(amount: float) -> void:
	total_damage_taken += amount

func record_coins_earned(amount: int) -> void:
	total_coins_earned += amount
