extends Node

# 角色系统
var current_character: String = "warrior"  # 当前选择的角色
var character_max_hp: float = 0.0
var character_speed: float = 0.0
var character_damage_mult: float = 1.0
var character_attack_speed_mult: float = 1.0
var character_move_speed_mult: float = 1.0
var character_hp_regen: float = 0.0

var selected_weapon: String = "rifle"
var player_stats = {
	"max_hp": 100.0,
	"hp_regen": 0.0,
	"damage_mult": 1.0,
	"attack_speed_mult": 1.0,
	"move_speed_mult": 1.0,
	"tower_mult": 1.0
}
var coins: int = GameConfig.PLAYER["initial_coins"]
var current_wave: int = 0
var tower_inventory = []  # 已布置的塔 {type, position}
var purchased_towers = []  # 商店购买的塔类型（字符串数组）
var pending_heal: int = 0  # 待应用的治疗量

# 初始化角色属性
func init_character(character_id: String) -> void:
	if not GameConfig.CHARACTERS.has(character_id):
		push_error("未知角色: " + character_id)
		character_id = "warrior"  # 回退到默认角色

	current_character = character_id
	var char_data: Dictionary = GameConfig.CHARACTERS[character_id]

	character_max_hp = char_data["max_hp"]
	character_speed = char_data["speed"]
	character_damage_mult = char_data["damage_mult"]
	character_attack_speed_mult = char_data["attack_speed_mult"]
	character_move_speed_mult = char_data["move_speed_mult"]
	character_hp_regen = char_data["hp_regen"]

	print("角色初始化: ", char_data["name"], " (", character_id, ")")

func reset() -> void:
	# 初始化角色（使用当前选择的角色）
	init_character(current_character)

	selected_weapon = "rifle"
	player_stats = {
		"max_hp": 100.0,
		"hp_regen": 0.0,
		"damage_mult": 1.0,
		"attack_speed_mult": 1.0,
		"move_speed_mult": 1.0,
		"tower_mult": 1.0
	}
	coins = GameConfig.PLAYER["initial_coins"]
	current_wave = 0
	tower_inventory = []
	purchased_towers = []
	pending_heal = 0
