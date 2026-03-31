class_name TemplateRenderer
extends RefCounted

## 将 MapTemplate 的 TerrainFeature 渲染到 MapLayout 网格

var _plaza_cells: Array[Vector2i] = []  # PLAZA 区域坐标，Prefab 散布时排除


## 将模板的所有 feature 渲染到 layout
func render(template: MapTemplate, layout: MapLayout) -> void:
	_plaza_cells.clear()
	for feature in template.features:
		_render_feature(feature, layout)
	_ensure_player_spawn_safe(layout)


## 获取 PLAZA 区域（Prefab 散布时排除）
func get_plaza_cells() -> Array[Vector2i]:
	return _plaza_cells


func _render_feature(feature: TerrainFeature, layout: MapLayout) -> void:
	match feature.shape:
		TerrainFeature.FeatureShape.LINE:
			_render_line(feature, layout)
		TerrainFeature.FeatureShape.RECT:
			_render_rect(feature, layout)
		TerrainFeature.FeatureShape.RING:
			_render_ring(feature, layout)


## 归一化坐标 → 战术区格子坐标
func _normalized_to_grid(normalized: Vector2) -> Vector2i:
	var x := int(MapLayout.TACTICAL_MIN_X + normalized.x * (MapLayout.TACTICAL_MAX_X - MapLayout.TACTICAL_MIN_X))
	var y := int(MapLayout.TACTICAL_MIN_Y + normalized.y * (MapLayout.TACTICAL_MAX_Y - MapLayout.TACTICAL_MIN_Y))
	return Vector2i(clampi(x, MapLayout.TACTICAL_MIN_X, MapLayout.TACTICAL_MAX_X),
					clampi(y, MapLayout.TACTICAL_MIN_Y, MapLayout.TACTICAL_MAX_Y))


## 检查坐标是否在战术区内
func _is_in_tactical(pos: Vector2i) -> bool:
	return (pos.x >= MapLayout.TACTICAL_MIN_X and pos.x <= MapLayout.TACTICAL_MAX_X
		and pos.y >= MapLayout.TACTICAL_MIN_Y and pos.y <= MapLayout.TACTICAL_MAX_Y)


## 获取 feature type 对应的 CellType
func _get_cell_type(feature: TerrainFeature) -> MapLayout.CellType:
	match feature.type:
		TerrainFeature.FeatureType.RIVER:
			return MapLayout.CellType.ABYSS
		TerrainFeature.FeatureType.WALL_BAND:
			return MapLayout.CellType.WALL
		_:
			return MapLayout.CellType.WALL


## Bresenham 直线光栅化 + 宽度扩展
func _render_line(feature: TerrainFeature, layout: MapLayout) -> void:
	var p0 := _normalized_to_grid(feature.start)
	var p1 := _normalized_to_grid(feature.end)
	var line_cells := _bresenham(p0, p1)
	var total_len := line_cells.size()

	var cell_type := _get_cell_type(feature)
	var is_corridor := feature.type == TerrainFeature.FeatureType.CORRIDOR

	for i in range(total_len):
		var progress: float = float(i) / max(total_len - 1, 1)
		# 检查是否在缺口内
		if _is_in_gap(progress, feature.gaps, feature.gap_width, total_len):
			continue

		var center_cell: Vector2i = line_cells[i]
		if is_corridor:
			_render_corridor_cross_section(center_cell, p0, p1, feature.width, layout)
		else:
			_render_wide_line_point(center_cell, p0, p1, feature.width, cell_type, layout)


## 检查某个进度位置是否在缺口内
func _is_in_gap(progress: float, gaps: Array[float], gap_width_cells: int, total_len: int) -> bool:
	if total_len <= 0:
		return false
	var gap_half := float(gap_width_cells) / float(total_len) / 2.0
	for gap_pos in gaps:
		if abs(progress - gap_pos) <= gap_half:
			return true
	return false


## 在线段某点处垂直方向扩展宽度
func _render_wide_line_point(center: Vector2i, p0: Vector2i, p1: Vector2i, width: int, cell_type: MapLayout.CellType, layout: MapLayout) -> void:
	# 计算线段方向的法线（垂直方向）
	var dir := Vector2(p1 - p0).normalized()
	var normal := Vector2(-dir.y, dir.x)
	# 如果是水平/垂直线，法线直接取正交方向
	if abs(normal.x) < 0.01:
		normal = Vector2(0, 1) if normal.y >= 0 else Vector2(0, -1)
	elif abs(normal.y) < 0.01:
		normal = Vector2(1, 0) if normal.x >= 0 else Vector2(1, 0)

	var half_w := (width - 1) / 2
	for offset in range(-half_w, half_w + 1):
		var pos := center + Vector2i(roundi(normal.x * offset), roundi(normal.y * offset))
		if _is_in_tactical(pos) and layout.get_cell(pos) == MapLayout.CellType.GROUND:
			layout.set_cell(pos, cell_type)


