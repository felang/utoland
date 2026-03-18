extends Node

# 经验与等级系统

var player_level: int = 1
var current_exp: int = 0
var total_exp_earned: int = 0

func exp_for_level(level: int) -> int:
	var config: ExpConfig = GameConfig.exp_config
	return int(floor(config.base_exp * pow(level, config.exp_exponent)))

func add_exp(amount: int) -> void:
	current_exp += amount
	total_exp_earned += amount
	while current_exp >= exp_for_level(player_level + 1):
		player_level += 1
		EventBus.player_level_changed.emit(player_level)
	var next_threshold: int = exp_for_level(player_level + 1)
	EventBus.exp_changed.emit(current_exp, next_threshold)

func get_population_cap() -> int:
	var config: ExpConfig = GameConfig.exp_config
	return config.initial_population + (player_level - 1) * config.population_per_level

func buy_level_up() -> void:
	player_level += 1
	EventBus.player_level_changed.emit(player_level)

func reset() -> void:
	player_level = 1
	current_exp = 0
	total_exp_earned = 0
