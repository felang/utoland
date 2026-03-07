# Projectile — 所有投射物的基类
# 持有 Hitbox 子节点，setup() 统一设置位置和伤害；子类覆盖 _on_setup() 实现飞行逻辑
class_name Projectile
extends Node2D

var hitbox: Hitbox

func _ready() -> void:
	if has_node("Hitbox"):
		hitbox = $Hitbox

func setup(damage: float, knockback_force: float, from: Vector2, direction: Vector2) -> void:
	global_position = from
	if hitbox == null and has_node("Hitbox"):
		hitbox = $Hitbox
	hitbox.damage = damage
	hitbox.knockback_force = knockback_force
	_on_setup(direction)

func _on_setup(_direction: Vector2) -> void:
	pass  # 子类实现
