class_name MapGenerator
extends RefCounted

## 随机地图生成器

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _template_renderer: TemplateRenderer = TemplateRenderer.new()


func generate(config: MapGeneratorConfig, seed_value: int = -1) -> MapLayout:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

	var layout := MapLayout.new()

	_fill_borders(layout)
	_fill_spawn_zone(layout)
	_generate_spawn_points(layout, config)

	var success := _try_generate_terrain(layout, config)
	if not success:
		_clear_terrain(layout)

	_compute_placeable_cells(layout)
	return layout


func apply_to_tilemap(map_scene: Node, layout: MapLayout, config: MapGeneratorConfig) -> void:
	var ground_layer: TileMapLayer = map_scene.get_node("Ground")
	var terrain_layer: TileMapLayer = map_scene.get_node("Terrain")

	assert(ground_layer != null, "地图模板缺少 Ground 节点")
	assert(terrain_layer != null, "地图模板缺少 Terrain 节点")

	var all_playable: Array[Vector2i] = []
	var water_cells: Array[Vector2i] = []
	var wall_cells: Array[Vector2i] = []
	var border_cells: Array[Vector2i] = []

	for gy in range(MapLayout.PLAYABLE_HEIGHT):
		for gx in range(MapLayout.PLAYABLE_WIDTH):
			var tile_pos := Vector2i(MapLayout.PLAYABLE_ORIGIN_X + gx, MapLayout.PLAYABLE_ORIGIN_Y + gy)
			all_playable.append(tile_pos)
			match layout.get_cell(Vector2i(gx, gy)):
				MapLayout.CellType.ABYSS:
					water_cells.append(tile_pos)
				MapLayout.CellType.WALL:
					wall_cells.append(tile_pos)
				MapLayout.CellType.BORDER:
					border_cells.append(tile_pos)

	# Ground 层：全部铺草底色
	var terrain_set := 0
	ground_layer.set_cells_terrain_connect(all_playable, terrain_set, config.grass_terrain_id)

	# Terrain 层：BORDER + WALL + ABYSS 同层渲染
	if border_cells.size() > 0:
		terrain_layer.set_cells_terrain_connect(border_cells, terrain_set, config.border_terrain_id)
	if wall_cells.size() > 0:
		terrain_layer.set_cells_terrain_connect(wall_cells, terrain_set, config.wall_terrain_id)
	if water_cells.size() > 0:
		terrain_layer.set_cells_terrain_connect(water_cells, terrain_set, config.water_terrain_id)


func _fill_borders(layout: MapLayout) -> void:
	## 填充边界（最外圈一圈）
	for x in range(MapLayout.PLAYABLE_WIDTH):
		layout.set_cell(Vector2i(x, 0), MapLayout.CellType.BORDER)
		layout.set_cell(Vector2i(x, MapLayout.PLAYABLE_HEIGHT - 1), MapLayout.CellType.BORDER)
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		layout.set_cell(Vector2i(0, y), MapLayout.CellType.BORDER)
		layout.set_cell(Vector2i(MapLayout.PLAYABLE_WIDTH - 1, y), MapLayout.CellType.BORDER)


func _fill_spawn_zone(layout: MapLayout) -> void:
	## 填充四边刷怪区（边界内侧 2 格宽）
	# 上下两条水平带
	for x in range(1, MapLayout.PLAYABLE_WIDTH - 1):
		for y in [1, 2]:
			layout.set_cell(Vector2i(x, y), MapLayout.CellType.SPAWN_ZONE)
		for y in [MapLayout.PLAYABLE_HEIGHT - 3, MapLayout.PLAYABLE_HEIGHT - 2]:
			layout.set_cell(Vector2i(x, y), MapLayout.CellType.SPAWN_ZONE)
	# 左右两条垂直带
	for y in range(1, MapLayout.PLAYABLE_HEIGHT - 1):
		for x in [1, 2]:
			layout.set_cell(Vector2i(x, y), MapLayout.CellType.SPAWN_ZONE)
		for x in [MapLayout.PLAYABLE_WIDTH - 3, MapLayout.PLAYABLE_WIDTH - 2]:
			layout.set_cell(Vector2i(x, y), MapLayout.CellType.SPAWN_ZONE)


