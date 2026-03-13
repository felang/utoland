extends Node

# 角色系统
var current_character: String = Enums.Character.DORA
var character_max_hp: float = 0.0
var character_speed: float = 0.0
var character_damage_mult: float = 1.0
var character_attack_speed_mult: float = 1.0
var character_move_speed_mult: float = 1.0
var character_hp_regen: float = 0.0

var selected_map: String = Enums.Map.FOREST
var player_stats: Dictionary = {
	Enums.Stat.MAX_HP: 100.0,
	Enums.Stat.HP_MULT: 1.0,
	Enums.Stat.HP_REGEN: 0.0,
	Enums.Stat.DAMAGE_MULT: 1.0,
	Enums.Stat.ATTACK_SPEED_MULT: 1.0,
	Enums.Stat.MOVE_SPEED_MULT: 1.0,
	Enums.Stat.TOWER_MULT: 1.0
}
var coins: int = GameConfig.PLAYER["initial_coins"]
var current_wave: int = 0
var tower_inventory: Array = []  # 已布置的塔 {type, position}
var pending_heal: int = 0

## 武器/塔 拥有状态 {id: level}
var owned_weapons: Dictionary = {}
var owned_towers: Dictionary = {}

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
	"tower_inventory": [],
	"pending_heal": 0,
	"owned_weapons": {},
	"owned_towers": {},
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
	character_move_speed_mult = char_data.move_speed_mult
	character_hp_regen = char_data.hp_regen
	print("角色初始化: ", char_data.display_name, " (", character_id, ")")

func reset() -> void:
	init_character(current_character)
	var char_data: CharacterData = GameConfig.characters[current_character]
	selected_map = Enums.Map.FOREST
	player_stats = {
		Enums.Stat.MAX_HP: character_max_hp,
		Enums.Stat.HP_MULT: 1.0,
		Enums.Stat.HP_REGEN: character_hp_regen,
		Enums.Stat.DAMAGE_MULT: character_damage_mult,
		Enums.Stat.ATTACK_SPEED_MULT: character_attack_speed_mult,
		Enums.Stat.MOVE_SPEED_MULT: character_move_speed_mult,
		Enums.Stat.TOWER_MULT: 1.0
	}
	coins = GameConfig.PLAYER["initial_coins"]
	# 批量重置
	for key: String in _DEFAULTS:
		var val: Variant = _DEFAULTS[key]
		if val is Array or val is Dictionary:
			set(key, val.duplicate())
		else:
			set(key, val)
	# 从角色配置初始化拥有的武器和塔
	owned_weapons = {char_data.default_weapon: 1}
	owned_towers = {char_data.default_tower: 1}

func upgrade_weapon(weapon_id: String) -> void:
	var current_level: int = owned_weapons.get(weapon_id, 0)
	if current_level == 0:
		owned_weapons[weapon_id] = 1
	else:
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		if current_level < wd.max_level:
			owned_weapons[weapon_id] = current_level + 1

func upgrade_tower(tower_id: String) -> void:
	var current_level: int = owned_towers.get(tower_id, 0)
	if current_level == 0:
		owned_towers[tower_id] = 1
		EventBus.tower_purchased.emit(tower_id)
	else:
		var td: TowerData = GameConfig.towers[tower_id]
		if current_level < td.max_level:
			owned_towers[tower_id] = current_level + 1
			EventBus.tower_upgraded.emit(tower_id)

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
