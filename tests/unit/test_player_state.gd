extends GutTest

func before_each() -> void:
	PlayerState.current_character = Enums.Character.RANGER
	PlayerState.reset()

# ===== init_character =====

func test_init_character_sets_stats() -> void:
	# 角色字典可能为空（ranger.tres 尚未创建），跳过
	if not GameConfig.characters.has(Enums.Character.RANGER):
		pass_test("ranger.tres 尚未创建，跳过")
		return
	PlayerState.init_character(Enums.Character.RANGER)
	var char_data: CharacterData = GameConfig.characters[Enums.Character.RANGER]
	assert_eq(PlayerState.current_character, Enums.Character.RANGER)
	assert_eq(PlayerState.character_max_hp, char_data.max_hp)
	assert_eq(PlayerState.character_speed, char_data.speed)

func test_init_character_fallback_on_invalid_id() -> void:
	PlayerState.init_character("nonexistent_character")
	assert_push_error("未知角色: nonexistent_character")

# ===== reset =====

func test_reset_restores_defaults() -> void:
	PlayerState.current_wave = 5
	PlayerState.selected_map = Enums.Map.DESERT
	PlayerState.reset()
	assert_eq(PlayerState.current_wave, 0)
	assert_eq(PlayerState.selected_map, Enums.Map.FOREST)

func test_reset_rebuilds_player_stats() -> void:
	PlayerState.reset()
	assert_true(PlayerState.player_stats.has(Enums.Stat.MAX_HP))
	assert_eq(PlayerState.player_stats[Enums.Stat.TOWER_MULT], 1.0)

# ===== Perk bonus 字段 =====

func test_player_stats_has_perk_bonus_keys() -> void:
	PlayerState.reset()
	assert_true(PlayerState.player_stats.has(Enums.Stat.HP_BONUS_PERCENT))
	assert_true(PlayerState.player_stats.has(Enums.Stat.MOVE_SPEED_BONUS_PERCENT))
	assert_true(PlayerState.player_stats.has(Enums.Stat.DAMAGE_BONUS_PERCENT))
	assert_true(PlayerState.player_stats.has(Enums.Stat.ATTACK_SPEED_BONUS_PERCENT))
	assert_true(PlayerState.player_stats.has(Enums.Stat.PICKUP_RADIUS_BONUS_PERCENT))
	assert_true(PlayerState.player_stats.has(Enums.Stat.COIN_DROP_BONUS_PERCENT))
	assert_true(PlayerState.player_stats.has(Enums.Stat.EXP_GAIN_BONUS_PERCENT))
	assert_true(PlayerState.player_stats.has(Enums.Stat.POPULATION_BONUS))

func test_perk_bonus_initialized_to_zero() -> void:
	PlayerState.reset()
	assert_eq(PlayerState.player_stats[Enums.Stat.HP_BONUS_PERCENT], 0.0)
	assert_eq(PlayerState.player_stats[Enums.Stat.POPULATION_BONUS], 0)

func test_perk_bonus_reset_clears_accumulated() -> void:
	PlayerState.reset()
	PlayerState.player_stats[Enums.Stat.HP_BONUS_PERCENT] = 0.5
	PlayerState.player_stats[Enums.Stat.POPULATION_BONUS] = 3
	PlayerState.reset()
	assert_eq(PlayerState.player_stats[Enums.Stat.HP_BONUS_PERCENT], 0.0)
	assert_eq(PlayerState.player_stats[Enums.Stat.POPULATION_BONUS], 0)
