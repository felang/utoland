extends GutTest

func test_items_are_loaded():
	assert_eq(GameConfig.items.size(), 25, "应加载25个物品")

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

func test_engineer_character_loaded():
	assert_true(GameConfig.characters.has("engineer"))
	var eng: CharacterData = GameConfig.characters["engineer"]
	assert_true(eng.affinity_tags.has("engineer"))

func test_warrior_has_affinity():
	var w: CharacterData = GameConfig.characters["warrior"]
	assert_true(w.affinity_tags.has("shooter"))

func test_ranger_has_strong_discount():
	var r: CharacterData = GameConfig.characters["ranger"]
	assert_eq(r.affinity_discount, 0.25)
