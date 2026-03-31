class_name MapLayout
extends RefCounted

## 随机地图生成结果的数据载体

enum CellType { GROUND, BORDER, WALL, ABYSS, SPAWN_ZONE }

const PLAYABLE_WIDTH: int = 40
const PLAYABLE_HEIGHT: int = 24
const PLAYABLE_ORIGIN_X: int = 3
const PLAYABLE_ORIGIN_Y: int = 3

const TACTICAL_MIN_X: int = 3
const TACTICAL_MAX_X: int = 36
const TACTICAL_MIN_Y: int = 3
const TACTICAL_MAX_Y: int = 20

const CENTER_SAFE_MIN_X: int = 14
const CENTER_SAFE_MAX_X: int = 25
const CENTER_SAFE_MIN_Y: int = 9
const CENTER_SAFE_MAX_Y: int = 14

var grid: Array = []
var spawn_points: Array[Vector2i] = []
var placeable_cells: Array[Vector2i] = []
var player_spawn: Vector2i = Vector2i(19, 11)


func _init() -> void:
	_init_grid()


func _init_grid() -> void:
	grid.resize(PLAYABLE_HEIGHT)
	for y in range(PLAYABLE_HEIGHT):
		var row: Array = []
		row.resize(PLAYABLE_WIDTH)
		row.fill(CellType.GROUND)
		grid[y] = row


func get_cell(pos: Vector2i) -> CellType:
	if pos.x < 0 or pos.x >= PLAYABLE_WIDTH or pos.y < 0 or pos.y >= PLAYABLE_HEIGHT:
		return CellType.BORDER
	return grid[pos.y][pos.x]


func set_cell(pos: Vector2i, cell_type: CellType) -> void:
	if pos.x >= 0 and pos.x < PLAYABLE_WIDTH and pos.y >= 0 and pos.y < PLAYABLE_HEIGHT:
		grid[pos.y][pos.x] = cell_type


func is_passable(pos: Vector2i) -> bool:
	var cell := get_cell(pos)
	return cell == CellType.GROUND or cell == CellType.SPAWN_ZONE


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var world_x := (PLAYABLE_ORIGIN_X + grid_pos.x - GameConfig.MAP_GRID_WIDTH / 2.0) * GameConfig.GRID_SIZE + GameConfig.GRID_SIZE / 2.0
	var world_y := (PLAYABLE_ORIGIN_Y + grid_pos.y - GameConfig.MAP_GRID_HEIGHT / 2.0) * GameConfig.GRID_SIZE + GameConfig.GRID_SIZE / 2.0
	return Vector2(world_x, world_y)


func get_spawn_points_world() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for sp in spawn_points:
		result.append(grid_to_world(sp))
	return result


func get_player_spawn_world() -> Vector2:
	return grid_to_world(player_spawn)


func get_placeable_dict() -> Dictionary:
	var dict := {}
	for cell in placeable_cells:
		dict[cell] = true
	return dict
