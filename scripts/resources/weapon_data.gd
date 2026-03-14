class_name WeaponData
extends Resource

@export_group("基础信息")
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_path: String = ""
@export var rarity: int = 0
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

@export_group("激光专有")
@export var beam_range: float = 200.0
@export var beam_width: float = 2.0
@export var beam_duration: float = 0.08

@export_group("火箭专有")
@export var explosion_radius_per_level: PackedFloat32Array = []

@export_group("火焰专有")
@export var flame_cone_angle: float = 45.0

@export_group("闪电专有")
@export var chain_count: int = 3
@export var chain_decay: float = 0.7
@export var chain_range: float = 150.0

@export_group("冰冻专有")
@export var slow_on_hit: float = 0.0
@export var slow_duration: float = 2.0
