extends GutTest

func test_all_weapons_have_valid_rarity() -> void:
	for weapon_id in GameConfig.weapons:
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		assert_true(
			wd.rarity >= Enums.WeaponRarity.COMMON and wd.rarity <= Enums.WeaponRarity.EPIC,
			"%s rarity %d 不在有效范围 [0, 2]" % [weapon_id, wd.rarity]
		)

func test_all_weapons_have_description() -> void:
	for weapon_id in GameConfig.weapons:
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		assert_ne(wd.description, "", "%s 缺少 description" % weapon_id)

func test_rarity_weight_mapping() -> void:
	# 验证 RARITY_WEIGHTS 常量包含所有稀有度等级
	assert_true(UpgradeGenerator.RARITY_WEIGHTS.has(Enums.WeaponRarity.COMMON), "缺少 COMMON 权重")
	assert_true(UpgradeGenerator.RARITY_WEIGHTS.has(Enums.WeaponRarity.RARE), "缺少 RARE 权重")
	assert_true(UpgradeGenerator.RARITY_WEIGHTS.has(Enums.WeaponRarity.EPIC), "缺少 EPIC 权重")
	# 验证权重递减
	assert_gt(
		UpgradeGenerator.RARITY_WEIGHTS[Enums.WeaponRarity.COMMON],
		UpgradeGenerator.RARITY_WEIGHTS[Enums.WeaponRarity.RARE],
		"COMMON 权重应大于 RARE"
	)
	assert_gt(
		UpgradeGenerator.RARITY_WEIGHTS[Enums.WeaponRarity.RARE],
		UpgradeGenerator.RARITY_WEIGHTS[Enums.WeaponRarity.EPIC],
		"RARE 权重应大于 EPIC"
	)

func test_common_weapons_count() -> void:
	var count: int = 0
	for weapon_id in GameConfig.weapons:
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		if wd.rarity == Enums.WeaponRarity.COMMON:
			count += 1
	assert_eq(count, 4, "应有 4 把普通武器")

func test_rare_weapons_count() -> void:
	var count: int = 0
	for weapon_id in GameConfig.weapons:
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		if wd.rarity == Enums.WeaponRarity.RARE:
			count += 1
	assert_eq(count, 4, "应有 4 把稀有武器")

func test_epic_weapons_count() -> void:
	var count: int = 0
	for weapon_id in GameConfig.weapons:
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		if wd.rarity == Enums.WeaponRarity.EPIC:
			count += 1
	assert_eq(count, 2, "应有 2 把史诗武器")
