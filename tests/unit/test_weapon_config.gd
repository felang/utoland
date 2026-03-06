extends GutTest

# 验证 GameConfig.WEAPONS 包含正确的武器配置

func test_weapons_has_rifle():
	assert_true(GameConfig.WEAPONS.has("rifle"), "应包含 rifle")

func test_weapons_has_boomerang():
	assert_true(GameConfig.WEAPONS.has("boomerang"), "应包含 boomerang")

func test_weapons_has_laser():
	assert_true(GameConfig.WEAPONS.has("laser"), "应包含 laser")

func test_weapons_no_shotgun():
	assert_false(GameConfig.WEAPONS.has("shotgun"), "不应包含 shotgun")

func test_weapons_no_sniper():
	assert_false(GameConfig.WEAPONS.has("sniper"), "不应包含 sniper")

func test_weapons_count():
	assert_eq(GameConfig.WEAPONS.size(), 3, "应有 3 把武器")

func test_rifle_has_projectile_type():
	assert_eq(GameConfig.WEAPONS["rifle"]["projectile_type"], "bullet", "步枪弹道类型应为 bullet")

func test_boomerang_has_projectile_type():
	assert_eq(GameConfig.WEAPONS["boomerang"]["projectile_type"], "boomerang", "回旋镖弹道类型应为 boomerang")

func test_laser_has_projectile_type():
	assert_eq(GameConfig.WEAPONS["laser"]["projectile_type"], "laser", "激光枪弹道类型应为 laser")

func test_boomerang_has_required_fields():
	var b: Dictionary = GameConfig.WEAPONS["boomerang"]
	assert_true(b.has("speed"), "回旋镖应有 speed")
	assert_true(b.has("outbound_distance"), "回旋镖应有 outbound_distance")
	assert_true(b.has("return_speed_mult"), "回旋镖应有 return_speed_mult")

func test_laser_has_required_fields():
	var l: Dictionary = GameConfig.WEAPONS["laser"]
	assert_true(l.has("beam_range"), "激光应有 beam_range")
	assert_true(l.has("beam_width"), "激光应有 beam_width")
	assert_true(l.has("beam_duration"), "激光应有 beam_duration")
