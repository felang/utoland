extends GutTest

var indicator: RangeIndicator

func before_each():
	indicator = load("res://scripts/ui/range_indicator.gd").new()
	add_child_autofree(indicator)

func test_initial_radius_is_zero():
	assert_eq(indicator.radius, 0.0)

func test_set_range_updates_radius():
	indicator.set_range(300.0)
	assert_eq(indicator.radius, 300.0)

func test_zero_radius_makes_node_invisible():
	indicator.set_range(0.0)
	assert_false(indicator.visible)

func test_positive_radius_makes_node_visible():
	indicator.set_range(300.0)
	assert_true(indicator.visible)

func test_hide_range_resets_to_zero():
	indicator.set_range(200.0)
	indicator.hide_range()
	assert_eq(indicator.radius, 0.0)
	assert_false(indicator.visible)
