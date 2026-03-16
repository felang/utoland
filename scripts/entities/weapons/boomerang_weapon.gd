# BoomerangWeapon — 发射回旋镖的武器
class_name BoomerangWeapon
extends Weapon

func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var final_damage: float = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var fire_pos: Vector2 = get_fire_position()
	var direction: Vector2 = fire_pos.direction_to(target.global_position)
	var boomerang: BoomerangProjectile = SceneFactory.create_boomerang_projectile()
	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		push_error("BoomerangWeapon: owner has no parent scene")
		return
	scene_parent.add_child(boomerang)
	boomerang.set_player(owner_node)
	boomerang.weapon_data = weapon_data  # 注入 WeaponData
	boomerang.setup(final_damage, weapon_data.knockback_force, fire_pos, direction)
