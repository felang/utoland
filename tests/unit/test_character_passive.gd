extends GutTest

func test_init_character_sets_passive_fields() -> void:
	GameData.init_character(Enums.Character.DORA)
	assert_eq(GameData.character_passive_type, "coin_bonus", "Dora 被动类型应为 coin_bonus")
	assert_almost_eq(GameData.character_passive_value, 0.2, 0.001, "Dora 被动值应为 0.2")

func test_coin_drop_mult_default() -> void:
	GameData.init_character(Enums.Character.DORA)
	assert_almost_eq(GameData.coin_drop_mult, 1.2, 0.001, "Dora coin_bonus 被动应使倍率为 1.2")

func test_reset_applies_starting_gold() -> void:
	GameData.current_character = Enums.Character.DORA
	GameData.reset()
	var char_data: CharacterData = GameConfig.characters[Enums.Character.DORA]
	var expected: int = GameConfig.PLAYER["initial_coins"] + char_data.starting_gold
	assert_eq(GameData.coins, expected, "reset 后金币应为 initial_coins + starting_gold")

func test_player_stats_no_hp_regen_key() -> void:
	GameData.current_character = Enums.Character.DORA
	GameData.reset()
	assert_false(GameData.player_stats.has("hp_regen"), "player_stats 不应再包含 hp_regen")

func test_player_stats_no_move_speed_mult_key() -> void:
	GameData.current_character = Enums.Character.DORA
	GameData.reset()
	assert_false(GameData.player_stats.has("move_speed_mult"), "player_stats 不应再包含 move_speed_mult")
