extends GutTest

# 验证 GameConfig.weapons 包含正确的武器配置

func test_weapons_count():
	assert_eq(GameConfig.weapons.size(), 6, "应有 6 把武器")

func test_rifle_has_projectile_type():
	assert_eq(GameConfig.weapons[Enums.WeaponId.RIFLE].projectile_type, Enums.ProjectileId.BULLET, "步枪弹道类型应为 bullet")

func test_boomerang_has_projectile_type():
	assert_eq(GameConfig.weapons[Enums.WeaponId.BOOMERANG].projectile_type, Enums.ProjectileId.BOOMERANG, "回旋镖弹道类型应为 boomerang")

func test_laser_has_projectile_type():
	assert_eq(GameConfig.weapons[Enums.WeaponId.LASER].projectile_type, Enums.ProjectileId.LASER, "激光枪弹道类型应为 laser")

func test_all_weapons_have_range():
	for weapon_id in GameConfig.weapons:
		var w: WeaponData = GameConfig.weapons[weapon_id]
		assert_gt(w.weapon_range_per_level[0], 0.0, "武器 %s 应有正的射程" % weapon_id)

func test_boomerang_has_required_fields():
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.BOOMERANG]
	assert_gt(w.boomerang_speed, 0.0, "回旋镖应有 speed")
	assert_gt(w.outbound_distance, 0.0, "回旋镖应有 outbound_distance")
	assert_gt(w.return_speed_mult, 0.0, "回旋镖应有 return_speed_mult")

func test_laser_has_required_fields():
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.LASER]
	assert_gt(w.beam_range, 0.0, "激光应有 beam_range")
	assert_gt(w.beam_width, 0.0, "激光应有 beam_width")
	assert_gt(w.beam_duration, 0.0, "激光应有 beam_duration")

func test_all_weapons_have_weapon_type():
	for id in GameConfig.weapons:
		var w: WeaponData = GameConfig.weapons[id]
		assert_ne(w.weapon_type, "", id + " 应有 weapon_type")

func test_shotgun_resource_loaded():
	assert_true(GameConfig.weapons.has(Enums.WeaponId.SHOTGUN), "应包含 shotgun")
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.SHOTGUN]
	assert_eq(w.weapon_type, "shotgun")
	assert_eq(w.projectile_type, Enums.ProjectileId.BULLET)
	assert_gt(w.bullet_count, 1, "霰弹枪应发射多颗子弹")

func test_minigun_resource_loaded():
	assert_true(GameConfig.weapons.has(Enums.WeaponId.MINIGUN))
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.MINIGUN]
	assert_eq(w.weapon_type, "minigun")
	assert_lt(w.fire_rate_per_level[0], 0.1, "加特林射速应极快")

func test_ice_gun_resource_loaded():
	assert_true(GameConfig.weapons.has(Enums.WeaponId.ICE_GUN))
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.ICE_GUN]
	assert_eq(w.weapon_type, "ice_gun")
	assert_gt(w.slow_on_hit, 0.0, "冰冻枪应有 slow_on_hit")
