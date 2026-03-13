# BladeWeapon — 近战圆形瞬时伤害
class_name BladeWeapon
extends Weapon

func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var base_damage: float = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		return
	var melee: MeleeProjectile = SceneFactory.create_melee_projectile()
	melee.melee_radius = get_weapon_range()
	scene_parent.add_child(melee)
	melee.setup(base_damage, weapon_data.knockback_force, owner_node.global_position, Vector2.ZERO)
	AudioManager.play("shoot")
