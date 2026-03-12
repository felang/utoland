extends GutTest

func test_items_are_loaded():
	assert_eq(GameConfig.items.size(), 37, "应加载37个物品")

func test_shooter_common_items_exist():
	assert_true(GameConfig.items.has("sharp_bullet"))
	assert_true(GameConfig.items.has("quick_hand"))
	assert_true(GameConfig.items.has("piercing_bullet"))

func test_engineer_rare_items_exist():
	assert_true(GameConfig.items.has("tower_link"))
	assert_true(GameConfig.items.has("overload"))

func test_epic_items_exist():
	assert_true(GameConfig.items.has("bullet_rain"))
	assert_true(GameConfig.items.has("arsenal"))
	assert_true(GameConfig.items.has("destiny"))

func test_dora_character_loaded():
	assert_true(GameConfig.characters.has("dora"))
	var c: CharacterData = GameConfig.characters["dora"]
	assert_true(c.affinity_tags.has("shooter"))

func test_all_new_characters_loaded():
	for char_id in ["dora", "gorg", "kaze", "merlin", "nemo"]:
		assert_true(GameConfig.characters.has(char_id), "应包含角色: " + char_id)
