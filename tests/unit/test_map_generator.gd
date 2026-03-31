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


func test_interior_is_ground():
	var layout := generator.generate(config, 42)
	# 无 prefab 时内部应全是 GROUND
	for y in range(1, MapLayout.PLAYABLE_HEIGHT - 1):
		for x in range(1, MapLayout.PLAYABLE_WIDTH - 1):
			assert_eq(layout.get_cell(Vector2i(x, y)), MapLayout.CellType.GROUND, "内部 (%d,%d)" % [x, y])


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
		# 应在边界内
		assert_true(cell.x >= 1 and cell.x < MapLayout.PLAYABLE_WIDTH - 1, "x 应在边界内")
		assert_true(cell.y >= 1 and cell.y < MapLayout.PLAYABLE_HEIGHT - 1, "y 应在边界内")


func _make_config_with_prefabs() -> MapGeneratorConfig:
	var cfg := MapGeneratorConfig.new()
	var wall := MapPrefab.new()
	wall.id = "wall_test"
	wall.cell_type = 2
	wall.cells = [Vector2i(0, 0), Vector2i(1, 0)]
	wall.rotatable = true
	cfg.prefabs = [wall]
	cfg.total_prefab_count = Vector2i(5, 10)
	return cfg


func test_prefabs_placed():
	var cfg := _make_config_with_prefabs()
	var layout := generator.generate(cfg, 42)
	var wall_count := 0
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		for x in range(MapLayout.PLAYABLE_WIDTH):
			if layout.get_cell(Vector2i(x, y)) == MapLayout.CellType.WALL:
				wall_count += 1
	assert_gt(wall_count, 0, "应有 WALL 格子")


func test_prefabs_not_in_center_safe():
	var cfg := _make_config_with_prefabs()
	var layout := generator.generate(cfg, 42)
	for y in range(MapLayout.CENTER_SAFE_MIN_Y, MapLayout.CENTER_SAFE_MAX_Y + 1):
		for x in range(MapLayout.CENTER_SAFE_MIN_X, MapLayout.CENTER_SAFE_MAX_X + 1):
			var cell := layout.get_cell(Vector2i(x, y))
			assert_eq(cell, MapLayout.CellType.GROUND, "中心安全区 (%d,%d) 应为 GROUND" % [x, y])


func test_edge_connectivity():
	var cfg := _make_config_with_prefabs()
	var layout := generator.generate(cfg, 42)
	# 四面边缘中点应可达玩家
	var edge_points: Array[Vector2i] = [
		Vector2i(MapLayout.PLAYABLE_WIDTH / 2, 1),
		Vector2i(MapLayout.PLAYABLE_WIDTH / 2, MapLayout.PLAYABLE_HEIGHT - 2),
		Vector2i(1, MapLayout.PLAYABLE_HEIGHT / 2),
		Vector2i(MapLayout.PLAYABLE_WIDTH - 2, MapLayout.PLAYABLE_HEIGHT / 2),
	]
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
	for ep in edge_points:
		assert_true(visited.has(ep), "边缘点 %s 应可达玩家" % ep)
