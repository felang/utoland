class_name MapGeneratorConfig
extends Resource

## 随机地图生成参数配置

@export var prefabs: Array[MapPrefab] = []
@export var empty_chance: float = 0.35
@export var min_prefabs_per_block: int = 1
@export var max_prefabs_per_block: int = 2
@export var spawns_per_edge: Vector2i = Vector2i(1, 2)
@export var corner_spawn_chance: float = 0.5
@export var min_spawn_spacing: int = 4
@export var symmetry_weights: Array[float] = [0.33, 0.34, 0.33]
@export var ground_tile: Vector2i = Vector2i.ZERO
@export var border_tile: Vector2i = Vector2i.ZERO
@export var wall_tile: Vector2i = Vector2i.ZERO
@export var abyss_tile: Vector2i = Vector2i.ZERO
@export var decoration_tiles: Array[Vector2i] = []
@export var tileset_source_id: int = 0
