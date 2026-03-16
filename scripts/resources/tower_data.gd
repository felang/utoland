class_name TowerData
extends Resource

@export_group("基础信息")
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_path: String = ""

@export_group("等级系统")
@export var max_level: int = 3
@export var hp_per_level: PackedFloat32Array = []
@export var damage_per_level: PackedFloat32Array = []
@export var fire_rate_per_level: PackedFloat32Array = []
@export var attack_range_per_level: PackedFloat32Array = []
@export var slow_ratio_per_level: PackedFloat32Array = []
@export var slow_duration_per_level: PackedFloat32Array = []
@export var sell_price_per_level: PackedInt32Array = PackedInt32Array([])

@export_group("投射物配置（射手塔）")
@export var projectile_data: ProjectileData = null

@export_group("向日葵专有")
@export var generate_amount_per_level: PackedFloat32Array = []
@export var generate_interval_per_level: PackedFloat32Array = []
