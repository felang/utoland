extends GutTest

func before_each() -> void:
	PlayerProgression.reset()

# ===== exp_for_level =====

func test_exp_for_level_formula() -> void:
	# 公式: floor(base_exp * level^exp_exponent)，使用当前角色的 ExpConfig
	var result: int = PlayerProgression.exp_for_level(2)
	var result3: int = PlayerProgression.exp_for_level(3)
	assert_gt(result, 0, "exp_for_level(2) 应大于 0")
	assert_gt(result3, result, "exp_for_level(3) 应大于 exp_for_level(2)")

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

