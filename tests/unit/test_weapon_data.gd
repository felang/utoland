extends GutTest

func test_all_weapons_have_description() -> void:
	for weapon_id in GameConfig.weapons:
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		assert_ne(wd.description, "", "%s 缺少 description" % weapon_id)

func test_weapon_count() -> void:
	assert_eq(GameConfig.weapons.size(), 3, "应有 3 种武器")
