extends GutTest

func test_tower_rarity_enum_values() -> void:
	assert_eq(Enums.TowerRarity.COMMON, 0, "COMMON should be 0")
	assert_eq(Enums.TowerRarity.RARE, 1, "RARE should be 1")
	assert_eq(Enums.TowerRarity.EPIC, 2, "EPIC should be 2")

func test_all_towers_have_valid_rarity() -> void:
	for tower_id in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		assert_true(
			td.rarity >= Enums.TowerRarity.COMMON and td.rarity <= Enums.TowerRarity.EPIC,
			"%s rarity %d 不在有效范围 [0, 2]" % [tower_id, td.rarity]
		)

func test_all_towers_have_description() -> void:
	for tower_id in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		assert_ne(td.description, "", "%s 缺少 description" % tower_id)

func test_tower_rarity_weight_mapping() -> void:
	# 验证稀有度枚举值范围覆盖所有级别
	assert_true(Enums.TowerRarity.COMMON >= 0, "COMMON 权重有效")
	assert_true(Enums.TowerRarity.RARE > Enums.TowerRarity.COMMON, "RARE 应大于 COMMON")
	assert_true(Enums.TowerRarity.EPIC > Enums.TowerRarity.RARE, "EPIC 应大于 RARE")

func test_common_towers_count() -> void:
	var count: int = 0
	for tower_id in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		if td.rarity == Enums.TowerRarity.COMMON:
			count += 1
	assert_eq(count, 6, "应有 6 个普通塔")

func test_rare_towers_count() -> void:
	var count: int = 0
	for tower_id in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		if td.rarity == Enums.TowerRarity.RARE:
			count += 1
	assert_eq(count, 5, "应有 5 个稀有塔")

func test_epic_towers_count() -> void:
	var count: int = 0
	for tower_id in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		if td.rarity == Enums.TowerRarity.EPIC:
			count += 1
	assert_eq(count, 4, "应有 4 个史诗塔")
