extends Node

# 角色身份与属性状态

# 角色身份
var current_character: String = Enums.Character.DORA
var selected_map: String = Enums.Map.FOREST
var current_wave: int = 0
var pending_heal: int = 0

# 角色属性（从 CharacterData 初始化）
var character_max_hp: float = 0.0
var character_speed: float = 0.0
var character_damage_mult: float = 1.0
var character_attack_speed_mult: float = 1.0

# 被动系统
var new_passive_id: String = ""
var new_passive_value: float = 0.0
var new_passive_value_2: float = 0.0

# 运行时属性集
var player_stats: Dictionary = {
	Enums.Stat.MAX_HP: 100.0,
	Enums.Stat.HP_MULT: 1.0,
	Enums.Stat.DAMAGE_MULT: 1.0,
	Enums.Stat.ATTACK_SPEED_MULT: 1.0,
	Enums.Stat.TOWER_MULT: 1.0,
	# Perk bonus(战斗中累加,reset 重置)
	Enums.Stat.HP_BONUS_PERCENT: 0.0,
	Enums.Stat.MOVE_SPEED_BONUS_PERCENT: 0.0,
	Enums.Stat.DAMAGE_BONUS_PERCENT: 0.0,
	Enums.Stat.ATTACK_SPEED_BONUS_PERCENT: 0.0,
	Enums.Stat.PICKUP_RADIUS_BONUS_PERCENT: 0.0,
	Enums.Stat.COIN_DROP_BONUS_PERCENT: 0.0,
	Enums.Stat.EXP_GAIN_BONUS_PERCENT: 0.0,
	Enums.Stat.POPULATION_BONUS: 0,
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
	new_passive_id = char_data.new_passive_id
	new_passive_value = char_data.new_passive_value
	new_passive_value_2 = char_data.new_passive_value_2

func reset() -> void:
	init_character(current_character)
	selected_map = Enums.Map.FOREST
	current_wave = 0
	pending_heal = 0
	player_stats = {
		Enums.Stat.MAX_HP: character_max_hp,
		Enums.Stat.HP_MULT: 1.0,
		Enums.Stat.DAMAGE_MULT: character_damage_mult,
		Enums.Stat.ATTACK_SPEED_MULT: character_attack_speed_mult,
		Enums.Stat.TOWER_MULT: 1.0,
		Enums.Stat.HP_BONUS_PERCENT: 0.0,
		Enums.Stat.MOVE_SPEED_BONUS_PERCENT: 0.0,
		Enums.Stat.DAMAGE_BONUS_PERCENT: 0.0,
		Enums.Stat.ATTACK_SPEED_BONUS_PERCENT: 0.0,
		Enums.Stat.PICKUP_RADIUS_BONUS_PERCENT: 0.0,
		Enums.Stat.COIN_DROP_BONUS_PERCENT: 0.0,
		Enums.Stat.EXP_GAIN_BONUS_PERCENT: 0.0,
		Enums.Stat.POPULATION_BONUS: 0,
	}
