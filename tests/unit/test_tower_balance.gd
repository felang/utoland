extends GutTest

# --- 所有塔均有 sell_price > 0（至少第一级）---
func test_all_towers_have_sell_price_level1_gt_zero() -> void:
	for tower_id in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		assert_gt(td.sell_price_per_level[0], 0,
			"%s 的 sell_price_per_level[0] 应大于 0" % tower_id)

func test_all_towers_have_sell_price_array_size_3() -> void:
	for tower_id in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		assert_eq(td.sell_price_per_level.size(), 3,
			"%s 的 sell_price_per_level 应有 3 个元素" % tower_id)

func test_all_towers_have_max_level_3() -> void:
	for tower_id in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		assert_eq(td.max_level, 3,
			"%s 的 max_level 应为 3" % tower_id)
