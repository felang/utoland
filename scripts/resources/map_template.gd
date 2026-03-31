class_name MapTemplate
extends Resource

## 地图模板骨架：地形 + 刷怪口

@export var id: String = ""
@export var display_name: String = ""
@export var features: Array[TerrainFeature] = []
@export var spawn_gates: Array[SpawnGate] = []
