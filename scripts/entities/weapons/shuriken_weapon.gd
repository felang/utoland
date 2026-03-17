# ShurikenWeapon — 手里剑武器
# 发射时漂浮精灵隐藏，冷却结束后恢复
class_name ShurikenWeapon
extends Weapon

func _on_attack_fired(target: Node2D, proj_data: ProjectileData) -> void:
	if not owner_node:
		return
	var fire_pos: Vector2 = get_fire_position()
	var direction: Vector2 = fire_pos.direction_to(target.global_position)
	var damage: float = attacker.get_final_damage()
	var extra_pierce: int = 0
	var proj: ProjectileBase = SceneFactory.create_projectile(proj_data, damage, fire_pos, direction, extra_pierce)
	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		return
	scene_parent.add_child(proj)
	projectile_created.emit(proj)
	# 隐藏漂浮精灵
	if sprite and is_instance_valid(sprite):
		sprite.visible = false
	# 冷却结束恢复精灵
	_schedule_sprite_restore()
	AudioManager.play("shoot")

func _schedule_sprite_restore() -> void:
	if not is_inside_tree():
		return
	var cooldown: float = attacker.get_final_cooldown()
	get_tree().create_timer(cooldown * 0.9).timeout.connect(func():
		if sprite and is_instance_valid(sprite):
			sprite.visible = true
	, CONNECT_ONE_SHOT)
