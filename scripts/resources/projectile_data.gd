class_name ProjectileData
extends Resource

@export_group("飞行参数")
@export var speed: float = 300.0
@export var lifetime: float = 5.0

@export_group("视觉")
@export var sprite_path: String = ""
@export var projectile_scene: PackedScene = null
