extends GutTest

# 验证 GameConfig.weapons 包含正确的武器配置

func test_weapons_count():
	assert_eq(GameConfig.weapons.size(), 3, "应有 3 把武器")

func test_bow_has_projectile_type():
	assert_eq(GameConfig.weapons[Enums.WeaponId.BOW].projectile_type, Enums.ProjectileId.BULLET, "弓弹道类型应为 bullet")

func test_shuriken_has_projectile_type():
	assert_eq(GameConfig.weapons[Enums.WeaponId.SHURIKEN].projectile_type, Enums.ProjectileId.SHURIKEN, "手里剑弹道类型应为 shuriken")

func test_all_weapons_have_range():
	for weapon_id in GameConfig.weapons:
		var w: WeaponData = GameConfig.weapons[weapon_id]
		assert_gt(w.weapon_range_per_level[0], 0.0, "武器 %s 应有正的射程" % weapon_id)

func test_shuriken_has_required_fields():
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.SHURIKEN]
	assert_gt(w.shuriken_speed, 0.0, "手里剑应有 speed")
	assert_gt(w.outbound_distance, 0.0, "手里剑应有 outbound_distance")
	assert_gt(w.return_speed_mult, 0.0, "手里剑应有 return_speed_mult")

func test_all_weapons_have_weapon_type():
	for id in GameConfig.weapons:
		var w: WeaponData = GameConfig.weapons[id]
		assert_ne(w.weapon_type, "", id + " 应有 weapon_type")

func test_bow_resource_loaded():
	assert_true(GameConfig.weapons.has(Enums.WeaponId.BOW), "应包含 bow")
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.BOW]
	assert_eq(w.weapon_type, "bow")
	assert_eq(w.projectile_type, Enums.ProjectileId.BULLET)
	assert_eq(w.bullet_count, 1, "弓应发射 1 颗子弹")

func test_sword_resource_loaded():
	assert_true(GameConfig.weapons.has(Enums.WeaponId.SWORD), "应包含 sword")
	var w: WeaponData = GameConfig.weapons[Enums.WeaponId.SWORD]
	assert_eq(w.weapon_type, "sword")
