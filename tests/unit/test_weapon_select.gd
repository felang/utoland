extends GutTest

func test_all_weapons_in_config_are_selectable():
	for weapon_id in GameConfig.weapons:
		var w: WeaponData = GameConfig.weapons[weapon_id]
		assert_ne(w.display_name, "", "武器 %s 应有 display_name" % weapon_id)

