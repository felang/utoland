class_name MapGeneratorConfig
extends Resource

## 随机地图生成参数配置

# 模板系统
@export var templates: Array[MapTemplate] = []
@export var total_prefab_count: Vector2i = Vector2i(8, 15)

# Prefab 池
@export var prefabs: Array[MapPrefab] = []

# 刷怪点
@export var spawns_per_edge: Vector2i = Vector2i(1, 2)
@export var corner_spawn_chance: float = 0.5
@export var min_spawn_spacing: int = 4

# Terrain ID
@export var grass_terrain_id: int = 0
@export var water_terrain_id: int = 1
@export var wall_terrain_id: int = 2
@export var border_terrain_id: int = 3
