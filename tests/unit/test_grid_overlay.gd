extends GutTest

var overlay: GridOverlay

func before_each():
	overlay = load("res://scripts/ui/grid_overlay.gd").new()
	add_child_autofree(overlay)

func test_grid_overlay_last_vertical_line_is_at_right_boundary():
	var v_lines: Array = overlay.get_vertical_line_positions()
	assert_eq(v_lines[-1], GameConfig.MAP_HALF_WIDTH, "最后一条竖线应在右边界")

func test_grid_overlay_last_horizontal_line_is_at_bottom_boundary():
	var h_lines: Array = overlay.get_horizontal_line_positions()
	assert_eq(h_lines[-1], GameConfig.MAP_HALF_HEIGHT, "最后一条横线应在下边界")

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