func _generate_spawn_points(layout: MapLayout, config: MapGeneratorConfig) -> void:
	## 在四条边的刷怪区内生成刷怪点
	var edges: Array = [
		{"axis": "x", "range_min": 3, "range_max": 36, "fixed_values": [1, 2]},
		{"axis": "x", "range_min": 3, "range_max": 36, "fixed_values": [21, 22]},
		{"axis": "y", "range_min": 3, "range_max": 20, "fixed_values": [1, 2]},
		{"axis": "y", "range_min": 3, "range_max": 20, "fixed_values": [37, 38]},
	]

	for edge in edges:
		var count := _rng.randi_range(config.spawns_per_edge.x, config.spawns_per_edge.y)
		var positions: Array[int] = []
		for i in range(count):
			var pos := _pick_spawn_pos_on_edge(
				edge["range_min"] as int, edge["range_max"] as int,
				positions, config.min_spawn_spacing
			)
			if pos >= 0:
				positions.append(pos)
				var fixed_vals: Array = edge["fixed_values"]
				var fixed_val: int = fixed_vals[_rng.randi_range(0, 1)]
				var spawn_pos: Vector2i
				if edge["axis"] == "x":
					spawn_pos = Vector2i(pos, fixed_val)
				else:
					spawn_pos = Vector2i(fixed_val, pos)
				layout.spawn_points.append(spawn_pos)

	# 四角刷怪点
	var corners: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(38, 1),
		Vector2i(1, 22), Vector2i(38, 22),
	]
	for corner in corners:
		if _rng.randf() < config.corner_spawn_chance:
			layout.spawn_points.append(corner)


func _pick_spawn_pos_on_edge(range_min: int, range_max: int, existing: Array[int], min_spacing: int) -> int:
	## 在指定范围内选择一个与已有位置保持间距的刷怪位置
	for attempt in range(20):
		var pos := _rng.randi_range(range_min, range_max)
		var valid := true
		for ex in existing:
			if abs(pos - ex) < min_spacing:
				valid = false
				break
		if valid:
			return pos
	return -1


func _try_generate_terrain(layout: MapLayout, config: MapGeneratorConfig) -> bool:
	## 模板渲染 + Prefab 散布 + 连通性验证
	if config.templates.is_empty():
		return true

	# 尝试最多 3 个随机模板
	var tried_indices: Array[int] = []
	for attempt in range(mini(config.templates.size(), 3)):
		var idx := _rng.randi_range(0, config.templates.size() - 1)
		while idx in tried_indices and tried_indices.size() < config.templates.size():
			idx = _rng.randi_range(0, config.templates.size() - 1)
		tried_indices.append(idx)
		var template: MapTemplate = config.templates[idx]

		# 渲染模板骨架
		var attempt_layout := _clone_layout(layout)
		_template_renderer.render(template, attempt_layout)

		# Prefab 散布 + 连通性检查
		var prefab_count := _rng.randi_range(config.total_prefab_count.x, config.total_prefab_count.y)
		for retry in range(5):
			var scatter_layout := _clone_layout(attempt_layout)
			_scatter_prefabs(scatter_layout, config, prefab_count)
			if _validate_connectivity(scatter_layout):
				_copy_grid(scatter_layout, layout)
				return true
			prefab_count = maxi(prefab_count - 2, 0)

	return false


func _scatter_prefabs(layout: MapLayout, config: MapGeneratorConfig, count: int) -> void:
	## 在战术区散布预制件，避开 PLAZA 区域和中心安全区
	if config.prefabs.is_empty() or count <= 0:
		return
	var plaza_set := {}
	for c in _template_renderer.get_plaza_cells():
		plaza_set[c] = true
	for i in range(count):
		var prefab: MapPrefab = config.prefabs[_rng.randi_range(0, config.prefabs.size() - 1)]
		var rotation := 0
		if prefab.rotatable:
			rotation = _rng.randi_range(0, 3)
		var cells := prefab.get_rotated_cells(rotation)
		_try_place_prefab(layout, cells, prefab.cell_type, plaza_set)


