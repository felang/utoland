extends GutTest

func before_each() -> void:
	PlayerState.current_character = Enums.Character.DORA
	PlayerState.reset()

# ===== init_character =====

func test_init_character_loads_dora_stats() -> void:
	PlayerState.init_character(Enums.Character.DORA)
	var char_data: CharacterData = GameConfig.characters[Enums.Character.DORA]
	assert_eq(PlayerState.current_character, Enums.Character.DORA)
	assert_eq(PlayerState.character_max_hp, char_data.max_hp)
	assert_eq(PlayerState.character_speed, char_data.speed)
	assert_eq(PlayerState.character_damage_mult, char_data.damage_mult)
	assert_eq(PlayerState.character_attack_speed_mult, char_data.attack_speed_mult)

func test_init_character_loads_passives() -> void:
	PlayerState.init_character(Enums.Character.DORA)
	var char_data: CharacterData = GameConfig.characters[Enums.Character.DORA]
	assert_eq(PlayerState.new_passive_id, char_data.new_passive_id)
	assert_eq(PlayerState.new_passive_value, char_data.new_passive_value)
	assert_eq(PlayerState.new_passive_value_2, char_data.new_passive_value_2)

func test_init_character_fallback_on_invalid_id() -> void:
	PlayerState.init_character("nonexistent_character")
	assert_eq(PlayerState.current_character, Enums.Character.DORA)
	assert_push_error("未知角色: nonexistent_character")

# ===== reset =====

func test_reset_restores_defaults() -> void:
	PlayerState.current_wave = 5
	PlayerState.pending_heal = 3
	PlayerState.selected_map = Enums.Map.DESERT
	PlayerState.reset()
	assert_eq(PlayerState.current_wave, 0)
	assert_eq(PlayerState.pending_heal, 0)
	assert_eq(PlayerState.selected_map, Enums.Map.FOREST)

func test_reset_rebuilds_player_stats_from_character() -> void:
	PlayerState.init_character(Enums.Character.DORA)
	PlayerState.player_stats[Enums.Stat.DAMAGE_MULT] = 999.0
	PlayerState.reset()
	var char_data: CharacterData = GameConfig.characters[Enums.Character.DORA]
	assert_eq(PlayerState.player_stats[Enums.Stat.MAX_HP], char_data.max_hp)
	assert_eq(PlayerState.player_stats[Enums.Stat.DAMAGE_MULT], char_data.damage_mult)
	assert_eq(PlayerState.player_stats[Enums.Stat.ATTACK_SPEED_MULT], char_data.attack_speed_mult)
	assert_eq(PlayerState.player_stats[Enums.Stat.HP_MULT], 1.0)
	assert_eq(PlayerState.player_stats[Enums.Stat.TOWER_MULT], 1.0)

func test_reset_preserves_current_character() -> void:
	# 切换角色后 reset 应保持该角色
	if GameConfig.characters.has(Enums.Character.KAZE):
		PlayerState.current_character = Enums.Character.KAZE
		PlayerState.reset()
		assert_eq(PlayerState.current_character, Enums.Character.KAZE)

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
