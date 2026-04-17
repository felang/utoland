extends Node

# 经验与等级系统

var player_level: int = 1
var current_exp: int = 0
var total_exp_earned: int = 0

func exp_for_level(level: int) -> int:
	var config: ExpConfig = _get_exp_config()
	return int(floor(config.base_exp * pow(level, config.exp_exponent)))

func _get_exp_config() -> ExpConfig:
	var char_data: CharacterData = GameConfig.characters.get(PlayerState.current_character)
	if char_data and char_data.exp_config:
		return char_data.exp_config
	return GameConfig.exp_config

func add_exp(amount: int) -> void:
	var bonus: float = PlayerState.player_stats.get(Enums.Stat.EXP_GAIN_BONUS_PERCENT, 0.0)
	var actual: int = int(round(amount * (1.0 + bonus)))
	current_exp += actual
	total_exp_earned += actual
	while current_exp >= exp_for_level(player_level + 1):
		player_level += 1
		EventBus.player_level_changed.emit(player_level)
	var next_threshold: int = exp_for_level(player_level + 1)
	EventBus.exp_changed.emit(current_exp, next_threshold)

func reset() -> void:
	player_level = 1
	current_exp = 0
	total_exp_earned = 0
