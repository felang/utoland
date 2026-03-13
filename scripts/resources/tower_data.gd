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

# 玫瑰（连发）
@export var burst_count: int = 3
@export var burst_interval: float = 0.15

# 藤蔓（定身）
@export var trap_duration_per_level: PackedFloat32Array = []
@export var trap_cooldown: float = 8.0

# 蒲公英（击退）
@export var knockback_force_per_level: PackedFloat32Array = []
@export var knockback_interval: float = 5.0

# 猪笼草（抓取）
@export var grab_dps_per_level: PackedFloat32Array = []
@export var digest_duration_per_level: PackedFloat32Array = []

# 荆棘（反伤）
@export var reflect_ratio_per_level: PackedFloat32Array = []

# 橡树（减伤光环）
@export var aura_reduction_per_level: PackedFloat32Array = []

# 向日葵（产金）
@export var generate_amount_per_level: PackedFloat32Array = []
@export var generate_interval_per_level: PackedFloat32Array = []

# 薄荷（增益光环）
@export var buff_damage_mult_per_level: PackedFloat32Array = []
@export var buff_speed_mult_per_level: PackedFloat32Array = []

# 治愈花（治疗）
@export var heal_amount_per_level: PackedFloat32Array = []
@export var heal_interval_per_level: PackedFloat32Array = []

# 爆竹竹（自爆）
@export var charge_time: float = 15.0
@export var explosion_damage_per_level: PackedFloat32Array = []
@export var explosion_range_per_level: PackedFloat32Array = []
