class_name KnockbackOnHitComponent
extends Node

@export var knockback_force: float = 40.0

func on_hit(target: Node2D, projectile: Node2D) -> void:
	var knockback_handler = target.get_node_or_null("KnockbackHandler")
	if knockback_handler and projectile:
		var direction: Vector2 = projectile.direction if projectile.get("direction") != null else Vector2.ZERO
		knockback_handler.apply_knockback(direction * knockback_force)

func reset() -> void:
	pass
