class_name MapPrefab
extends Resource

## 地形预制件定义

@export var id: String = ""
@export_enum("GROUND", "BORDER", "WALL", "ABYSS", "SPAWN_ZONE") var cell_type: int = 2
@export var cells: Array[Vector2i] = []
@export var rotatable: bool = true
@export var tile_atlas_coords: Vector2i = Vector2i.ZERO


func get_rotated_cells(rotation_steps: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(_rotate_cell(cell, rotation_steps))
	return result


func get_mirrored_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(Vector2i(-cell.x, cell.y))
	return result


func _rotate_cell(cell: Vector2i, steps: int) -> Vector2i:
	var c := cell
	for i in range(steps % 4):
		c = Vector2i(-c.y, c.x)
	return c
