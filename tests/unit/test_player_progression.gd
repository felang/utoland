extends GutTest

func before_each() -> void:
	PlayerProgression.reset()

# ===== exp_for_level =====

func test_exp_for_level_formula() -> void:
	# 公式: floor(base_exp * level^exp_exponent)
	var config: ExpConfig = GameConfig.exp_config
	var expected: int = int(floor(config.base_exp * pow(2, config.exp_exponent)))
	assert_eq(PlayerProgression.exp_for_level(2), expected)

func test_exp_for_level_increases_with_level() -> void:
	assert_true(PlayerProgression.exp_for_level(3) > PlayerProgression.exp_for_level(2))
	assert_true(PlayerProgression.exp_for_level(5) > PlayerProgression.exp_for_level(4))

# ===== add_exp =====

func test_add_exp_accumulates() -> void:
	PlayerProgression.add_exp(5)
	assert_eq(PlayerProgression.current_exp, 5)
	assert_eq(PlayerProgression.total_exp_earned, 5)
	PlayerProgression.add_exp(3)
	assert_eq(PlayerProgression.current_exp, 8)
	assert_eq(PlayerProgression.total_exp_earned, 8)

func test_add_exp_triggers_level_up() -> void:
	var threshold: int = PlayerProgression.exp_for_level(2)
	PlayerProgression.add_exp(threshold)
	assert_eq(PlayerProgression.player_level, 2)

func test_add_exp_multiple_level_ups() -> void:
	# 给足够多的经验一次升多级
	var huge_exp: int = PlayerProgression.exp_for_level(2) + PlayerProgression.exp_for_level(3) + PlayerProgression.exp_for_level(4)
	PlayerProgression.add_exp(huge_exp)
	assert_true(PlayerProgression.player_level >= 3)

# ===== get_population_cap =====

func test_population_cap_at_level_1() -> void:
	var config: ExpConfig = GameConfig.exp_config
	assert_eq(PlayerProgression.get_population_cap(), config.initial_population)

func test_population_cap_increases_with_level() -> void:
	var config: ExpConfig = GameConfig.exp_config
	var cap_at_1: int = PlayerProgression.get_population_cap()
	# 手动设置等级
	PlayerProgression.player_level = 3
	var cap_at_3: int = PlayerProgression.get_population_cap()
	assert_eq(cap_at_3, config.initial_population + 2 * config.population_per_level)
	assert_true(cap_at_3 > cap_at_1)

# ===== reset =====

func test_reset_restores_defaults() -> void:
	PlayerProgression.add_exp(100)
	PlayerProgression.player_level = 5
	PlayerProgression.reset()
	assert_eq(PlayerProgression.player_level, 1)
	assert_eq(PlayerProgression.current_exp, 0)
	assert_eq(PlayerProgression.total_exp_earned, 0)

# ===== Perk bonus 应用 =====

func test_exp_gain_bonus_multiplies_added_exp() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	PlayerState.player_stats[Enums.Stat.EXP_GAIN_BONUS_PERCENT] = 0.5  # +50%
	PlayerProgression.add_exp(10)
	assert_eq(PlayerProgression.current_exp, 15)

func test_population_bonus_added_to_cap() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	var base_cap: int = PlayerProgression.get_population_cap()
	PlayerState.player_stats[Enums.Stat.POPULATION_BONUS] = 3
	assert_eq(PlayerProgression.get_population_cap(), base_cap + 3)
