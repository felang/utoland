class_name LinearMovementComponent
extends Node

signal lifetime_expired

var speed: float = 300.0
var lifetime: float = 5.0
var _elapsed: float = 0.0

func on_projectile_setup(projectile: Node2D) -> void:
	speed = projectile.data.speed
	lifetime = projectile.data.lifetime
	_elapsed = 0.0
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	var proj: Node2D = get_parent()
	if not proj:
		return
	proj.position += proj.direction * speed * delta
	_elapsed += delta
	if _elapsed >= lifetime:
		lifetime_expired.emit()
		proj.request_destroy()

func reset() -> void:
	_elapsed = 0.0
	set_physics_process(false)