## 走廊横截面：中间 GROUND，两侧 WALL
func _render_corridor_cross_section(center: Vector2i, p0: Vector2i, p1: Vector2i, corridor_width: int, layout: MapLayout) -> void:
	var dir := Vector2(p1 - p0).normalized()
	var normal := Vector2(-dir.y, dir.x)
	if abs(normal.x) < 0.01:
		normal = Vector2(0, 1)
	elif abs(normal.y) < 0.01:
		normal = Vector2(1, 0)

	var half_corridor := (corridor_width - 1) / 2
	var wall_offset := half_corridor + 1
	# 两侧墙壁
	for side in [-1, 1]:
		var wall_pos := center + Vector2i(roundi(normal.x * wall_offset * side), roundi(normal.y * wall_offset * side))
		if _is_in_tactical(wall_pos) and layout.get_cell(wall_pos) == MapLayout.CellType.GROUND:
			layout.set_cell(wall_pos, MapLayout.CellType.WALL)


## Bresenham 直线算法
func _bresenham(p0: Vector2i, p1: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dx: int = absi(p1.x - p0.x)
	var dy: int = absi(p1.y - p0.y)
	var sx: int = 1 if p0.x < p1.x else -1
	var sy: int = 1 if p0.y < p1.y else -1
	var err: int = dx - dy
	var x: int = p0.x
	var y: int = p0.y
	while true:
		result.append(Vector2i(x, y))
		if x == p1.x and y == p1.y:
			break
		var e2: int = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
	return result


## 玩家出生点安全：确保 3×3 区域为 GROUND
func _ensure_player_spawn_safe(layout: MapLayout) -> void:
	var spawn := layout.player_spawn
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var pos := Vector2i(spawn.x + dx, spawn.y + dy)
			if layout.get_cell(pos) != MapLayout.CellType.GROUND:
				layout.set_cell(pos, MapLayout.CellType.GROUND)


func _render_rect(feature: TerrainFeature, layout: MapLayout) -> void:
	var center_pos := _normalized_to_grid(feature.center)
	var half_w := feature.size.x / 2
	var half_h := feature.size.y / 2

	var cell_type := _get_cell_type(feature)
	var is_plaza := feature.type == TerrainFeature.FeatureType.PLAZA

	for dy in range(-half_h, half_h + 1):
		for dx in range(-half_w, half_w + 1):
			var pos := Vector2i(center_pos.x + dx, center_pos.y + dy)
			if not _is_in_tactical(pos):
				continue
			if is_plaza:
				_plaza_cells.append(pos)
			elif layout.get_cell(pos) == MapLayout.CellType.GROUND:
				layout.set_cell(pos, cell_type)


func _render_ring(feature: TerrainFeature, layout: MapLayout) -> void:
	var center_pos := _normalized_to_grid(feature.center)
	var half_w := feature.size.x / 2
	var half_h := feature.size.y / 2
	var ring_width := feature.width

	var cell_type := _get_cell_type(feature)

	# 计算环的总周长用于缺口位置计算
	var perimeter := 2 * (feature.size.x + feature.size.y)
	var ring_cells: Array[Dictionary] = []  # {pos: Vector2i, progress: float}
	var accumulated := 0

	# 按顺时针收集环上所有格子：上→右→下→左
	# 上边
	for dx in range(-half_w, half_w + 1):
		for dw in range(ring_width):
			var pos := Vector2i(center_pos.x + dx, center_pos.y - half_h + dw)
			ring_cells.append({"pos": pos, "progress": float(accumulated) / perimeter})
		accumulated += 1
	# 右边
	for dy in range(-half_h + 1, half_h):
		for dw in range(ring_width):
			var pos := Vector2i(center_pos.x + half_w - dw, center_pos.y + dy)
			ring_cells.append({"pos": pos, "progress": float(accumulated) / perimeter})
		accumulated += 1
	# 下边
	for dx in range(half_w, -half_w - 1, -1):
		for dw in range(ring_width):
			var pos := Vector2i(center_pos.x + dx, center_pos.y + half_h - dw)
			ring_cells.append({"pos": pos, "progress": float(accumulated) / perimeter})
		accumulated += 1
	# 左边
	for dy in range(half_h - 1, -half_h, -1):
		for dw in range(ring_width):
			var pos := Vector2i(center_pos.x - half_w + dw, center_pos.y + dy)
			ring_cells.append({"pos": pos, "progress": float(accumulated) / perimeter})
		accumulated += 1

	# 渲染，跳过缺口
	for entry in ring_cells:
		var pos: Vector2i = entry["pos"]
		var progress: float = entry["progress"]
		if not _is_in_tactical(pos):
			continue
		if _is_in_gap(progress, feature.gaps, feature.gap_width, perimeter):
			continue
		if layout.get_cell(pos) == MapLayout.CellType.GROUND:
			layout.set_cell(pos, cell_type)
