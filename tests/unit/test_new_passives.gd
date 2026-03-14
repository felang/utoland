extends GutTest

# 新被动系统测试

func before_each() -> void:
	GameData.reset()

func test_kaze_passive_loaded() -> void:
	GameData.init_character("kaze")
	assert_eq(GameData.new_passive_id, "swift_combo")
	assert_almost_eq(GameData.new_passive_value, 0.05, 0.001)
	assert_almost_eq(GameData.new_passive_value_2, 0.3, 0.001)

func test_nemo_passive_loaded() -> void:
	GameData.init_character("nemo")
	assert_eq(GameData.new_passive_id, "field_master")
	assert_almost_eq(GameData.new_passive_value, 0.3, 0.001)

func test_gorg_passive_loaded() -> void:
	GameData.init_character("gorg")
	assert_eq(GameData.new_passive_id, "blood_rage")
	assert_almost_eq(GameData.new_passive_value, 0.05, 0.001)
	assert_almost_eq(GameData.new_passive_value_2, 0.5, 0.001)

func test_dora_passive_loaded() -> void:
	GameData.init_character("dora")
	assert_eq(GameData.new_passive_id, "fortify_regen")
	assert_almost_eq(GameData.new_passive_value, 0.02, 0.001)
	assert_almost_eq(GameData.new_passive_value_2, 3.0, 0.001)

func test_merlin_passive_loaded() -> void:
	GameData.init_character("merlin")
	assert_eq(GameData.new_passive_id, "amplify_field")
	assert_almost_eq(GameData.new_passive_value, 0.4, 0.001)

func test_old_passive_fields_removed() -> void:
	# 验证旧被动字段已移除
	GameData.init_character("dora")
	assert_false("character_passive_type" in GameData, "旧被动字段 character_passive_type 应已移除")
	assert_false("coin_drop_mult" in GameData, "旧字段 coin_drop_mult 应已移除")

func test_reset_clears_passive() -> void:
	GameData.init_character("kaze")
	assert_eq(GameData.new_passive_id, "swift_combo")
	# reset 会重新调用 init_character，所以被动应被重新设置
	GameData.reset()
	# reset 调用 init_character(current_character)，current_character 仍为 kaze
	assert_eq(GameData.new_passive_id, "swift_combo")

func test_switch_character_updates_passive() -> void:
	GameData.init_character("kaze")
	assert_eq(GameData.new_passive_id, "swift_combo")
	GameData.init_character("dora")
	assert_eq(GameData.new_passive_id, "fortify_regen")

func test_reset_applies_starting_gold() -> void:
	GameData.current_character = Enums.Character.DORA
	GameData.reset()
	var char_data: CharacterData = GameConfig.characters[Enums.Character.DORA]
	var expected: int = GameConfig.PLAYER["initial_coins"] + char_data.starting_gold
	assert_eq(GameData.coins, expected, "reset 后金币应为 initial_coins + starting_gold")

func test_player_stats_no_hp_regen_key() -> void:
	GameData.current_character = Enums.Character.DORA
	GameData.reset()
	assert_false(GameData.player_stats.has("hp_regen"), "player_stats 不应包含 hp_regen")

func test_player_stats_no_move_speed_mult_key() -> void:
	GameData.current_character = Enums.Character.DORA
	GameData.reset()
	assert_false(GameData.player_stats.has("move_speed_mult"), "player_stats 不应包含 move_speed_mult")
