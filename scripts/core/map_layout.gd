class_name MapLayout
extends RefCounted

enum CellType { GROUND, OBSTACLE }

var grid: Array = []
var spawn_points: Dictionary = {}
var player_spawn: Vector2i = Vector2i(19, 12)
var grid_width: int = 40
var grid_height: int = 24

func init_grid() -> void:
	grid.clear()
	for y in range(grid_height):
		var row: Array = []
		row.resize(grid_width)
		row.fill(CellType.GROUND)
		grid.append(row)

func get_cell(pos: Vector2i) -> int:
	if pos.x < 0 or pos.x >= grid_width or pos.y < 0 or pos.y >= grid_height:
		return CellType.OBSTACLE
	return grid[pos.y][pos.x]

func set_cell(pos: Vector2i, cell_type: int) -> void:
	if pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height:
		grid[pos.y][pos.x] = cell_type

func is_ground(pos: Vector2i) -> bool:
	return get_cell(pos) == CellType.GROUND

func is_placeable(pos: Vector2i) -> bool:
	if not is_ground(pos):
		return false
	if pos == player_spawn:
		return false
	for sp in spawn_points.values():
		if pos == sp:
			return false
	return true

func grid_to_world(pos: Vector2i) -> Vector2:
	var full_x := GameConfig.PLAYABLE_ORIGIN_X + pos.x
	var full_y := GameConfig.PLAYABLE_ORIGIN_Y + pos.y
	var world_x := (full_x - GameConfig.MAP_GRID_WIDTH / 2.0) * GameConfig.GRID_SIZE + GameConfig.GRID_SIZE / 2.0
	var world_y := (full_y - GameConfig.MAP_GRID_HEIGHT / 2.0) * GameConfig.GRID_SIZE + GameConfig.GRID_SIZE / 2.0
	return Vector2(world_x, world_y)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var gx := int(floor((world_pos.x + GameConfig.MAP_HALF_WIDTH) / GameConfig.GRID_SIZE)) - GameConfig.PLAYABLE_ORIGIN_X
	var gy := int(floor((world_pos.y + GameConfig.MAP_HALF_HEIGHT) / GameConfig.GRID_SIZE)) - GameConfig.PLAYABLE_ORIGIN_Y
	return Vector2i(gx, gy)

func get_placeable_dict() -> Dictionary:
	var dict := {}
	for y in range(grid_height):
		for x in range(grid_width):
			var pos := Vector2i(x, y)
			if is_placeable(pos):
				var full_pos := Vector2i(GameConfig.PLAYABLE_ORIGIN_X + x, GameConfig.PLAYABLE_ORIGIN_Y + y)
				dict[full_pos] = true
	return dict

func get_spawn_points_world() -> Dictionary:
	var result := {}
	for dir in spawn_points:
		result[dir] = grid_to_world(spawn_points[dir])
	return result

func get_player_spawn_world() -> Vector2:
	return grid_to_world(player_spawn)
