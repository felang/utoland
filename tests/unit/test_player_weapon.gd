extends GutTest

func test_all_weapons_have_range():
	for weapon_id in GameConfig.weapons:
		var w: WeaponData = GameConfig.weapons[weapon_id]
		assert_gt(w.weapon_range_per_level[0], 0.0, "武器 %s 应有正的射程" % weapon_id)

func test_ranged_weapons_have_projectile_data():
	for weapon_id in GameConfig.weapons:
		var w: WeaponData = GameConfig.weapons[weapon_id]
		# 近战武器无投射物，跳过
		if w.attack_mode == 1:
			continue
		assert_not_null(w.projectile_data, "远程武器 %s 应有 projectile_data" % weapon_id)
