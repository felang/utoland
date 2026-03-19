class_name TrackingMovementComponent
extends Node

## 追踪移动组件 — 投射物飞行中每帧朝目标调整方向，保证命中
## 与 LinearMovementComponent 互斥，同一投射物场景只挂其中一个

signal lifetime_expired

var speed: float = 300.0
var lifetime: float = 5.0
@export var turn_speed: float = 8.0

var _elapsed: float = 0.0
var _target: Node2D = null

func on_projectile_setup(projectile: Node2D) -> void:
	speed = projectile.data.speed
	lifetime = projectile.data.lifetime
	_target = projectile.target
	_elapsed = 0.0
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	var proj: Node2D = get_parent()
	if not proj:
		return
	# 目标有效且在场景树中时持续调整方向（池化回收的敌人不在树中）
	if _target and is_instance_valid(_target) and _target.is_inside_tree():
		var desired: Vector2 = proj.global_position.direction_to(_target.global_position)
		proj.direction = proj.direction.lerp(desired, turn_speed * delta).normalized()
		proj.rotation = proj.direction.angle()
	# 目标失效时保持最后方向直线飞行
	proj.position += proj.direction * speed * delta
	_elapsed += delta
	if _elapsed >= lifetime:
		lifetime_expired.emit()
		proj.request_destroy()

func reset() -> void:
	_elapsed = 0.0
	_target = null
	set_physics_process(false)
