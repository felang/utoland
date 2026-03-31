class_name MapGenerator
extends RefCounted

## 随机地图生成器
## 简单方案：完整边界墙 + Prefab 随机散布 + 连通性验证

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func generate(config: MapGeneratorConfig, seed_value: int = -1) -> MapLayout:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

	var layout := MapLayout.new()

	_fill_borders(layout)
	_fill_ground(layout)

	# Prefab 散布 + 连通性验证
	_scatter_with_retry(layout, config)

	_compute_placeable_cells(layout)
	return layout


func apply_to_tilemap(map_scene: Node, layout: MapLayout, _config: MapGeneratorConfig) -> void:
	var ground_layer: TileMapLayer = map_scene.get_node("Ground")
	var terrain_layer: TileMapLayer = map_scene.get_node("Terrain")

	# Grass1 满铺坐标（type3 网格中心 fill tile）
	var grass_src_id := 0
	var grass_tile := Vector2i(5, 1)

	# 地形 source ID
	var border_src_id := 1   # Dirt1
	var wall_src_id := 2     # Wall-Up1
	var abyss_src_id := 3    # Water1

	for gy in range(MapLayout.PLAYABLE_HEIGHT):
		for gx in range(MapLayout.PLAYABLE_WIDTH):
			var grid_pos := Vector2i(gx, gy)
			var tile_pos := Vector2i(MapLayout.PLAYABLE_ORIGIN_X + gx, MapLayout.PLAYABLE_ORIGIN_Y + gy)
			var cell := layout.get_cell(grid_pos)

			# Ground layer: 全部铺草地
			ground_layer.set_cell(tile_pos, grass_src_id, grass_tile)

			# Terrain layer: 非 GROUND/SPAWN_ZONE 叠加 autotile
			match cell:
				MapLayout.CellType.BORDER:
					var atlas := TerrainAutotiler.get_atlas_coord(layout, grid_pos, MapLayout.CellType.BORDER)
					terrain_layer.set_cell(tile_pos, border_src_id, atlas)
				MapLayout.CellType.WALL:
					var atlas := TerrainAutotiler.get_atlas_coord(layout, grid_pos, MapLayout.CellType.WALL)
					terrain_layer.set_cell(tile_pos, wall_src_id, atlas)
				MapLayout.CellType.ABYSS:
					var atlas := TerrainAutotiler.get_atlas_coord(layout, grid_pos, MapLayout.CellType.ABYSS)
					terrain_layer.set_cell(tile_pos, abyss_src_id, atlas)


func _fill_borders(layout: MapLayout) -> void:
	for x in range(MapLayout.PLAYABLE_WIDTH):
		layout.set_cell(Vector2i(x, 0), MapLayout.CellType.BORDER)
		layout.set_cell(Vector2i(x, MapLayout.PLAYABLE_HEIGHT - 1), MapLayout.CellType.BORDER)
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		layout.set_cell(Vector2i(0, y), MapLayout.CellType.BORDER)
		layout.set_cell(Vector2i(MapLayout.PLAYABLE_WIDTH - 1, y), MapLayout.CellType.BORDER)


func _fill_ground(layout: MapLayout) -> void:
	for y in range(1, MapLayout.PLAYABLE_HEIGHT - 1):
		for x in range(1, MapLayout.PLAYABLE_WIDTH - 1):
			layout.set_cell(Vector2i(x, y), MapLayout.CellType.GROUND)


func _scatter_with_retry(layout: MapLayout, config: MapGeneratorConfig) -> void:
	if config.prefabs.is_empty():
		return

	var prefab_count := _rng.randi_range(config.total_prefab_count.x, config.total_prefab_count.y)
	var base_layout := _clone_layout(layout)

	for retry in range(8):
		var attempt := _clone_layout(base_layout)
		_scatter_prefabs(attempt, config, prefab_count)
		if _validate_edge_connectivity(attempt):
			_copy_grid(attempt, layout)
			return
		prefab_count = maxi(prefab_count - 2, 0)

	# 保底：不放 Prefab


