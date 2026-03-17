class_name SlowOnHitComponent
extends Node

@export var slow_ratio: float = 0.3
@export var slow_duration: float = 1.5

func on_hit(target: Node2D, projectile: Node2D) -> void:
	var slow_handler = target.get_node_or_null("SlowHandler")
	if slow_handler:
		var source_id: String = "proj_" + str(projectile.get_instance_id()) if projectile else "proj_unknown"
		slow_handler.apply_timed_slow(slow_ratio, slow_duration, source_id)

func reset() -> void:
	pass
