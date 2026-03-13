class_name WeaponData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var projectile_type: String = "bullet"

# === 等级系统 ===
@export var max_level: int = 5
@export var damage_per_level: PackedFloat32Array = []
@export var fire_rate_per_level: PackedFloat32Array = []
@export var weapon_range_per_level: PackedFloat32Array = []
@export var milestones: Dictionary = {}

# === 旧平面字段（暂保留，Task 5 移除）===
@export var fire_rate: float = 0.1
@export var damage: float = 10.0
@export var weapon_range: float = 300.0

# 子弹特有
@export var bullet_count: int = 1
@export var bullet_speed: float = 600.0

# 回旋镖特有
@export var boomerang_speed: float = 350.0
@export var outbound_distance: float = 200.0
@export var return_speed_mult: float = 1.3

# 通用
@export var knockback_force: float = 80.0

# 激光特有
@export var beam_range: float = 400.0
@export var beam_width: float = 2.0
@export var beam_duration: float = 0.08
