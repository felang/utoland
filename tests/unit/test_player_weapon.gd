extends GutTest

func test_rifle_weapon_range():
	GameData.selected_weapon = "rifle"
	var range_val: float = GameConfig.WEAPONS["rifle"]["range"]
	assert_eq(range_val, 300.0, "步枪射程应为 300")

func test_boomerang_weapon_range():
	GameData.selected_weapon = "boomerang"
	var range_val: float = GameConfig.WEAPONS["boomerang"]["range"]
	assert_eq(range_val, 200.0, "回旋镖射程应为 200")

func test_laser_weapon_range():
	GameData.selected_weapon = "laser"
	var range_val: float = GameConfig.WEAPONS["laser"]["range"]
	assert_eq(range_val, 400.0, "激光枪射程应为 400")

func test_all_weapons_have_range():
	for weapon_id in GameConfig.WEAPONS:
		assert_true(GameConfig.WEAPONS[weapon_id].has("range"),
			"武器 %s 应有 range 字段" % weapon_id)

func test_all_weapons_have_projectile_type():
	for weapon_id in GameConfig.WEAPONS:
		assert_true(GameConfig.WEAPONS[weapon_id].has("projectile_type"),
			"武器 %s 应有 projectile_type 字段" % weapon_id)
