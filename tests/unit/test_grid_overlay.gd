extends GutTest

var overlay: GridOverlay

func before_each():
	overlay = load("res://scripts/ui/grid_overlay.gd").new()
	add_child_autofree(overlay)

func test_grid_overlay_last_vertical_line_is_at_right_boundary():
	var v_lines: Array = overlay.get_vertical_line_positions()
	assert_almost_eq(v_lines[-1], GameConfig.MAP_HALF_WIDTH, float(GameConfig.GRID_SIZE), "最后一条竖线应在右边界附近")

func test_grid_overlay_last_horizontal_line_is_at_bottom_boundary():
	var h_lines: Array = overlay.get_horizontal_line_positions()
	assert_almost_eq(h_lines[-1], GameConfig.MAP_HALF_HEIGHT, float(GameConfig.GRID_SIZE), "最后一条横线应在下边界附近")

func test_grid_overlay_first_lines_at_negative_boundary():
	var v_lines: Array = overlay.get_vertical_line_positions()
	var h_lines: Array = overlay.get_horizontal_line_positions()
	assert_almost_eq(v_lines[0], -GameConfig.MAP_HALF_WIDTH, 1.0, "第一条竖线在左边界附近")
	assert_almost_eq(h_lines[0], -GameConfig.MAP_HALF_HEIGHT, 1.0, "第一条横线在上边界附近")

func test_grid_overlay_lines_are_grid_spaced():
	var v_lines: Array = overlay.get_vertical_line_positions()
	if v_lines.size() >= 2:
		var spacing: float = v_lines[1] - v_lines[0]
		assert_almost_eq(spacing, float(GameConfig.GRID_SIZE), 0.01, "竖线间距应为 GRID_SIZE")

func test_grid_overlay_line_count_matches_formula():
	var v_lines: Array = overlay.get_vertical_line_positions()
	var h_lines: Array = overlay.get_horizontal_line_positions()
	var expected_v: int = int(floor(GameConfig.MAP_PIXEL_WIDTH / GameConfig.GRID_SIZE)) + 1
	var expected_h: int = int(floor(GameConfig.MAP_PIXEL_HEIGHT / GameConfig.GRID_SIZE)) + 1
	assert_eq(v_lines.size(), expected_v, "竖线数量应为 floor(MAP_WIDTH/GRID) + 1")
	assert_eq(h_lines.size(), expected_h, "横线数量应为 floor(MAP_HEIGHT/GRID) + 1")
