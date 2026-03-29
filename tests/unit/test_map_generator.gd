extends GutTest

## MapGenerator 单元测试

var generator: MapGenerator
var config: MapGeneratorConfig


func before_each():
	generator = MapGenerator.new()
	config = MapGeneratorConfig.new()


func test_borders_filled():
	var layout := generator.generate(config, 42)
	for x in range(MapLayout.PLAYABLE_WIDTH):
		assert_eq(layout.get_cell(Vector2i(x, 0)), MapLayout.CellType.BORDER, "上边界 x=%d" % x)
		assert_eq(layout.get_cell(Vector2i(x, 23)), MapLayout.CellType.BORDER, "下边界 x=%d" % x)
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		assert_eq(layout.get_cell(Vector2i(0, y)), MapLayout.CellType.BORDER, "左边界 y=%d" % y)
		assert_eq(layout.get_cell(Vector2i(39, y)), MapLayout.CellType.BORDER, "右边界 y=%d" % y)


func test_spawn_zone_filled():
	var layout := generator.generate(config, 42)
	for x in range(1, 39):
		for y in [1, 2]:
			assert_eq(layout.get_cell(Vector2i(x, y)), MapLayout.CellType.SPAWN_ZONE, "刷怪区 (%d,%d)" % [x, y])


func test_spawn_points_count():
	var layout := generator.generate(config, 42)
	assert_gt(layout.spawn_points.size(), 3, "至少 4 个刷怪点")
	assert_lt(layout.spawn_points.size(), 13, "最多 12 个刷怪点")


func test_spawn_points_in_spawn_zone():
	var layout := generator.generate(config, 42)
	for sp in layout.spawn_points:
		assert_eq(layout.get_cell(sp), MapLayout.CellType.SPAWN_ZONE, "刷怪点 %s 应在刷怪区" % sp)


func test_seed_reproducibility():
	var layout1 := generator.generate(config, 123)
	var layout2 := generator.generate(config, 123)
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		for x in range(MapLayout.PLAYABLE_WIDTH):
			assert_eq(layout1.get_cell(Vector2i(x, y)), layout2.get_cell(Vector2i(x, y)),
				"相同种子应产生相同地图 (%d,%d)" % [x, y])


func test_placeable_cells_valid():
	var layout := generator.generate(config, 42)
	assert_gt(layout.placeable_cells.size(), 0, "应有可放置格子")
	for cell in layout.placeable_cells:
		assert_eq(layout.get_cell(cell), MapLayout.CellType.GROUND, "可放置格子应为 GROUND")
		assert_true(cell.x >= MapLayout.TACTICAL_MIN_X and cell.x <= MapLayout.TACTICAL_MAX_X, "可放置格子应在战术区 x 范围")
		assert_true(cell.y >= MapLayout.TACTICAL_MIN_Y and cell.y <= MapLayout.TACTICAL_MAX_Y, "可放置格子应在战术区 y 范围")


func _make_river_template() -> MapTemplate:
	var f := TerrainFeature.new()
	f.type = TerrainFeature.FeatureType.RIVER
	f.shape = TerrainFeature.FeatureShape.LINE
	f.start = Vector2(0.0, 0.5)
	f.end = Vector2(1.0, 0.5)
	f.width = 1
	f.gaps = [0.3, 0.7]
	f.gap_width = 3
	var t := MapTemplate.new()
	t.id = "test_river"
	t.features = [f]
	return t


func _make_config_with_template() -> MapGeneratorConfig:
	var cfg := MapGeneratorConfig.new()
	cfg.templates = [_make_river_template()]
	var wall := MapPrefab.new()
	wall.id = "wall_test"
	wall.cell_type = 2
	wall.cells = [Vector2i(0, 0), Vector2i(1, 0)]
	wall.rotatable = true
	cfg.prefabs = [wall]
	cfg.total_prefab_count = Vector2i(3, 5)
	return cfg


func test_template_generates_abyss():
	var cfg := _make_config_with_template()
	var layout := generator.generate(cfg, 42)
	var abyss_count := 0
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		for x in range(MapLayout.PLAYABLE_WIDTH):
			if layout.get_cell(Vector2i(x, y)) == MapLayout.CellType.ABYSS:
				abyss_count += 1
	assert_gt(abyss_count, 10, "模板应产生 ABYSS 格子")


func test_template_connectivity():
	var cfg := _make_config_with_template()
	var layout := generator.generate(cfg, 42)
	var visited := {}
	var queue: Array[Vector2i] = [layout.player_spawn]
	visited[layout.player_spawn] = true
	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		for dir in dirs:
			var next: Vector2i = current + dir
			if visited.has(next):
				continue
			if layout.is_passable(next):
				visited[next] = true
				queue.append(next)
	for sp in layout.spawn_points:
		assert_true(visited.has(sp), "刷怪点 %s 应可达" % sp)


func test_prefabs_not_in_center_safe():
	var cfg := _make_config_with_template()
	var layout := generator.generate(cfg, 42)
	for y in range(MapLayout.CENTER_SAFE_MIN_Y, MapLayout.CENTER_SAFE_MAX_Y + 1):
		for x in range(MapLayout.CENTER_SAFE_MIN_X, MapLayout.CENTER_SAFE_MAX_X + 1):
			var cell := layout.get_cell(Vector2i(x, y))
			assert_true(cell == MapLayout.CellType.GROUND or cell == MapLayout.CellType.ABYSS,
				"中心安全区 (%d,%d) 不应有 Prefab" % [x, y])
