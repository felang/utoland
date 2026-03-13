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
