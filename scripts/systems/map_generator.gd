class_name MapGenerator
extends RefCounted

## 区域骨架 + 随机填充地图生成器
## 步骤：初始化网格 → 绘制边界 → 边界缺口 → 区域固定墙 → 随机填充 → BFS 连通性验证

var _rng := RandomNumberGenerator.new()


func generate(blueprint: MapBlueprint, seed_value: int = -1) -> MapLayout:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

	var layout := MapLayout.new()
	layout.grid_width = blueprint.grid_width
	layout.grid_height = blueprint.grid_height
	layout.player_spawn = blueprint.player_spawn
	layout.spawn_points = blueprint.spawn_points.duplicate()
	layout.init_grid()

	_draw_border(layout, blueprint)
	_draw_skeletons(layout, blueprint)
	_random_fill(layout, blueprint)
	_ensure_connectivity(layout, blueprint)
	return layout


func _draw_border(layout: MapLayout, blueprint: MapBlueprint) -> void:
	var w := layout.grid_width
	var h := layout.grid_height
	var gap := blueprint.border_gap_size
	var half_gap := gap / 2

	# 绘制四面边界墙
	for x in range(w):
		layout.set_cell(Vector2i(x, 0), MapLayout.CellType.OBSTACLE)
		layout.set_cell(Vector2i(x, h - 1), MapLayout.CellType.OBSTACLE)
	for y in range(h):
		layout.set_cell(Vector2i(0, y), MapLayout.CellType.OBSTACLE)
		layout.set_cell(Vector2i(w - 1, y), MapLayout.CellType.OBSTACLE)

	# 在刷怪点处开缺口
	for dir in blueprint.spawn_points:
		var sp: Vector2i = blueprint.spawn_points[dir]
		for offset in range(-half_gap, half_gap + 1):
			if dir == "north" or dir == "south":
				var gx := clampi(sp.x + offset, 0, w - 1)
				layout.set_cell(Vector2i(gx, sp.y), MapLayout.CellType.GROUND)
			else:
				var gy := clampi(sp.y + offset, 0, h - 1)
				layout.set_cell(Vector2i(sp.x, gy), MapLayout.CellType.GROUND)


func _draw_skeletons(layout: MapLayout, blueprint: MapBlueprint) -> void:
	for zone in blueprint.zones:
		for wall_offset in zone.fixed_walls:
			var pos := zone.origin + wall_offset
			layout.set_cell(pos, MapLayout.CellType.OBSTACLE)


func _random_fill(layout: MapLayout, blueprint: MapBlueprint) -> void:
	for zone in blueprint.zones:
		if zone.fill_count == Vector2i.ZERO:
			continue
		var count := _rng.randi_range(zone.fill_count.x, zone.fill_count.y)
		var placed := 0
		var attempts := 0
		var max_attempts := count * 10
		while placed < count and attempts < max_attempts:
			attempts += 1
			var rx := _rng.randi_range(0, zone.size.x - 1)
			var ry := _rng.randi_range(0, zone.size.y - 1)
			var pos := zone.origin + Vector2i(rx, ry)
			if not _can_place_fill(layout, pos, zone, blueprint):
				continue
			layout.set_cell(pos, MapLayout.CellType.OBSTACLE)
			placed += 1


func _can_place_fill(layout: MapLayout, pos: Vector2i, zone: ZoneData, blueprint: MapBlueprint) -> bool:
	if not layout.is_ground(pos):
		return false
	# 保护玩家出生点周围 1 格
	if abs(pos.x - blueprint.player_spawn.x) <= 1 and abs(pos.y - blueprint.player_spawn.y) <= 1:
		return false
	# 保护刷怪点
	for sp in blueprint.spawn_points.values():
		if pos == sp:
			return false
	# 固定墙间距约束
	if zone.fill_margin > 0:
		for wall_offset in zone.fixed_walls:
			var wall_pos := zone.origin + wall_offset
			var dist := absi(pos.x - wall_pos.x) + absi(pos.y - wall_pos.y)
			if dist <= zone.fill_margin:
				return false
	return true


func _ensure_connectivity(layout: MapLayout, blueprint: MapBlueprint) -> void:
	if _is_connected(layout, blueprint):
		return
	# 连通性验证失败：移除随机填充的障碍物（保留固定墙）
	for zone in blueprint.zones:
		if zone.fill_count == Vector2i.ZERO:
			continue
		var fixed_set := {}
		for w in zone.fixed_walls:
			fixed_set[zone.origin + w] = true
		for y in range(zone.size.y):
			for x in range(zone.size.x):
				var pos := zone.origin + Vector2i(x, y)
				if layout.get_cell(pos) == MapLayout.CellType.OBSTACLE and not fixed_set.has(pos):
					layout.set_cell(pos, MapLayout.CellType.GROUND)


func _is_connected(layout: MapLayout, blueprint: MapBlueprint) -> bool:
	var visited := {}
	var queue: Array[Vector2i] = [blueprint.player_spawn]
	visited[blueprint.player_spawn] = true
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		for dir in dirs:
			var next: Vector2i = current + dir
			if visited.has(next):
				continue
			if layout.is_ground(next):
				visited[next] = true
				queue.append(next)
	for sp in blueprint.spawn_points.values():
		if not visited.has(sp):
			return false
	return true
