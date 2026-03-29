class_name MapGenerator
extends RefCounted

## 随机地图生成器

enum SymmetryMode { RANDOM, MIRROR_X, ROTATE_180 }

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


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


func _try_generate_terrain(_layout: MapLayout, _config: MapGeneratorConfig) -> bool:
	## 占位，Task 4 实现地形生成
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
