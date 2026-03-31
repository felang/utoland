extends GutTest

## TemplateRenderer 单元测试

var renderer: TemplateRenderer


func before_each():
	renderer = TemplateRenderer.new()


func _make_river_line(start: Vector2, end: Vector2, width: int = 1, gaps: Array[float] = []) -> TerrainFeature:
	var f := TerrainFeature.new()
	f.type = TerrainFeature.FeatureType.RIVER
	f.shape = TerrainFeature.FeatureShape.LINE
	f.start = start
	f.end = end
	f.width = width
	f.gaps = gaps
	f.gap_width = 3
	return f


func _make_template(features: Array[TerrainFeature]) -> MapTemplate:
	var t := MapTemplate.new()
	t.id = "test"
	t.features = features
	return t


func test_horizontal_river_creates_abyss():
	var layout := MapLayout.new()
	layout._init_grid()
	var feature := _make_river_line(Vector2(0.0, 0.5), Vector2(1.0, 0.5))
	var template := _make_template([feature])
	renderer.render(template, layout)
	# y=0.5 在战术区 → y = 3 + 0.5*17 = 11（约中间）
	var mid_y := int(MapLayout.TACTICAL_MIN_Y + 0.5 * (MapLayout.TACTICAL_MAX_Y - MapLayout.TACTICAL_MIN_Y))
	var abyss_count := 0
	for x in range(MapLayout.TACTICAL_MIN_X, MapLayout.TACTICAL_MAX_X + 1):
		if layout.get_cell(Vector2i(x, mid_y)) == MapLayout.CellType.ABYSS:
			abyss_count += 1
	assert_gt(abyss_count, 20, "水平河流应产生大量 ABYSS 格子")


func test_river_gap_creates_ground():
	var layout := MapLayout.new()
	layout._init_grid()
	var feature := _make_river_line(Vector2(0.0, 0.5), Vector2(1.0, 0.5), 1, [0.5])
	feature.gap_width = 5
	var template := _make_template([feature])
	renderer.render(template, layout)
	var mid_y := int(MapLayout.TACTICAL_MIN_Y + 0.5 * (MapLayout.TACTICAL_MAX_Y - MapLayout.TACTICAL_MIN_Y))
	# 中间位置应有 GROUND 缺口
	var mid_x := int(MapLayout.TACTICAL_MIN_X + 0.5 * (MapLayout.TACTICAL_MAX_X - MapLayout.TACTICAL_MIN_X))
	assert_eq(layout.get_cell(Vector2i(mid_x, mid_y)), MapLayout.CellType.GROUND, "缺口位置应为 GROUND")


func test_corridor_has_walls_and_ground():
	var layout := MapLayout.new()
	layout._init_grid()
	var f := TerrainFeature.new()
	f.type = TerrainFeature.FeatureType.CORRIDOR
	f.shape = TerrainFeature.FeatureShape.LINE
	f.start = Vector2(0.5, 0.0)
	f.end = Vector2(0.5, 1.0)
	f.width = 3
	var template := _make_template([f])
	renderer.render(template, layout)
	# 中线附近应有 WALL 和 GROUND 混合
	var mid_x := int(MapLayout.TACTICAL_MIN_X + 0.5 * (MapLayout.TACTICAL_MAX_X - MapLayout.TACTICAL_MIN_X))
	var has_wall := false
	var has_ground := false
	for dy in range(-3, 4):
		var cell := layout.get_cell(Vector2i(mid_x + dy, 10))
		if cell == MapLayout.CellType.WALL:
			has_wall = true
		elif cell == MapLayout.CellType.GROUND:
			has_ground = true
	assert_true(has_wall, "走廊应有 WALL")
	assert_true(has_ground, "走廊应有 GROUND 通道")


