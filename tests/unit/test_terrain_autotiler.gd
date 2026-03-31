extends GutTest

## TerrainAutotiler 单元测试


func _make_layout_with_cell(pos: Vector2i, cell_type: int) -> MapLayout:
	var layout := MapLayout.new()
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		for x in range(MapLayout.PLAYABLE_WIDTH):
			layout.set_cell(Vector2i(x, y), MapLayout.CellType.GROUND)
	layout.set_cell(pos, cell_type as MapLayout.CellType)
	return layout


func _make_layout_filled(cell_type: int) -> MapLayout:
	var layout := MapLayout.new()
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		for x in range(MapLayout.PLAYABLE_WIDTH):
			layout.set_cell(Vector2i(x, y), cell_type as MapLayout.CellType)
	return layout


func test_isolated_cell_bitmask_is_zero():
	var layout := _make_layout_with_cell(Vector2i(10, 10), MapLayout.CellType.WALL)
	var bitmask := TerrainAutotiler.compute_bitmask(layout, Vector2i(10, 10), MapLayout.CellType.WALL)
	assert_eq(bitmask, 0, "孤立 cell bitmask 应为 0")


func test_fully_surrounded_bitmask_is_255():
	var layout := _make_layout_filled(MapLayout.CellType.WALL)
	var bitmask := TerrainAutotiler.compute_bitmask(layout, Vector2i(10, 10), MapLayout.CellType.WALL)
	assert_eq(bitmask, 255, "全包围 bitmask 应为 255")


func test_north_neighbor_only():
	var layout := _make_layout_with_cell(Vector2i(10, 10), MapLayout.CellType.WALL)
	layout.set_cell(Vector2i(10, 9), MapLayout.CellType.WALL)
	var bitmask := TerrainAutotiler.compute_bitmask(layout, Vector2i(10, 10), MapLayout.CellType.WALL)
	assert_eq(bitmask, 1, "仅 N 邻居 bitmask 应为 1")


func test_east_neighbor_only():
	var layout := _make_layout_with_cell(Vector2i(10, 10), MapLayout.CellType.WALL)
	layout.set_cell(Vector2i(11, 10), MapLayout.CellType.WALL)
	var bitmask := TerrainAutotiler.compute_bitmask(layout, Vector2i(10, 10), MapLayout.CellType.WALL)
	assert_eq(bitmask, 4, "仅 E 邻居 bitmask 应为 4")


func test_corner_masking_ne_without_both_edges():
	var layout := _make_layout_with_cell(Vector2i(10, 10), MapLayout.CellType.WALL)
	layout.set_cell(Vector2i(11, 9), MapLayout.CellType.WALL)  # NE
	layout.set_cell(Vector2i(10, 9), MapLayout.CellType.WALL)  # N
	var bitmask := TerrainAutotiler.compute_bitmask(layout, Vector2i(10, 10), MapLayout.CellType.WALL)
	assert_eq(bitmask, 1, "NE 被 mask，只剩 N=1")


func test_corner_masking_ne_with_both_edges():
	var layout := _make_layout_with_cell(Vector2i(10, 10), MapLayout.CellType.WALL)
	layout.set_cell(Vector2i(10, 9), MapLayout.CellType.WALL)  # N
	layout.set_cell(Vector2i(11, 9), MapLayout.CellType.WALL)  # NE
	layout.set_cell(Vector2i(11, 10), MapLayout.CellType.WALL) # E
	var bitmask := TerrainAutotiler.compute_bitmask(layout, Vector2i(10, 10), MapLayout.CellType.WALL)
	assert_eq(bitmask, 1 + 2 + 4, "N+NE+E = 7")


func test_spawn_zone_treated_as_non_same_type():
	var layout := _make_layout_with_cell(Vector2i(10, 10), MapLayout.CellType.WALL)
	layout.set_cell(Vector2i(10, 9), MapLayout.CellType.SPAWN_ZONE)
	var bitmask := TerrainAutotiler.compute_bitmask(layout, Vector2i(10, 10), MapLayout.CellType.WALL)
	assert_eq(bitmask, 0, "SPAWN_ZONE 不是 WALL 的同类型")


func test_abyss_bitmask_independent_from_wall():
	var layout := _make_layout_with_cell(Vector2i(10, 10), MapLayout.CellType.ABYSS)
	layout.set_cell(Vector2i(10, 9), MapLayout.CellType.WALL)
	layout.set_cell(Vector2i(10, 11), MapLayout.CellType.ABYSS)
	var bitmask := TerrainAutotiler.compute_bitmask(layout, Vector2i(10, 10), MapLayout.CellType.ABYSS)
	assert_eq(bitmask, 16, "WALL 邻居不算 ABYSS 同类型，只有 S=16")


func test_border_at_edge_sees_border_outside():
	var layout := MapLayout.new()
	layout.set_cell(Vector2i(0, 0), MapLayout.CellType.BORDER)
	layout.set_cell(Vector2i(1, 0), MapLayout.CellType.BORDER)
	layout.set_cell(Vector2i(0, 1), MapLayout.CellType.BORDER)
	var bitmask := TerrainAutotiler.compute_bitmask(layout, Vector2i(0, 0), MapLayout.CellType.BORDER)
	assert_eq(bitmask, 1 + 2 + 4 + 16 + 32 + 64 + 128, "边缘 BORDER 应看到边界外为同类型 (缺SE=247)")


func test_get_atlas_coord_isolated():
	var layout := _make_layout_with_cell(Vector2i(10, 10), MapLayout.CellType.WALL)
	var coord := TerrainAutotiler.get_atlas_coord(layout, Vector2i(10, 10), MapLayout.CellType.WALL)
	assert_eq(coord, Vector2i(0, 0), "孤立块应返回 (0,0)")


func test_get_atlas_coord_full():
	var layout := _make_layout_filled(MapLayout.CellType.BORDER)
	var coord := TerrainAutotiler.get_atlas_coord(layout, Vector2i(10, 10), MapLayout.CellType.BORDER)
	assert_eq(coord, Vector2i(7, 0), "全填充应返回 (7,0)")
