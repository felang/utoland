extends GutTest

var generator: MapGenerator
var blueprint: MapBlueprint

func before_each() -> void:
	generator = MapGenerator.new()
	blueprint = _create_test_blueprint()

func _create_test_blueprint() -> MapBlueprint:
	var bp := MapBlueprint.new()
	bp.id = "test"
	bp.grid_width = 40
	bp.grid_height = 24
	bp.player_spawn = Vector2i(19, 12)
	bp.spawn_points = {
		"north": Vector2i(20, 0),
		"south": Vector2i(20, 23),
		"east": Vector2i(39, 12),
		"west": Vector2i(0, 12),
	}
	bp.border_gap_size = 3

	var zone := ZoneData.new()
	zone.id = "test_zone"
	zone.origin = Vector2i(10, 10)
	zone.size = Vector2i(4, 4)
	zone.fixed_walls = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	zone.fill_count = Vector2i(0, 0)
	bp.zones = [zone]
	return bp

func test_grid_dimensions() -> void:
	var layout := generator.generate(blueprint)
	assert_eq(layout.grid_width, 40)
	assert_eq(layout.grid_height, 24)
	assert_eq(layout.grid.size(), 24)

func test_border_walls() -> void:
	var layout := generator.generate(blueprint)
	assert_eq(layout.get_cell(Vector2i(5, 0)), MapLayout.CellType.OBSTACLE, "top border")
	assert_eq(layout.get_cell(Vector2i(0, 5)), MapLayout.CellType.OBSTACLE, "left border")
	assert_eq(layout.get_cell(Vector2i(39, 5)), MapLayout.CellType.OBSTACLE, "right border")
	assert_eq(layout.get_cell(Vector2i(5, 23)), MapLayout.CellType.OBSTACLE, "bottom border")

func test_border_gaps_at_spawn_points() -> void:
	var layout := generator.generate(blueprint)
	assert_eq(layout.get_cell(Vector2i(20, 0)), MapLayout.CellType.GROUND, "north spawn gap center")
	assert_eq(layout.get_cell(Vector2i(19, 0)), MapLayout.CellType.GROUND, "north spawn gap left")
	assert_eq(layout.get_cell(Vector2i(21, 0)), MapLayout.CellType.GROUND, "north spawn gap right")

func test_interior_is_ground() -> void:
	var layout := generator.generate(blueprint)
	assert_eq(layout.get_cell(Vector2i(15, 12)), MapLayout.CellType.GROUND, "interior cell")

func test_fixed_walls_placed() -> void:
	var layout := generator.generate(blueprint)
	assert_eq(layout.get_cell(Vector2i(10, 10)), MapLayout.CellType.OBSTACLE)
	assert_eq(layout.get_cell(Vector2i(11, 10)), MapLayout.CellType.OBSTACLE)
	assert_eq(layout.get_cell(Vector2i(12, 10)), MapLayout.CellType.OBSTACLE)
	assert_eq(layout.get_cell(Vector2i(13, 10)), MapLayout.CellType.OBSTACLE)

func test_random_fill_count() -> void:
	var bp := _create_test_blueprint()
	bp.zones[0].fill_count = Vector2i(2, 4)
	bp.zones[0].fixed_walls = []
	var layout := generator.generate(bp)
	var count := 0
	for y in range(10, 14):
		for x in range(10, 14):
			if layout.get_cell(Vector2i(x, y)) == MapLayout.CellType.OBSTACLE:
				count += 1
	assert_gte(count, 2, "at least 2 random obstacles")
	assert_lte(count, 4, "at most 4 random obstacles")

func test_player_spawn_area_clear() -> void:
	var layout := generator.generate(blueprint)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var pos := blueprint.player_spawn + Vector2i(dx, dy)
			assert_eq(layout.get_cell(pos), MapLayout.CellType.GROUND,
				"player spawn area (%d,%d) should be ground" % [pos.x, pos.y])

func test_connectivity() -> void:
	var layout := generator.generate(blueprint)
	var visited := {}
	var queue: Array[Vector2i] = [layout.player_spawn]
	visited[layout.player_spawn] = true
	var dirs: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		for dir in dirs:
			var next: Vector2i = current + dir
			if visited.has(next):
				continue
			if layout.is_ground(next):
				visited[next] = true
				queue.append(next)
	for sp in layout.spawn_points.values():
		assert_true(visited.has(sp), "spawn point %s should be reachable" % str(sp))

func test_spawn_points_stored() -> void:
	var layout := generator.generate(blueprint)
	assert_eq(layout.spawn_points.size(), 4)
	assert_eq(layout.spawn_points["north"], Vector2i(20, 0))
	assert_eq(layout.player_spawn, Vector2i(19, 12))

func test_seed_reproducibility() -> void:
	var layout_a := generator.generate(blueprint, 42)
	var layout_b := generator.generate(blueprint, 42)
	for y in range(24):
		for x in range(40):
			assert_eq(layout_a.grid[y][x], layout_b.grid[y][x],
				"cell (%d,%d) should match with same seed" % [x, y])