func _scatter_prefabs(layout: MapLayout, config: MapGeneratorConfig, count: int) -> void:
	for i in range(count):
		var prefab: MapPrefab = config.prefabs[_rng.randi_range(0, config.prefabs.size() - 1)]
		var rotation := 0
		if prefab.rotatable:
			rotation = _rng.randi_range(0, 3)
		var cells := prefab.get_rotated_cells(rotation)
		_try_place_prefab(layout, cells, prefab.cell_type)


func _try_place_prefab(layout: MapLayout, cells: Array[Vector2i], cell_type: int) -> void:
	for attempt in range(20):
		# 在边界内（不含边界墙和紧贴边界 1 格缓冲）随机放置
		var ox := _rng.randi_range(2, MapLayout.PLAYABLE_WIDTH - 3)
		var oy := _rng.randi_range(2, MapLayout.PLAYABLE_HEIGHT - 3)
		var valid := true
		var placed: Array[Vector2i] = []
		for c in cells:
			var pos := Vector2i(ox + c.x, oy + c.y)
			if not _is_valid_prefab_pos(pos, layout):
				valid = false
				break
			placed.append(pos)
		if valid:
			for pos in placed:
				layout.set_cell(pos, cell_type as MapLayout.CellType)
			return


func _is_valid_prefab_pos(pos: Vector2i, layout: MapLayout) -> bool:
	# 必须在边界内（留 1 格缓冲不贴边界墙）
	if pos.x < 2 or pos.x >= MapLayout.PLAYABLE_WIDTH - 2:
		return false
	if pos.y < 2 or pos.y >= MapLayout.PLAYABLE_HEIGHT - 2:
		return false
	if layout.get_cell(pos) != MapLayout.CellType.GROUND:
		return false
	# 不放在中心安全区
	if (pos.x >= MapLayout.CENTER_SAFE_MIN_X and pos.x <= MapLayout.CENTER_SAFE_MAX_X
		and pos.y >= MapLayout.CENTER_SAFE_MIN_Y and pos.y <= MapLayout.CENTER_SAFE_MAX_Y):
		return false
	return true


func _validate_edge_connectivity(layout: MapLayout) -> bool:
	## 验证四面边缘都能到达玩家位置
	## 取四面边缘中点作为测试点
	var edge_points: Array[Vector2i] = [
		Vector2i(MapLayout.PLAYABLE_WIDTH / 2, 1),   # 上
		Vector2i(MapLayout.PLAYABLE_WIDTH / 2, MapLayout.PLAYABLE_HEIGHT - 2),  # 下
		Vector2i(1, MapLayout.PLAYABLE_HEIGHT / 2),   # 左
		Vector2i(MapLayout.PLAYABLE_WIDTH - 2, MapLayout.PLAYABLE_HEIGHT / 2),  # 右
	]

	var visited := {}
	var queue: Array[Vector2i] = [layout.player_spawn]
	visited[layout.player_spawn] = true
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

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
		if not visited.has(ep):
			return false
	return true


func _clone_layout(layout: MapLayout) -> MapLayout:
	var clone := MapLayout.new()
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		for x in range(MapLayout.PLAYABLE_WIDTH):
			clone.grid[y][x] = layout.grid[y][x]
	clone.spawn_points = layout.spawn_points.duplicate()
	clone.player_spawn = layout.player_spawn
	return clone


func _copy_grid(source: MapLayout, target: MapLayout) -> void:
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		for x in range(MapLayout.PLAYABLE_WIDTH):
			target.grid[y][x] = source.grid[y][x]


func _compute_placeable_cells(layout: MapLayout) -> void:
	layout.placeable_cells.clear()
	for y in range(1, MapLayout.PLAYABLE_HEIGHT - 1):
		for x in range(1, MapLayout.PLAYABLE_WIDTH - 1):
			if layout.get_cell(Vector2i(x, y)) == MapLayout.CellType.GROUND:
				layout.placeable_cells.append(Vector2i(x, y))
