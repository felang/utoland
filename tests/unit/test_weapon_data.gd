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
	# 验证武器稀有度枚举值范围覆盖所有级别
	assert_true(Enums.WeaponRarity.COMMON >= 0, "COMMON 权重有效")
	assert_true(Enums.WeaponRarity.RARE > Enums.WeaponRarity.COMMON, "RARE 应大于 COMMON")
	assert_true(Enums.WeaponRarity.EPIC > Enums.WeaponRarity.RARE, "EPIC 应大于 RARE")

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
