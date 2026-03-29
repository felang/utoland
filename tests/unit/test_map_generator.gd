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


func test_center_block_is_clear():
	var layout := generator.generate(config, 42)
	for y in range(9, 15):
		for x in range(14, 26):
			assert_eq(layout.get_cell(Vector2i(x, y)), MapLayout.CellType.GROUND, "中心区 (%d,%d) 应为空地" % [x, y])


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


func _make_config_with_prefabs() -> MapGeneratorConfig:
	var cfg := MapGeneratorConfig.new()
	var wall := MapPrefab.new()
	wall.id = "wall_test"
	wall.cell_type = 2  # WALL
	wall.cells = [Vector2i(0, 0), Vector2i(1, 0)]
	wall.rotatable = true
	cfg.prefabs = [wall]
	cfg.empty_chance = 0.0
	return cfg


func test_connectivity_all_spawn_points_reachable():
	var cfg := _make_config_with_prefabs()
	var layout := generator.generate(cfg, 42)
	var visited := {}
	var queue: Array[Vector2i] = [layout.player_spawn]
	visited[layout.player_spawn] = true
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
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
		assert_true(visited.has(sp), "刷怪点 %s 应可达玩家位置" % sp)


func test_mirror_x_symmetry():
	var cfg := _make_config_with_prefabs()
	cfg.symmetry_weights = [0.0, 1.0, 0.0]
	var layout := generator.generate(cfg, 42)
	var left_walls := 0
	var right_walls := 0
	var left_bounds := layout.get_block_bounds(0, 0)
	var right_bounds := layout.get_block_bounds(2, 0)
	for y in range(left_bounds.position.y, left_bounds.position.y + left_bounds.size.y):
		for x in range(left_bounds.position.x, left_bounds.position.x + left_bounds.size.x):
			if layout.get_cell(Vector2i(x, y)) == MapLayout.CellType.WALL:
				left_walls += 1
	for y in range(right_bounds.position.y, right_bounds.position.y + right_bounds.size.y):
		for x in range(right_bounds.position.x, right_bounds.position.x + right_bounds.size.x):
			if layout.get_cell(Vector2i(x, y)) == MapLayout.CellType.WALL:
				right_walls += 1
	assert_eq(left_walls, right_walls, "MIRROR_X 对称：左上和右上墙数量应相等")


func test_rotate_180_symmetry():
	var cfg := _make_config_with_prefabs()
	cfg.symmetry_weights = [0.0, 0.0, 1.0]
	var layout := generator.generate(cfg, 42)
	var tl_walls := 0
	var br_walls := 0
	var tl_bounds := layout.get_block_bounds(0, 0)
	var br_bounds := layout.get_block_bounds(2, 2)
	for y in range(tl_bounds.position.y, tl_bounds.position.y + tl_bounds.size.y):
		for x in range(tl_bounds.position.x, tl_bounds.position.x + tl_bounds.size.x):
			if layout.get_cell(Vector2i(x, y)) == MapLayout.CellType.WALL:
				tl_walls += 1
	for y in range(br_bounds.position.y, br_bounds.position.y + br_bounds.size.y):
		for x in range(br_bounds.position.x, br_bounds.position.x + br_bounds.size.x):
			if layout.get_cell(Vector2i(x, y)) == MapLayout.CellType.WALL:
				br_walls += 1
	assert_eq(tl_walls, br_walls, "ROTATE_180 对称：TL 和 BR 墙数量应相等")


func test_fallback_to_empty_map():
	var cfg := MapGeneratorConfig.new()
	var big_wall := MapPrefab.new()
	big_wall.id = "huge_wall"
	big_wall.cell_type = 2  # WALL
	var big_cells: Array[Vector2i] = []
	for y in range(5):
		for x in range(10):
			big_cells.append(Vector2i(x, y))
	big_wall.cells = big_cells
	big_wall.rotatable = false
	cfg.prefabs = [big_wall]
	cfg.empty_chance = 0.0
	cfg.max_prefabs_per_block = 2
	var layout := generator.generate(cfg, 42)
	assert_not_null(layout)
	assert_gt(layout.spawn_points.size(), 0, "应有刷怪点")