func _try_place_prefab(layout: MapLayout, cells: Array[Vector2i], cell_type: int, plaza_set: Dictionary) -> void:
	## 随机尝试在战术区放置一个预制件
	for attempt in range(15):
		var ox := _rng.randi_range(MapLayout.TACTICAL_MIN_X, MapLayout.TACTICAL_MAX_X)
		var oy := _rng.randi_range(MapLayout.TACTICAL_MIN_Y, MapLayout.TACTICAL_MAX_Y)
		var valid := true
		var placed: Array[Vector2i] = []
		for c in cells:
			var pos := Vector2i(ox + c.x, oy + c.y)
			if not _is_valid_prefab_pos(pos, layout, plaza_set):
				valid = false
				break
			placed.append(pos)
		if valid:
			for pos in placed:
				layout.set_cell(pos, cell_type as MapLayout.CellType)
			return


func _is_valid_prefab_pos(pos: Vector2i, layout: MapLayout, plaza_set: Dictionary) -> bool:
	## 检查位置是否可放置预制件
	if pos.x < MapLayout.TACTICAL_MIN_X or pos.x > MapLayout.TACTICAL_MAX_X:
		return false
	if pos.y < MapLayout.TACTICAL_MIN_Y or pos.y > MapLayout.TACTICAL_MAX_Y:
		return false
	if layout.get_cell(pos) != MapLayout.CellType.GROUND:
		return false
	if plaza_set.has(pos):
		return false
	if (pos.x >= MapLayout.CENTER_SAFE_MIN_X and pos.x <= MapLayout.CENTER_SAFE_MAX_X
		and pos.y >= MapLayout.CENTER_SAFE_MIN_Y and pos.y <= MapLayout.CENTER_SAFE_MAX_Y):
		return false
	return true


func _clone_layout(layout: MapLayout) -> MapLayout:
	## 复制 layout 用于尝试（保留边界/刷怪区/刷怪点，只复制 grid）
	var clone := MapLayout.new()
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		for x in range(MapLayout.PLAYABLE_WIDTH):
			clone.grid[y][x] = layout.grid[y][x]
	clone.spawn_points = layout.spawn_points.duplicate()
	clone.player_spawn = layout.player_spawn
	return clone


func _copy_grid(source: MapLayout, target: MapLayout) -> void:
	## 将 source 的完整 grid 复制到 target
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		for x in range(MapLayout.PLAYABLE_WIDTH):
			target.grid[y][x] = source.grid[y][x]


func _validate_connectivity(layout: MapLayout) -> bool:
	## BFS 从玩家出生点验证所有刷怪点可达
	if layout.spawn_points.is_empty():
		return true

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

	for sp in layout.spawn_points:
		if not visited.has(sp):
			return false
	return true


func _clear_terrain(layout: MapLayout) -> void:
	## 清除战术区内的地形（回退用）
	for y in range(MapLayout.TACTICAL_MIN_Y, MapLayout.TACTICAL_MAX_Y + 1):
		for x in range(MapLayout.TACTICAL_MIN_X, MapLayout.TACTICAL_MAX_X + 1):
			if layout.get_cell(Vector2i(x, y)) in [MapLayout.CellType.WALL, MapLayout.CellType.ABYSS]:
				layout.set_cell(Vector2i(x, y), MapLayout.CellType.GROUND)


func _compute_placeable_cells(layout: MapLayout) -> void:
	## 计算战术区内所有可放置塔的格子
	layout.placeable_cells.clear()
	for y in range(MapLayout.TACTICAL_MIN_Y, MapLayout.TACTICAL_MAX_Y + 1):
		for x in range(MapLayout.TACTICAL_MIN_X, MapLayout.TACTICAL_MAX_X + 1):
			if layout.get_cell(Vector2i(x, y)) == MapLayout.CellType.GROUND:
				layout.placeable_cells.append(Vector2i(x, y))
