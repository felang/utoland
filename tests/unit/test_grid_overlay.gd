extends GutTest

var overlay: Node2D

func before_each():
	overlay = load("res://scripts/ui/grid_overlay.gd").new()
	add_child_autofree(overlay)

func test_grid_overlay_is_node2d():
	assert_is(overlay, Node2D)

func test_grid_overlay_calculates_vertical_line_positions():
	var expected_v_count: int = GameConfig.MAP_COLS + 1  # 41
	var v_lines: Array = overlay.get_vertical_line_positions()
	assert_eq(v_lines.size(), expected_v_count, "竖线数量应为 MAP_COLS + 1")
	assert_eq(v_lines[0], -GameConfig.MAP_HALF_WIDTH, "第一条竖线在左边界")

func test_grid_overlay_calculates_horizontal_line_positions():
	var expected_h_count: int = GameConfig.MAP_ROWS + 1  # 31
	var h_lines: Array = overlay.get_horizontal_line_positions()
	assert_eq(h_lines.size(), expected_h_count, "横线数量应为 MAP_ROWS + 1")
	assert_eq(h_lines[0], -GameConfig.MAP_HALF_HEIGHT, "第一条横线在上边界")
