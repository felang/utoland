# Hitbox — 携带伤害数据的碰撞检测组件，挂载于投射物和敌人接触碰撞体
# 本身为被动数据载体，不处理碰撞事件；碰撞检测由 Hurtbox 负责
class_name Hitbox
extends Area2D

@export var damage: float = 0.0
@export var knockback_force: float = 0.0
# 碰撞层在 .tscn 中配置，不在脚本里硬编码
