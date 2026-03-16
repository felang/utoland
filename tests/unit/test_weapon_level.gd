extends GutTest

func test_weapon_data_has_level_fields():
	var wd: WeaponData = GameConfig.weapons["bow"]
	assert_eq(wd.max_level, 3, "应有最大等级 3")
	assert_eq(wd.damage_per_level.size(), 3, "damage_per_level 应有 3 级")
	assert_eq(wd.fire_rate_per_level.size(), 3, "fire_rate_per_level 应有 3 级")
	assert_eq(wd.weapon_range_per_level.size(), 3, "weapon_range_per_level 应有 3 级")

func test_weapon_data_level_values_increase():
	var wd: WeaponData = GameConfig.weapons["bow"]
	# 伤害应逐级递增
	for i in range(1, wd.damage_per_level.size()):
		assert_gt(wd.damage_per_level[i], wd.damage_per_level[i - 1],
			"Lv%d 伤害应大于 Lv%d" % [i + 1, i])

func test_weapon_set_level_reads_correct_stats():
	var weapon := Weapon.new()
	var wd: WeaponData = GameConfig.weapons["bow"]
	add_child_autofree(weapon)
	weapon.initialize(wd)
	weapon.set_level(3)
	assert_almost_eq(weapon.attacker.base_damage, wd.damage_per_level[2], 0.01,
		"Lv3 伤害应读 damage_per_level[2]")

func test_weapon_attacker_cooldown_reads_level():
	var weapon := Weapon.new()
	var wd: WeaponData = GameConfig.weapons["bow"]
	add_child_autofree(weapon)
	weapon.initialize(wd)
	weapon.set_level(1)
	assert_almost_eq(weapon.attacker.base_cooldown, wd.fire_rate_per_level[0], 0.01,
		"Lv1 cooldown 应读 fire_rate_per_level[0]")

func test_weapon_attacker_range_reads_level():
	var weapon := Weapon.new()
	var wd: WeaponData = GameConfig.weapons["bow"]
	add_child_autofree(weapon)
	weapon.initialize(wd)
	weapon.set_level(3)
	assert_almost_eq(weapon.attacker.attack_range, wd.weapon_range_per_level[2], 0.01,
		"Lv3 射程应读 weapon_range_per_level[2]")
