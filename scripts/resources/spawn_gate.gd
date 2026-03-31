class_name SpawnGate
extends Resource

## 刷怪口：边界墙上的缺口，敌人从这里进入地图

enum Edge { TOP, BOTTOM, LEFT, RIGHT }

@export var edge: Edge = Edge.TOP
@export var position: float = 0.5  # 沿边缘的归一化位置 0~1
@export var width: int = 3         # 缺口宽度（格数）
