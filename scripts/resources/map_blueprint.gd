class_name MapBlueprint
extends Resource

@export var id: String = ""
@export var grid_width: int = 40
@export var grid_height: int = 24
@export var zones: Array[ZoneData] = []
@export var spawn_points: Dictionary = {}
@export var player_spawn: Vector2i = Vector2i(19, 12)
@export var border_gap_size: int = 3
