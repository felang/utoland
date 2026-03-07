extends Node

# 角色系统
var current_character: String = Enums.Character.WARRIOR  # 当前选择的角色
var character_max_hp: float = 0.0
var character_speed: float = 0.0
var character_damage_mult: float = 1.0
var character_attack_speed_mult: float = 1.0
var character_move_speed_mult: float = 1.0
var character_hp_regen: float = 0.0

var selected_weapon: String = Enums.Weapon.RIFLE
var selected_map: String = Enums.Map.FOREST  # 当前选择的地图，默认森林
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
var purchased_towers: Array = []  # 商店购买的塔类型（字符串数组）
var pending_heal: int = 0  # 待应用的治疗量

func _ready() -> void:
	# 游戏启动时初始化默认角色
	init_character(current_character)

# 初始化角色属性
func init_character(character_id: String) -> void:
	if not GameConfig.characters.has(character_id):
		push_error("未知角色: " + character_id)
		character_id = Enums.Character.WARRIOR  # 回退到默认角色

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
	# 初始化角色（使用当前选择的角色）
	init_character(current_character)

	selected_weapon = Enums.Weapon.RIFLE
	selected_map = Enums.Map.FOREST
	# 将角色属性同步到 player_stats
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
	current_wave = 0
	tower_inventory = []
	purchased_towers = []
	pending_heal = 0
