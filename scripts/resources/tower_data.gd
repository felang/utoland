class_name TowerData
extends Resource

@export_group("基础信息")
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_path: String = ""
@export var rarity: int = 0
@export var tag: String = ""

@export_group("等级系统")
@export var max_level: int = 3
@export var hp_per_level: PackedFloat32Array = []
@export var damage_per_level: PackedFloat32Array = []
@export var fire_rate_per_level: PackedFloat32Array = []
@export var attack_range_per_level: PackedFloat32Array = []
@export var slow_ratio_per_level: PackedFloat32Array = []
@export var sell_price_per_level: PackedInt32Array = PackedInt32Array([])

@export_group("玫瑰专有")
@export var burst_count: int = 3
@export var burst_interval: float = 0.15

@export_group("藤蔓专有")
@export var trap_duration_per_level: PackedFloat32Array = []
@export var trap_cooldown: float = 8.0

@export_group("蒲公英专有")
@export var knockback_force_per_level: PackedFloat32Array = []
@export var knockback_interval: float = 5.0

@export_group("猪笼草专有")
@export var grab_dps_per_level: PackedFloat32Array = []
@export var digest_duration_per_level: PackedFloat32Array = []

@export_group("荆棘专有")
@export var reflect_ratio_per_level: PackedFloat32Array = []

@export_group("橡树专有")
@export var aura_reduction_per_level: PackedFloat32Array = []

@export_group("向日葵专有")
@export var generate_amount_per_level: PackedFloat32Array = []
@export var generate_interval_per_level: PackedFloat32Array = []

@export_group("薄荷专有")
@export var buff_damage_mult_per_level: PackedFloat32Array = []
@export var buff_speed_mult_per_level: PackedFloat32Array = []

@export_group("治愈花专有")
@export var heal_amount_per_level: PackedFloat32Array = []
@export var heal_interval_per_level: PackedFloat32Array = []

@export_group("爆竹竹专有")
@export var charge_time: float = 15.0
@export var explosion_damage_per_level: PackedFloat32Array = []
@export var explosion_range_per_level: PackedFloat32Array = []
