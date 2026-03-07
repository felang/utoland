# BoomerangWeapon — 发射回旋镖的武器
class_name BoomerangWeapon
extends Weapon

func fire(target: Node2D) -> void:
	var owner_node: Node2D = get_parent() as Node2D
	if not owner_node:
		return
	var final_damage: float = weapon_data.damage * GameData.player_stats.get("damage_mult", 1.0)
	var direction: Vector2 = owner_node.global_position.direction_to(target.global_position)
	var boomerang: BoomerangProjectile = SceneFactory.create_boomerang_projectile()
	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		push_error("BoomerangWeapon: owner has no parent scene")
		return
	scene_parent.add_child(boomerang)
	boomerang.set_player(owner_node)
	boomerang.setup(final_damage, weapon_data.knockback_force, owner_node.global_position, direction)
