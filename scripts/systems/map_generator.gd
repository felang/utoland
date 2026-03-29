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


func _try_generate_terrain(layout: MapLayout, config: MapGeneratorConfig) -> bool:
	## 对称模板填充 + 连通性验证
	if config.prefabs.is_empty():
		return true

	# 标准密度尝试 10 次
	for i in range(10):
		var attempt_layout := _clone_layout(layout)
		var symmetry := _pick_symmetry(config)
		_fill_tactical_zone(attempt_layout, config, symmetry, config.max_prefabs_per_block)
		if _validate_connectivity(attempt_layout):
			_copy_terrain(attempt_layout, layout)
			return true

	# 降低密度尝试 5 次
	for i in range(5):
		var attempt_layout := _clone_layout(layout)
		var symmetry := _pick_symmetry(config)
		_fill_tactical_zone(attempt_layout, config, symmetry, config.min_prefabs_per_block)
		if _validate_connectivity(attempt_layout):
			_copy_terrain(attempt_layout, layout)
			return true

	return false


func _clone_layout(layout: MapLayout) -> MapLayout:
	## 复制 layout 用于尝试（保留边界/刷怪区/刷怪点，只复制 grid）
	var clone := MapLayout.new()
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		for x in range(MapLayout.PLAYABLE_WIDTH):
			clone.grid[y][x] = layout.grid[y][x]
	clone.spawn_points = layout.spawn_points.duplicate()
	clone.player_spawn = layout.player_spawn
	return clone


func _copy_terrain(source: MapLayout, target: MapLayout) -> void:
	## 将 source 的战术区地形复制到 target
	for y in range(MapLayout.TACTICAL_MIN_Y, MapLayout.TACTICAL_MAX_Y + 1):
		for x in range(MapLayout.TACTICAL_MIN_X, MapLayout.TACTICAL_MAX_X + 1):
			target.grid[y][x] = source.grid[y][x]


func _pick_symmetry(config: MapGeneratorConfig) -> SymmetryMode:
	## 根据权重随机选择对称模式
	var weights := config.symmetry_weights
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return SymmetryMode.RANDOM

	var roll := _rng.randf() * total
	var cumulative := 0.0
	for i in range(weights.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return i as SymmetryMode
	return SymmetryMode.RANDOM


func _fill_tactical_zone(layout: MapLayout, config: MapGeneratorConfig, symmetry: SymmetryMode, max_per_block: int) -> void:
	## 对每个主块填充预制件，然后镜像到对称块
	var primary_blocks := _get_primary_blocks(symmetry)
	for block_pos in primary_blocks:
		# 空块概率
		if _rng.randf() < config.empty_chance:
			continue

		var count := _rng.randi_range(config.min_prefabs_per_block, max_per_block)
		var placements := _generate_block_placements(layout, config, block_pos, count)
		_apply_placements(layout, placements)

		# 镜像到对称块
		var mirror_block := _get_mirror_block(block_pos, symmetry)
		if mirror_block != Vector2i(-1, -1):
			_mirror_placements(layout, placements, block_pos, mirror_block, symmetry)


func _get_primary_blocks(symmetry: SymmetryMode) -> Array[Vector2i]:
	## 返回需要独立决策的主块列表（col_index, row_index）
	match symmetry:
		SymmetryMode.MIRROR_X:
			# 左侧 + 上下中列，右侧镜像左侧
			return [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(1, 2)]
		SymmetryMode.ROTATE_180:
			# 左上半区，对角镜像
			return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)]
		_:
			# RANDOM：所有 8 个非中心块
			return [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
				Vector2i(0, 1), Vector2i(2, 1),
				Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
			]


func _get_mirror_block(block_pos: Vector2i, symmetry: SymmetryMode) -> Vector2i:
	## 返回对称的镜像块位置，无镜像返回 (-1,-1)
	match symmetry:
		SymmetryMode.MIRROR_X:
			# 左→右镜像：col 0→2, col 2→0, col 1 无镜像
			if block_pos.x == 0:
				return Vector2i(2, block_pos.y)
			elif block_pos.x == 2:
				return Vector2i(0, block_pos.y)
			return Vector2i(-1, -1)
		SymmetryMode.ROTATE_180:
			# 180度旋转：(c,r) → (2-c, 2-r)，中心(1,1)无镜像
			var mirror := Vector2i(2 - block_pos.x, 2 - block_pos.y)
			if mirror == block_pos:
				return Vector2i(-1, -1)
			return mirror
		_:
			return Vector2i(-1, -1)


