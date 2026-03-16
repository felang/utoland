class_name WeaponData
extends Resource

@export_group("基础信息")
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_path: String = ""
@export var weapon_type: String = ""
@export var projectile_type: String = "bullet"

@export_group("等级系统")
@export var max_level: int = 3
@export var damage_per_level: PackedFloat32Array = []
@export var fire_rate_per_level: PackedFloat32Array = []
@export var weapon_range_per_level: PackedFloat32Array = []
@export var sell_price_per_level: PackedInt32Array = PackedInt32Array([])

@export_group("通用属性")
@export var knockback_force: float = 40.0
@export var bullet_speed: float = 300.0

@export_group("子弹专有")
@export var bullet_count: int = 1

@export_group("回旋镖专有")
@export var boomerang_speed: float = 175.0
@export var outbound_distance: float = 100.0
@export var return_speed_mult: float = 1.3
@export var boomerang_max_lifetime: float = 5.0
