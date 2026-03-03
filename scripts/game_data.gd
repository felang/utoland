extends Node

var selected_weapon: String = "rifle"
var player_stats = {
	"max_hp": 100.0,
	"hp_regen": 0.0,
	"damage_mult": 1.0,
	"attack_speed_mult": 1.0,
	"move_speed_mult": 1.0,
	"tower_mult": 1.0
}
var coins: int = 50
var current_wave: int = 0
var tower_inventory = []  # 已布置的塔 {type, position}
var purchased_towers = []  # 商店购买的塔类型（字符串数组）
var pending_heal: int = 0  # 待应用的治疗量

func reset():
	selected_weapon = "rifle"
	player_stats = {
		"max_hp": 100.0,
		"hp_regen": 0.0,
		"damage_mult": 1.0,
		"attack_speed_mult": 1.0,
		"move_speed_mult": 1.0,
		"tower_mult": 1.0
	}
	coins = 50
	current_wave = 0
	tower_inventory = []
	purchased_towers = []
	pending_heal = 0
