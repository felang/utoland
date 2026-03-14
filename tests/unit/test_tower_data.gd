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
	# 验证 get_rarity_weights 在中等等级时返回所有稀有度等级（使用整数键）
	var weights: Dictionary = UpgradeGenerator.get_rarity_weights(5)
	assert_true(weights.has(Enums.TowerRarity.COMMON), "缺少 COMMON 权重")
	assert_true(weights.has(Enums.TowerRarity.RARE), "缺少 RARE 权重")
	assert_true(weights.has(Enums.TowerRarity.EPIC), "缺少 EPIC 权重")
	# 验证权重递减（等级 5 时 1.0 > 0.8 > 0.3）
	assert_gt(
		weights[Enums.TowerRarity.COMMON],
		weights[Enums.TowerRarity.RARE],
		"COMMON 权重应大于 RARE"
	)
	assert_gt(
		weights[Enums.TowerRarity.RARE],
		weights[Enums.TowerRarity.EPIC],
		"RARE 权重应大于 EPIC"
	)

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
