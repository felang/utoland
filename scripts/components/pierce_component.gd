class_name PierceComponent
extends Node

signal pierce_exhausted

@export var max_pierce_count: int = 0
var manages_lifecycle: bool = true
var _hit_count: int = 0

func on_hit(target: Node2D, projectile: Node2D) -> void:
	_hit_count += 1
	if _hit_count > max_pierce_count:
		if projectile:
			projectile._should_destroy = true
		pierce_exhausted.emit()

func reset() -> void:
	_hit_count = 0
