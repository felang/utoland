extends GutTest

func test_forest_blueprint_generates_valid_layout() -> void:
	var blueprint: MapBlueprint = load("res://resources/maps/blueprints/forest_blueprint.tres")
	assert_not_null(blueprint, "forest blueprint should load")
	assert_eq(blueprint.zones.size(), 3, "should have 3 zones")
	assert_eq(blueprint.spawn_points.size(), 4, "should have 4 spawn points")

	var generator := MapGenerator.new()
	var layout := generator.generate(blueprint)

	assert_eq(layout.grid_width, 40)
	assert_eq(layout.grid_height, 24)

	# 玩家出生点是 GROUND
	assert_true(layout.is_ground(layout.player_spawn), "player spawn should be ground")

	# 所有刷新点可达 (BFS)
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
	for sp_dir in layout.spawn_points:
		var sp: Vector2i = layout.spawn_points[sp_dir]
		assert_true(visited.has(sp), "%s spawn point should be reachable" % sp_dir)

	# 中央废墟骨架存在
	assert_eq(layout.get_cell(Vector2i(15, 9)), MapLayout.CellType.OBSTACLE, "central ruins top-left wall")
	assert_eq(layout.get_cell(Vector2i(24, 9)), MapLayout.CellType.OBSTACLE, "central ruins top-right wall")

	# 东北狭道墙柱存在
	assert_eq(layout.get_cell(Vector2i(14, 2)), MapLayout.CellType.OBSTACLE, "NE corridor left wall")
	assert_eq(layout.get_cell(Vector2i(17, 2)), MapLayout.CellType.OBSTACLE, "NE corridor right wall")

	# 东北狭道通道畅通
	assert_eq(layout.get_cell(Vector2i(15, 4)), MapLayout.CellType.GROUND, "NE corridor passage")
	assert_eq(layout.get_cell(Vector2i(16, 4)), MapLayout.CellType.GROUND, "NE corridor passage")

func test_spawn_direction_activation() -> void:
	var spawner := EnemySpawner.new()
	spawner.all_spawn_points = {
		"north": Vector2(0, -368),
		"south": Vector2(0, 368),
		"east": Vector2(608, 0),
		"west": Vector2(-608, 0),
	}
	add_child(spawner)

	spawner.update_active_directions(1, WaveData.new())
	assert_eq(spawner.active_directions.size(), 2)

	spawner.update_active_directions(6, WaveData.new())
	assert_eq(spawner.active_directions.size(), 3)

	spawner.update_active_directions(13, WaveData.new())
	assert_eq(spawner.active_directions.size(), 4)

	var boss_wd := WaveData.new()
	boss_wd.active_spawn_directions = ["north", "south", "east", "west"]
	spawner.update_active_directions(5, boss_wd)
	assert_eq(spawner.active_directions.size(), 4)

	spawner.queue_free()

func test_multiple_generations_differ() -> void:
	var blueprint: MapBlueprint = load("res://resources/maps/blueprints/forest_blueprint.tres")
	var generator := MapGenerator.new()
	var layout_a := generator.generate(blueprint, 1)
	var layout_b := generator.generate(blueprint, 2)
	var diff_count := 0
	for y in range(17, 23):
		for x in range(10, 30):
			if layout_a.grid[y][x] != layout_b.grid[y][x]:
				diff_count += 1
	assert_gt(diff_count, 0, "different seeds should produce different layouts in rubble zone")
