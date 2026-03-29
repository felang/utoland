class_name MapGeneratorConfig
extends Resource

## 随机地图生成参数配置

# 模板系统
@export var templates: Array[MapTemplate] = []
@export var total_prefab_count: Vector2i = Vector2i(8, 15)

# Prefab 池
@export var prefabs: Array[MapPrefab] = []
