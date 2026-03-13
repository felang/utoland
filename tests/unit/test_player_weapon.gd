extends GutTest

func test_all_weapons_have_range():
	for weapon_id in GameConfig.weapons:
		var w: WeaponData = GameConfig.weapons[weapon_id]
		assert_gt(w.weapon_range_per_level[0], 0.0, "武器 %s 应有正的射程" % weapon_id)

func test_all_weapons_have_projectile_type():
	for weapon_id in GameConfig.weapons:
		var w: WeaponData = GameConfig.weapons[weapon_id]
		assert_ne(w.projectile_type, "", "武器 %s 应有 projectile_type" % weapon_id)
