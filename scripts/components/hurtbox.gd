# Hurtbox — 受击检测组件，挂载于玩家和敌人
# 监听进入的 Area2D，若为 Hitbox 则读取伤害数据并发射 hit_taken 信号
# 宿主（Player/Enemy）连接此信号来处理受伤逻辑
class_name Hurtbox
extends Area2D

signal hit_taken(damage: float, knockback: Vector2)

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if not area is Hitbox:
		return
	var dir: Vector2 = area.global_position.direction_to(global_position)
	hit_taken.emit(area.damage, dir * area.knockback_force)