func test_player_spawn_safe():
	var layout := MapLayout.new()
	layout._init_grid()
	# 放一条穿过玩家出生点的河流
	var feature := _make_river_line(Vector2(0.0, 0.47), Vector2(1.0, 0.47), 3)
	var template := _make_template([feature])
	renderer.render(template, layout)
	# 玩家出生点 3×3 应全为 GROUND
	var spawn := layout.player_spawn
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			assert_eq(layout.get_cell(Vector2i(spawn.x + dx, spawn.y + dy)), MapLayout.CellType.GROUND,
				"玩家出生点 (%d,%d) 应为 GROUND" % [spawn.x + dx, spawn.y + dy])


func test_rect_wall_band():
	var layout := MapLayout.new()
	layout._init_grid()
	var f := TerrainFeature.new()
	f.type = TerrainFeature.FeatureType.WALL_BAND
	f.shape = TerrainFeature.FeatureShape.RECT
	f.center = Vector2(0.8, 0.2)  # 远离玩家出生点，避免被 _ensure_player_spawn_safe 覆盖
	f.size = Vector2i(4, 4)
	var template := _make_template([f])
	renderer.render(template, layout)
	var center_pos := Vector2i(
		int(MapLayout.TACTICAL_MIN_X + 0.8 * (MapLayout.TACTICAL_MAX_X - MapLayout.TACTICAL_MIN_X)),
		int(MapLayout.TACTICAL_MIN_Y + 0.2 * (MapLayout.TACTICAL_MAX_Y - MapLayout.TACTICAL_MIN_Y)))
	assert_eq(layout.get_cell(center_pos), MapLayout.CellType.WALL, "RECT 中心应为 WALL")


func test_plaza_marks_cells():
	var layout := MapLayout.new()
	layout._init_grid()
	var f := TerrainFeature.new()
	f.type = TerrainFeature.FeatureType.PLAZA
	f.shape = TerrainFeature.FeatureShape.RECT
	f.center = Vector2(0.3, 0.3)
	f.size = Vector2i(4, 4)
	var template := _make_template([f])
	renderer.render(template, layout)
	assert_gt(renderer.get_plaza_cells().size(), 0, "PLAZA 应有标记格子")
	# PLAZA 不改变 CellType，仍为 GROUND
	for cell in renderer.get_plaza_cells():
		assert_eq(layout.get_cell(cell), MapLayout.CellType.GROUND, "PLAZA 格子仍为 GROUND")


func test_ring_creates_ring_shape():
	var layout := MapLayout.new()
	layout._init_grid()
	var f := TerrainFeature.new()
	f.type = TerrainFeature.FeatureType.RIVER
	f.shape = TerrainFeature.FeatureShape.RING
	f.center = Vector2(0.5, 0.5)
	f.size = Vector2i(10, 6)
	f.width = 1
	f.gaps = [0.25, 0.5, 0.75, 1.0]
	f.gap_width = 2
	var template := _make_template([f])
	renderer.render(template, layout)
	# 中心应为 GROUND（环内部）
	var center_pos := Vector2i(
		int(MapLayout.TACTICAL_MIN_X + 0.5 * (MapLayout.TACTICAL_MAX_X - MapLayout.TACTICAL_MIN_X)),
		int(MapLayout.TACTICAL_MIN_Y + 0.5 * (MapLayout.TACTICAL_MAX_Y - MapLayout.TACTICAL_MIN_Y)))
	assert_eq(layout.get_cell(center_pos), MapLayout.CellType.GROUND, "环中心应为 GROUND")
	# 环上应有 ABYSS
	var abyss_count := 0
	for y in range(MapLayout.TACTICAL_MIN_Y, MapLayout.TACTICAL_MAX_Y + 1):
		for x in range(MapLayout.TACTICAL_MIN_X, MapLayout.TACTICAL_MAX_X + 1):
			if layout.get_cell(Vector2i(x, y)) == MapLayout.CellType.ABYSS:
				abyss_count += 1
	assert_gt(abyss_count, 10, "环应产生 ABYSS 格子")
