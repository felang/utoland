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
