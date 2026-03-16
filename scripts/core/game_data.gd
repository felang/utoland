extends Node

# 角色系统
var current_character: String = Enums.Character.DORA
var character_max_hp: float = 0.0
var character_speed: float = 0.0
var character_damage_mult: float = 1.0
var character_attack_speed_mult: float = 1.0
## 新被动系统
var new_passive_id: String = ""
var new_passive_value: float = 0.0
var new_passive_value_2: float = 0.0

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

## 已上阵武器 [{id, level}]
var deployed_weapons: Array[Dictionary] = []

## 已布置塔 [{id, level, grid_pos}]
var deployed_towers: Array[Dictionary] = []

## 商店栏位 [{id, type, cost}] x4
var shop_slots: Array[Dictionary] = []

## 推荐武器/塔 ID（商店首次访问保证出现）
var _recommended_weapon: String = ""
var _recommended_tower: String = ""

## 是否首次访问商店
var is_first_shop_visit: bool = true

## 塔部署 ID 计数器（从 1 开始，0 表示失败）
var _next_deploy_id: int = 1

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
	# 新被动系统
	new_passive_id = char_data.new_passive_id
	new_passive_value = char_data.new_passive_value
	new_passive_value_2 = char_data.new_passive_value_2

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
	_next_deploy_id = 1
	# 初始武器：开局自动装备
	if char_data.starting_weapon != "":
		deployed_weapons.append({id = char_data.starting_weapon, level = 1})
	# # TODO: 临时 hardcode 三把武器用于测试，后续删除
	# deployed_weapons.append({id = "bow", level = 1})
	# deployed_weapons.append({id = "shuriken", level = 1})
	# deployed_weapons.append({id = "sword", level = 1})

# ===== 种群系统 =====

func get_population_cap() -> int:
	var config: ShopConfig = GameConfig.shop_config
	return config.population_per_level[player_level - 1]

func get_population_used() -> int:
	return deployed_weapons.size() + deployed_towers.size()

func can_deploy() -> bool:
	return get_population_used() < get_population_cap()

## 判断是否可以购买指定物品（考虑合成释放人口）
func can_buy_item(item_id: String, item_level: int) -> bool:
	if can_deploy():
		return true
	# 人口满，检查是否能触发合成（已有 ≥2 个同 id 同 level）
	var count: int = 0
	for w in deployed_weapons:
		if w.id == item_id and w.level == item_level:
			count += 1
	for t in deployed_towers:
		if t.id == item_id and t.level == item_level:
			count += 1
	return count >= 2

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

## 购买并直接装备武器
func buy_and_equip_weapon(weapon_id: String, cost: int) -> bool:
	if not can_deploy():
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

## 购买并直接布置塔
func buy_and_place_tower(tower_id: String, cost: int, grid_pos: Vector2i) -> int:
	if not can_deploy():
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

# ===== 出售 =====

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

# ===== 合成系统 =====

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
