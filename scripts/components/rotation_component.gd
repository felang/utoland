class_name RotationComponent
extends Node

@export var rotation_speed: float = 10.0

var _sprite: Node2D = null

func on_projectile_setup(projectile: Node2D) -> void:
	_sprite = projectile.get_node_or_null("_PooledSprite")

func _process(delta: float) -> void:
	if _sprite:
		_sprite.rotation += rotation_speed * delta

func reset() -> void:
	_sprite = nil
