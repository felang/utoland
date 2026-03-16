class_name ProjectileData
extends Resource

@export_group("飞行参数")
@export var speed: float = 300.0
@export var lifetime: float = 5.0

@export_group("视觉")
@export var sprite_path: String = ""
@export var projectile_scene: PackedScene = null
@export var trail_enabled: bool = true
@export var trail_config: EffectConfigData = null

@export_group("命中效果")
@export var knockback_force: float = 0.0
@export var base_pierce_count: int = 0
@export var slow_ratio: float = 0.0
@export var slow_duration: float = 0.0
