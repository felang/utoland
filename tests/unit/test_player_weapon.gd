extends GutTest

func test_rifle_weapon_range():
	GameData.selected_weapon = "rifle"
	assert_eq(GameConfig.weapons["rifle"].weapon_range, 300.0, "步枪射程应为 300")

func test_boomerang_weapon_range():
	GameData.selected_weapon = "boomerang"
	assert_eq(GameConfig.weapons["boomerang"].weapon_range, 200.0, "回旋镖射程应为 200")

func test_laser_weapon_range():
	GameData.selected_weapon = "laser"
	assert_eq(GameConfig.weapons["laser"].weapon_range, 400.0, "激光枪射程应为 400")

func test_all_weapons_have_range():
	for weapon_id in GameConfig.weapons:
		var w: WeaponData = GameConfig.weapons[weapon_id]
		assert_gt(w.weapon_range, 0.0, "武器 %s 应有正的射程" % weapon_id)

func test_all_weapons_have_projectile_type():
	for weapon_id in GameConfig.weapons:
		var w: WeaponData = GameConfig.weapons[weapon_id]
		assert_ne(w.projectile_type, "", "武器 %s 应有 projectile_type" % weapon_id)
