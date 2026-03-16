class_name WeaponData
extends Resource

@export_group("基础信息")
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_path: String = ""

@export_group("攻击模式")
@export var attack_mode: int = 0  # 0=RANGED, 1=MELEE

@export_group("等级系统")
@export var max_level: int = 3
@export var damage_per_level: PackedFloat32Array = []
@export var fire_rate_per_level: PackedFloat32Array = []
@export var weapon_range_per_level: PackedFloat32Array = []
@export var sell_price_per_level: PackedInt32Array = PackedInt32Array([])

@export_group("投射物配置（远程）")
@export var projectile_data: ProjectileData = null

@export_group("近战配置")
@export var melee_config: MeleeConfig = null
