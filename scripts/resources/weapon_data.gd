class_name WeaponData
extends Resource

@export_group("基础信息")
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_path: String = ""
@export var sell_price_per_level: PackedInt32Array = PackedInt32Array([])

@export_group("攻击配置")
@export var attack_config: AttackConfigData = null
@export var projectile_data: ProjectileData = null
@export var melee_config: MeleeConfig = null

@export_group("Pivot 配置")
@export var pivot_offset: float = 15.0

@export_group("视觉配置")
@export var sprite_rotation_offset: float = 0.0  # 精灵初始旋转偏移（弧度）
@export var hide_sprite_on_fire: bool = false
@export var sprite_restore_ratio: float = 0.9
