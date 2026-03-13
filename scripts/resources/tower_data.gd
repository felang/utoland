class_name TowerData
extends Resource

@export var id: String = ""
@export var display_name: String = ""

# === 等级系统 ===
@export var max_level: int = 5
@export var hp_per_level: PackedFloat32Array = []
@export var damage_per_level: PackedFloat32Array = []
@export var fire_rate_per_level: PackedFloat32Array = []
@export var attack_range_per_level: PackedFloat32Array = []
@export var slow_ratio_per_level: PackedFloat32Array = []
@export var shop_price_per_level: PackedInt32Array = []
@export var place_cost_per_level: PackedInt32Array = []
@export var milestones: Dictionary = {}

# === 旧平面字段（暂保留，Task 5 移除）===
@export var hp: float = 100.0
@export var damage: float = 0.0
@export var fire_rate: float = 0.0
@export var attack_range: float = 0.0
@export var shop_price_min: int = 35
@export var shop_price_max: int = 45

# 减速塔特有
@export var slow_percent: float = 0.0
