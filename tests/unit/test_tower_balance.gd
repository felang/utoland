extends GutTest

# --- 所有塔均有 place_cost > 0（至少第一级）---
func test_all_towers_have_place_cost_level1_gt_zero() -> void:
	for tower_id in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		assert_gt(td.place_cost_per_level[0], 0,
			"%s 的 place_cost_per_level[0] 应大于 0" % tower_id)

func test_all_towers_have_place_cost_array_size_5() -> void:
	for tower_id in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		assert_eq(td.place_cost_per_level.size(), 5,
			"%s 的 place_cost_per_level 应有 5 个元素" % tower_id)

# --- Thorn ---
func test_thorn_place_cost_level1() -> void:
	var td: TowerData = GameConfig.towers[Enums.TowerId.THORN]
	assert_eq(td.place_cost_per_level[0], 12, "Thorn Lv1 place_cost 应为 12")

func test_thorn_place_cost_level5() -> void:
	var td: TowerData = GameConfig.towers[Enums.TowerId.THORN]
	assert_eq(td.place_cost_per_level[4], 40, "Thorn Lv5 place_cost 应为 40")

# --- Sunflower ---
func test_sunflower_place_cost_level1() -> void:
	var td: TowerData = GameConfig.towers[Enums.TowerId.SUNFLOWER]
	assert_eq(td.place_cost_per_level[0], 18, "Sunflower Lv1 place_cost 应为 18")

func test_sunflower_place_cost_level5() -> void:
	var td: TowerData = GameConfig.towers[Enums.TowerId.SUNFLOWER]
	assert_eq(td.place_cost_per_level[4], 55, "Sunflower Lv5 place_cost 应为 55")

func test_sunflower_hp_level1() -> void:
	var td: TowerData = GameConfig.towers[Enums.TowerId.SUNFLOWER]
	assert_almost_eq(td.hp_per_level[0], 70.0, 0.01, "Sunflower Lv1 HP 应为 70")

func test_sunflower_hp_level5() -> void:
	var td: TowerData = GameConfig.towers[Enums.TowerId.SUNFLOWER]
	assert_almost_eq(td.hp_per_level[4], 170.0, 0.01, "Sunflower Lv5 HP 应为 170")

# --- Mint ---
func test_mint_place_cost_level1() -> void:
	var td: TowerData = GameConfig.towers[Enums.TowerId.MINT]
	assert_eq(td.place_cost_per_level[0], 20, "Mint Lv1 place_cost 应为 20")

func test_mint_place_cost_level5() -> void:
	var td: TowerData = GameConfig.towers[Enums.TowerId.MINT]
	assert_eq(td.place_cost_per_level[4], 56, "Mint Lv5 place_cost 应为 56")

# --- Heal Flower ---
func test_heal_flower_place_cost_level1() -> void:
	var td: TowerData = GameConfig.towers[Enums.TowerId.HEAL_FLOWER]
	assert_eq(td.place_cost_per_level[0], 16, "HealFlower Lv1 place_cost 应为 16")

func test_heal_flower_place_cost_level5() -> void:
	var td: TowerData = GameConfig.towers[Enums.TowerId.HEAL_FLOWER]
	assert_eq(td.place_cost_per_level[4], 52, "HealFlower Lv5 place_cost 应为 52")

# --- Oak ---
func test_oak_place_cost_level1() -> void:
	var td: TowerData = GameConfig.towers[Enums.TowerId.OAK]
	assert_eq(td.place_cost_per_level[0], 22, "Oak Lv1 place_cost 应为 22")

func test_oak_place_cost_level5() -> void:
	var td: TowerData = GameConfig.towers[Enums.TowerId.OAK]
	assert_eq(td.place_cost_per_level[4], 58, "Oak Lv5 place_cost 应为 58")

# --- Bamboo ---
func test_bamboo_place_cost_level1() -> void:
	var td: TowerData = GameConfig.towers[Enums.TowerId.BAMBOO]
	assert_eq(td.place_cost_per_level[0], 20, "Bamboo Lv1 place_cost 应为 20")

func test_bamboo_place_cost_level5() -> void:
	var td: TowerData = GameConfig.towers[Enums.TowerId.BAMBOO]
	assert_eq(td.place_cost_per_level[4], 56, "Bamboo Lv5 place_cost 应为 56")

func test_bamboo_charge_time() -> void:
	var td: TowerData = GameConfig.towers[Enums.TowerId.BAMBOO]
	assert_almost_eq(td.charge_time, 12.0, 0.001, "Bamboo charge_time 应为 12.0")

# --- Dandelion ---
func test_dandelion_knockback_interval() -> void:
	var td: TowerData = GameConfig.towers[Enums.TowerId.DANDELION]
	assert_almost_eq(td.knockback_interval, 4.0, 0.001, "Dandelion knockback_interval 应为 4.0")
