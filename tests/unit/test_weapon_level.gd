extends GutTest

func test_weapon_data_has_level_fields():
	var wd: WeaponData = GameConfig.weapons["rifle"]
	assert_eq(wd.max_level, 5, "应有最大等级 5")
	assert_eq(wd.damage_per_level.size(), 5, "damage_per_level 应有 5 级")
	assert_eq(wd.fire_rate_per_level.size(), 5, "fire_rate_per_level 应有 5 级")
	assert_eq(wd.weapon_range_per_level.size(), 5, "weapon_range_per_level 应有 5 级")

func test_weapon_data_level_values_increase():
	var wd: WeaponData = GameConfig.weapons["rifle"]
	# 伤害应逐级递增
	for i in range(1, wd.damage_per_level.size()):
		assert_gt(wd.damage_per_level[i], wd.damage_per_level[i - 1],
			"Lv%d 伤害应大于 Lv%d" % [i + 1, i])

func test_weapon_get_damage_reads_level():
	var weapon := BulletWeapon.new()
	var wd: WeaponData = GameConfig.weapons["rifle"]
	weapon.initialize(wd)
	weapon.set_level(3)
	assert_almost_eq(weapon.get_damage(), wd.damage_per_level[2], 0.01,
		"Lv3 伤害应读 damage_per_level[2]")
	add_child_autofree(weapon)

func test_weapon_get_fire_rate_reads_level():
	var weapon := BulletWeapon.new()
	var wd: WeaponData = GameConfig.weapons["rifle"]
	weapon.initialize(wd)
	weapon.set_level(1)
	assert_almost_eq(weapon.get_fire_rate(), wd.fire_rate_per_level[0], 0.01,
		"Lv1 射速应读 fire_rate_per_level[0]")
	add_child_autofree(weapon)

func test_weapon_get_weapon_range_reads_level():
	var weapon := BulletWeapon.new()
	var wd: WeaponData = GameConfig.weapons["rifle"]
	weapon.initialize(wd)
	weapon.set_level(5)
	assert_almost_eq(weapon.get_weapon_range(), wd.weapon_range_per_level[4], 0.01,
		"Lv5 射程应读 weapon_range_per_level[4]")
	add_child_autofree(weapon)
