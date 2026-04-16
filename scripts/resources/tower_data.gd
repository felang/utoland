class_name TowerData
extends Resource

@export_group("基础信息")
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_path: String = ""
@export var sell_price_per_level: PackedInt32Array = PackedInt32Array([])
@export var hp_per_level: PackedFloat32Array = []
@export var tier: int = 1  # Tier 1-4

@export_group("射击塔配置")
@export var attack_config: AttackConfigData = null
@export var projectile_data: ProjectileData = null
@export var slow_ratio_per_level: PackedFloat32Array = []
@export var slow_duration_per_level: PackedFloat32Array = []

@export_group("生成塔配置")
@export var generator_config: GeneratorConfigData = null
