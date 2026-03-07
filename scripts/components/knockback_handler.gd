class_name KnockbackHandler
extends Node

# 击退处理组件 — 管理 tween 击退效果

var _knockback_tween: Tween = null

func apply_knockback(direction: Vector2) -> void:
	var owner_node: Node2D = get_parent() as Node2D
	if not owner_node:
		return

	var config: Dictionary = GameConfig.EFFECTS["knockback"]
	if _knockback_tween and _knockback_tween.is_valid():
		_knockback_tween.kill()
	_knockback_tween = owner_node.create_tween()
	var target_pos: Vector2 = owner_node.global_position + direction * config["distance"]
	_knockback_tween.tween_property(owner_node, "global_position", target_pos, config["duration"]).set_ease(Tween.EASE_OUT)

func kill_tween() -> void:
	if _knockback_tween and _knockback_tween.is_valid():
		_knockback_tween.kill()