func _generate_block_placements(layout: MapLayout, config: MapGeneratorConfig, block_pos: Vector2i, count: int) -> Array:
	## 在指定块内生成预制件放置方案
	var placements: Array = []  # Array of {cells: Array[Vector2i], cell_type: int}
	var bounds := layout.get_block_bounds(block_pos.x, block_pos.y)

	for i in range(count):
		var prefab: MapPrefab = config.prefabs[_rng.randi_range(0, config.prefabs.size() - 1)]
		var rotation := 0
		if prefab.rotatable:
			rotation = _rng.randi_range(0, 3)
		var cells := prefab.get_rotated_cells(rotation)

		var placed_cells := _try_place_in_bounds(layout, cells, bounds, prefab.cell_type)
		if not placed_cells.is_empty():
			placements.append({"cells": placed_cells, "cell_type": prefab.cell_type})

	return placements


func _try_place_in_bounds(layout: MapLayout, cells: Array[Vector2i], bounds: Rect2i, cell_type: int) -> Array[Vector2i]:
	## 在块范围内找到有效位置放置预制件，返回世界坐标的 cells
	# 计算预制件的包围盒
	var min_x := 9999
	var min_y := 9999
	var max_x := -9999
	var max_y := -9999
	for c in cells:
		min_x = mini(min_x, c.x)
		min_y = mini(min_y, c.y)
		max_x = maxi(max_x, c.x)
		max_y = maxi(max_y, c.y)

	var prefab_w := max_x - min_x + 1
	var prefab_h := max_y - min_y + 1

	# 可用放置范围
	var place_w := bounds.size.x - prefab_w + 1
	var place_h := bounds.size.y - prefab_h + 1
	if place_w <= 0 or place_h <= 0:
		return []

	# 随机尝试放置
	for attempt in range(10):
		var ox := bounds.position.x + _rng.randi_range(0, place_w - 1) - min_x
		var oy := bounds.position.y + _rng.randi_range(0, place_h - 1) - min_y

		var valid := true
		var world_cells: Array[Vector2i] = []
		for c in cells:
			var wc := Vector2i(ox + c.x, oy + c.y)
			# 检查是否在战术区且当前为 GROUND
			if wc.x < MapLayout.TACTICAL_MIN_X or wc.x > MapLayout.TACTICAL_MAX_X:
				valid = false
				break
			if wc.y < MapLayout.TACTICAL_MIN_Y or wc.y > MapLayout.TACTICAL_MAX_Y:
				valid = false
				break
			if layout.get_cell(wc) != MapLayout.CellType.GROUND:
				valid = false
				break
			world_cells.append(wc)

		if valid:
			return world_cells

	return []


func _apply_placements(layout: MapLayout, placements: Array) -> void:
	## 将放置方案写入 grid
	for placement in placements:
		var cell_type_int: int = placement["cell_type"]
		for cell in placement["cells"]:
			layout.set_cell(cell, cell_type_int as MapLayout.CellType)


func _mirror_placements(layout: MapLayout, placements: Array, src_block: Vector2i, dst_block: Vector2i, symmetry: SymmetryMode) -> void:
	## 将放置方案从源块变换到目标块
	var src_bounds := layout.get_block_bounds(src_block.x, src_block.y)
	var dst_bounds := layout.get_block_bounds(dst_block.x, dst_block.y)

	for placement in placements:
		var cell_type_int: int = placement["cell_type"]
		var src_cells: Array = placement["cells"]

		for cell in src_cells:
			var mirror_pos: Vector2i
			match symmetry:
				SymmetryMode.MIRROR_X:
					# X 轴镜像：在目标块内水平翻转
					var local_x: int = cell.x - src_bounds.position.x
					var local_y: int = cell.y - src_bounds.position.y
					var mirrored_x: int = dst_bounds.position.x + dst_bounds.size.x - 1 - local_x
					var mirrored_y: int = dst_bounds.position.y + local_y
					mirror_pos = Vector2i(mirrored_x, mirrored_y)
				SymmetryMode.ROTATE_180:
					# 180度旋转：在目标块内旋转
					var local_x: int = cell.x - src_bounds.position.x
					var local_y: int = cell.y - src_bounds.position.y
					var rotated_x: int = dst_bounds.position.x + dst_bounds.size.x - 1 - local_x
					var rotated_y: int = dst_bounds.position.y + dst_bounds.size.y - 1 - local_y
					mirror_pos = Vector2i(rotated_x, rotated_y)
				_:
					continue

			if mirror_pos.x >= MapLayout.TACTICAL_MIN_X and mirror_pos.x <= MapLayout.TACTICAL_MAX_X \
				and mirror_pos.y >= MapLayout.TACTICAL_MIN_Y and mirror_pos.y <= MapLayout.TACTICAL_MAX_Y:
				if layout.get_cell(mirror_pos) == MapLayout.CellType.GROUND:
					layout.set_cell(mirror_pos, cell_type_int as MapLayout.CellType)


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
