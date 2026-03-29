class_name TerrainFeature
extends Resource

## 地图模板中的单个地形元素

enum FeatureType { RIVER, WALL_BAND, CORRIDOR, PLAZA }
enum FeatureShape { LINE, RECT, RING }

@export var type: FeatureType = FeatureType.RIVER
@export var shape: FeatureShape = FeatureShape.LINE
@export var start: Vector2 = Vector2.ZERO
@export var end: Vector2 = Vector2.ONE
@export var width: int = 1
@export var gaps: Array[float] = []
@export var gap_width: int = 2
@export var size: Vector2i = Vector2i(6, 6)
@export var center: Vector2 = Vector2(0.5, 0.5)
