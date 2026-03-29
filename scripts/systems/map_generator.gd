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

	# 1. 全部填 BORDER（完整边界墙）
	_fill_borders(layout)

	# 2. 内部填 GROUND
	_fill_ground(layout)

	# 3. 选模板 → 渲染地形 + 开刷怪口
	var template: MapTemplate = null
	if not config.templates.is_empty():
		template = config.templates[_rng.randi_range(0, config.templates.size() - 1)]

	if template:
		# 渲染模板地形
		_template_renderer.render(template, layout)
		# 在边界墙上开刷怪口
		_open_spawn_gates(layout, template)

	# 4. Prefab 散布 + 连通性验证
	var success := _try_scatter_with_connectivity(layout, config, template)
	if not success:
		pass  # 保底：模板地形在，但没有额外 Prefab

	# 5. 计算可放塔格子
	_compute_placeable_cells(layout)
	return layout


func apply_to_tilemap(map_scene: Node, layout: MapLayout, _config: MapGeneratorConfig) -> void:
	var ground_layer: TileMapLayer = map_scene.get_node("Ground")
	var terrain_layer: TileMapLayer = map_scene.get_node("Terrain")

	# luminara tileset source_id=1
	var src_id := 1
	var ground_tile := Vector2i(0, 0)
	var border_tile := Vector2i(1, 0)
	var wall_tile := Vector2i(2, 0)
	var abyss_tile := Vector2i(3, 0)

	for gy in range(MapLayout.PLAYABLE_HEIGHT):
		for gx in range(MapLayout.PLAYABLE_WIDTH):
			var tile_pos := Vector2i(MapLayout.PLAYABLE_ORIGIN_X + gx, MapLayout.PLAYABLE_ORIGIN_Y + gy)
			var cell := layout.get_cell(Vector2i(gx, gy))
			match cell:
				MapLayout.CellType.GROUND, MapLayout.CellType.SPAWN_ZONE:
					ground_layer.set_cell(tile_pos, src_id, ground_tile)
				MapLayout.CellType.BORDER:
					ground_layer.set_cell(tile_pos, src_id, ground_tile)
					terrain_layer.set_cell(tile_pos, src_id, border_tile)
				MapLayout.CellType.WALL:
					ground_layer.set_cell(tile_pos, src_id, ground_tile)
					terrain_layer.set_cell(tile_pos, src_id, wall_tile)
				MapLayout.CellType.ABYSS:
					terrain_layer.set_cell(tile_pos, src_id, abyss_tile)


# === 边界和地面 ===

func _fill_borders(layout: MapLayout) -> void:
	## 外围 1 格全部填 BORDER
	for x in range(MapLayout.PLAYABLE_WIDTH):
		layout.set_cell(Vector2i(x, 0), MapLayout.CellType.BORDER)
		layout.set_cell(Vector2i(x, MapLayout.PLAYABLE_HEIGHT - 1), MapLayout.CellType.BORDER)
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		layout.set_cell(Vector2i(0, y), MapLayout.CellType.BORDER)
		layout.set_cell(Vector2i(MapLayout.PLAYABLE_WIDTH - 1, y), MapLayout.CellType.BORDER)


func _fill_ground(layout: MapLayout) -> void:
	## 边界内全部填 GROUND（不再有刷怪区分区）
	for y in range(1, MapLayout.PLAYABLE_HEIGHT - 1):
		for x in range(1, MapLayout.PLAYABLE_WIDTH - 1):
			layout.set_cell(Vector2i(x, y), MapLayout.CellType.GROUND)


# === 刷怪口 ===

func _open_spawn_gates(layout: MapLayout, template: MapTemplate) -> void:
	## 在边界墙上开缺口，同时生成刷怪点
	for gate in template.spawn_gates:
		var gate_cells := _get_gate_cells(gate)
		for cell in gate_cells:
			# 边界墙变成 SPAWN_ZONE（标记为刷怪入口）
			layout.set_cell(cell, MapLayout.CellType.SPAWN_ZONE)
			# 刷怪点 = 缺口中心
		# 刷怪点取缺口中心格
		if gate_cells.size() > 0:
			var center_idx := gate_cells.size() / 2
			layout.spawn_points.append(gate_cells[center_idx])


func _get_gate_cells(gate: SpawnGate) -> Array[Vector2i]:
	## 计算刷怪口在边界墙上的格子坐标
	var cells: Array[Vector2i] = []
	var half_w := gate.width / 2

	match gate.edge:
		SpawnGate.Edge.TOP:
			var center_x := int(1 + gate.position * (MapLayout.PLAYABLE_WIDTH - 3))
			for dx in range(-half_w, half_w + 1):
				var x := clampi(center_x + dx, 1, MapLayout.PLAYABLE_WIDTH - 2)
				cells.append(Vector2i(x, 0))
		SpawnGate.Edge.BOTTOM:
			var center_x := int(1 + gate.position * (MapLayout.PLAYABLE_WIDTH - 3))
			for dx in range(-half_w, half_w + 1):
				var x := clampi(center_x + dx, 1, MapLayout.PLAYABLE_WIDTH - 2)
				cells.append(Vector2i(x, MapLayout.PLAYABLE_HEIGHT - 1))
		SpawnGate.Edge.LEFT:
			var center_y := int(1 + gate.position * (MapLayout.PLAYABLE_HEIGHT - 3))
			for dy in range(-half_w, half_w + 1):
				var y := clampi(center_y + dy, 1, MapLayout.PLAYABLE_HEIGHT - 2)
				cells.append(Vector2i(0, y))
		SpawnGate.Edge.RIGHT:
			var center_y := int(1 + gate.position * (MapLayout.PLAYABLE_HEIGHT - 3))
			for dy in range(-half_w, half_w + 1):
				var y := clampi(center_y + dy, 1, MapLayout.PLAYABLE_HEIGHT - 2)
				cells.append(Vector2i(MapLayout.PLAYABLE_WIDTH - 1, y))

	return cells


# === Prefab 散布 + 连通性 ===

func _try_scatter_with_connectivity(layout: MapLayout, config: MapGeneratorConfig, template: MapTemplate) -> bool:
	if config.prefabs.is_empty():
		return true

	var base_layout := _clone_layout(layout)
	var prefab_count := _rng.randi_range(config.total_prefab_count.x, config.total_prefab_count.y)

	for retry in range(5):
		var attempt := _clone_layout(base_layout)
		_scatter_prefabs(attempt, config, prefab_count)
		if _validate_connectivity(attempt):
			_copy_grid(attempt, layout)
			return true
		prefab_count = maxi(prefab_count - 2, 0)

	return false


func _scatter_prefabs(layout: MapLayout, config: MapGeneratorConfig, count: int) -> void:
	## 在战术区散布预制件，避开 PLAZA 和中心安全区
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


# === 工具方法 ===

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
	for y in range(1, MapLayout.PLAYABLE_HEIGHT - 1):
		for x in range(1, MapLayout.PLAYABLE_WIDTH - 1):
			if layout.get_cell(Vector2i(x, y)) in [MapLayout.CellType.WALL, MapLayout.CellType.ABYSS]:
				layout.set_cell(Vector2i(x, y), MapLayout.CellType.GROUND)


func _compute_placeable_cells(layout: MapLayout) -> void:
	layout.placeable_cells.clear()
	for y in range(1, MapLayout.PLAYABLE_HEIGHT - 1):
		for x in range(1, MapLayout.PLAYABLE_WIDTH - 1):
			if layout.get_cell(Vector2i(x, y)) == MapLayout.CellType.GROUND:
				layout.placeable_cells.append(Vector2i(x, y))
