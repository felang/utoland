extends GutTest

# 验证 GameConfig.weapons 包含正确的武器配置

func test_weapons_count():
	assert_eq(GameConfig.weapons.size(), 3, "应有 3 把武器")

func test_bow_has_projectile_data():
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.BOW]
	assert_not_null(w.projectile_data, "弓应有 projectile_data")
	assert_eq(w.projectile_data.speed, 300.0, "弓弹道速度应为 300")

func test_shuriken_has_projectile_data():
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.SHURIKEN]
	assert_not_null(w.projectile_data, "手里剑应有 projectile_data")
	assert_eq(w.projectile_data.speed, 175.0, "手里剑弹道速度应为 175")

func test_all_weapons_have_range():
	for weapon_id in GameConfig.weapons:
		var w: WeaponData = GameConfig.weapons[weapon_id]
		assert_not_null(w.attack_config, "武器 %s 应有 attack_config" % weapon_id)
		assert_gt(w.attack_config.attack_range_per_level[0], 0.0, "武器 %s 应有正的射程" % weapon_id)

func test_shuriken_has_required_fields():
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.SHURIKEN]
	assert_not_null(w.projectile_data, "手里剑应有 projectile_data")
	assert_gt(w.projectile_data.speed, 0.0, "手里剑弹道应有 speed")
	assert_gt(w.projectile_data.lifetime, 0.0, "手里剑弹道应有 lifetime")

func test_bow_resource_loaded():
	assert_true(GameConfig.weapons.has(Enums.WeaponId.BOW), "应包含 bow")
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.BOW]
	assert_not_null(w.attack_config, "弓应有 attack_config")
	assert_not_null(w.projectile_data, "弓应有 projectile_data")

func test_sword_resource_loaded():
	assert_true(GameConfig.weapons.has(Enums.WeaponId.SWORD), "应包含 sword")
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.SWORD]
	assert_not_null(w.attack_config, "剑应有 attack_config")
	assert_not_null(w.melee_config, "剑应有 melee_config")

func test_ranged_weapons_have_projectile_data():
	for weapon_id in GameConfig.weapons:
		var w: WeaponData = GameConfig.weapons[weapon_id]
		if w.projectile_data != null:
			assert_not_null(w.projectile_data, "远程武器 %s 应有 projectile_data" % weapon_id)

func test_melee_weapons_have_melee_config():
	for weapon_id in GameConfig.weapons:
		var w: WeaponData = GameConfig.weapons[weapon_id]
		if w.melee_config != null:
			assert_not_null(w.melee_config, "近战武器 %s 应有 melee_config" % weapon_id)

func test_all_weapons_have_attack_config():
	for id in GameConfig.weapons:
		var w: WeaponData = GameConfig.weapons[id]
		assert_not_null(w.attack_config, id + " 应有 attack_config")
