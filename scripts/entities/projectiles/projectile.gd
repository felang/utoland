# Projectile — 所有投射物的基类
# 持有 Hitbox 子节点，setup() 统一设置位置和伤害；子类覆盖 _on_setup() 实现飞行逻辑
class_name Projectile
extends Node2D

@onready var hitbox: Hitbox = $Hitbox

func setup(damage: float, knockback_force: float, from: Vector2, direction: Vector2) -> void:
	assert(hitbox != null, "Projectile.setup: 缺少 Hitbox 子节点，请检查场景配置")
	global_position = from
	hitbox.damage = damage
	hitbox.knockback_force = knockback_force
	_on_setup(direction)

func _on_setup(_direction: Vector2) -> void:
	pass  # 子类实现
