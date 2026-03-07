extends GutTest

# 验证 GameConfig.weapons 包含正确的武器配置

func test_weapons_count():
	assert_eq(GameConfig.weapons.size(), 3, "应有 3 把武器")

func test_rifle_has_projectile_type():
	assert_eq(GameConfig.weapons[Enums.Weapon.RIFLE].projectile_type, Enums.Projectile.BULLET, "步枪弹道类型应为 bullet")

func test_boomerang_has_projectile_type():
	assert_eq(GameConfig.weapons[Enums.Weapon.BOOMERANG].projectile_type, Enums.Projectile.BOOMERANG, "回旋镖弹道类型应为 boomerang")

func test_laser_has_projectile_type():
	assert_eq(GameConfig.weapons[Enums.Weapon.LASER].projectile_type, Enums.Projectile.LASER, "激光枪弹道类型应为 laser")

func test_all_weapons_have_range():
	for weapon_id in GameConfig.weapons:
		var w: WeaponData = GameConfig.weapons[weapon_id]
		assert_gt(w.weapon_range, 0.0, "武器 %s 应有正的射程" % weapon_id)

func test_boomerang_has_required_fields():
	var w: WeaponData = GameConfig.weapons[Enums.Weapon.BOOMERANG]
	assert_gt(w.boomerang_speed, 0.0, "回旋镖应有 speed")
	assert_gt(w.outbound_distance, 0.0, "回旋镖应有 outbound_distance")
	assert_gt(w.return_speed_mult, 0.0, "回旋镖应有 return_speed_mult")

func test_laser_has_required_fields():
	var w: WeaponData = GameConfig.weapons[Enums.Weapon.LASER]
	assert_gt(w.beam_range, 0.0, "激光应有 beam_range")
	assert_gt(w.beam_width, 0.0, "激光应有 beam_width")
	assert_gt(w.beam_duration, 0.0, "激光应有 beam_duration")
