extends GutTest

func test_all_weapons_in_config_are_selectable():
	for weapon_id in GameConfig.WEAPONS:
		assert_true(GameConfig.WEAPONS[weapon_id].has("name"),
			"武器 %s 应有 name 字段" % weapon_id)

func test_weapon_count_matches_config():
	assert_eq(GameConfig.WEAPONS.size(), 3, "应有 3 把武器可选")
