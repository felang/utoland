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
