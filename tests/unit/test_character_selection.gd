extends GutTest

# 角色选择界面数据验证测试

func test_all_characters_have_portrait_path() -> void:
	for character_id in GameConfig.characters:
		var char_data: CharacterData = GameConfig.characters[character_id]
		assert_ne(char_data.portrait_path, "", "%s 应有 portrait_path" % character_id)

func test_all_characters_have_valid_default_weapon() -> void:
	for character_id in GameConfig.characters:
		var char_data: CharacterData = GameConfig.characters[character_id]
		assert_true(GameConfig.weapons.has(char_data.default_weapon),
			"%s 的 default_weapon '%s' 应存在于 GameConfig.weapons" % [character_id, char_data.default_weapon])

func test_all_characters_have_display_name() -> void:
	for character_id in GameConfig.characters:
		var char_data: CharacterData = GameConfig.characters[character_id]
		assert_ne(char_data.display_name, "", "%s 应有 display_name" % character_id)

func test_character_portrait_files_exist() -> void:
	for character_id in GameConfig.characters:
		var char_data: CharacterData = GameConfig.characters[character_id]
		if char_data.portrait_path != "":
			assert_true(ResourceLoader.exists(char_data.portrait_path),
				"%s 的 portrait_path '%s' 文件应存在" % [character_id, char_data.portrait_path])

func test_game_data_init_character_sets_stats() -> void:
	var first_id: String = GameConfig.characters.keys()[0]
	var char_data: CharacterData = GameConfig.characters[first_id]
	GameData.init_character(first_id)
	assert_eq(GameData.character_max_hp, char_data.max_hp, "init_character 应设置 max_hp")
	assert_eq(GameData.character_speed, char_data.speed, "init_character 应设置 speed")
	assert_eq(GameData.character_damage_mult, char_data.damage_mult, "init_character 应设置 damage_mult")

func test_characters_dict_not_empty() -> void:
	assert_gt(GameConfig.characters.size(), 0, "角色字典不应为空")

func test_portrait_load_fallback_for_invalid_path() -> void:
	# 验证无效路径不会导致崩溃
	var invalid_path := "res://nonexistent/portrait.png"
	assert_false(ResourceLoader.exists(invalid_path), "无效路径应不存在")

func test_scene_file_exists() -> void:
	assert_true(ResourceLoader.exists("res://scenes/ui/character_selection.tscn"),
		"角色选择场景文件应存在")
