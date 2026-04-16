extends GutTest

var _table: TierWeightTable = null

func before_each() -> void:
	_table = load("res://resources/shop/tier_weight_table.tres")

func test_level_1_returns_only_tier_1() -> void:
	var w: Array = _table.get_tier_weights(1)
	assert_eq(w[0], 1.0)
	assert_eq(w[1], 0.0)
	assert_eq(w[2], 0.0)
	assert_eq(w[3], 0.0)

func test_level_3_returns_t1_t2_mix() -> void:
	var w: Array = _table.get_tier_weights(3)
	assert_almost_eq(w[0], 0.75, 0.001)
	assert_almost_eq(w[1], 0.25, 0.001)

func test_level_10_returns_full_spread() -> void:
	var w: Array = _table.get_tier_weights(10)
	assert_almost_eq(w[3], 0.1, 0.001)

func test_level_above_max_uses_top_segment() -> void:
	var w: Array = _table.get_tier_weights(99)
	assert_almost_eq(w[3], 0.1, 0.001)
