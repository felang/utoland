class_name SpawnPhaseData
extends Resource

## 该阶段占波次总时长的比例（所有阶段之和 = 1.0）
@export var duration_ratio: float = 0.5
## 该阶段的生成间隔（秒）
@export var spawn_interval: float = 1.0
## 该阶段的敌人权重（留空则继承波次级别的 enemy_weights）
@export var enemy_weights: Dictionary = {}
