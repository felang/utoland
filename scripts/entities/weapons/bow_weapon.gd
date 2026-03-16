# BowWeapon — 单发射击的基础远程武器
class_name BowWeapon
extends Weapon

func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var base_damage: float = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		push_error("BowWeapon: owner has no parent scene")
		return
	var direction: Vector2 = owner_node.global_position.direction_to(target.global_position)
	var bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
	bullet.speed = weapon_data.bullet_speed
	scene_parent.add_child(bullet)
	bullet.setup(base_damage, weapon_data.knockback_force, owner_node.global_position, direction)
	AudioManager.play("shoot")
