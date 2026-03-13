# RocketWeapon — 发射爆炸火箭
class_name RocketWeapon
extends Weapon

func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var base_damage: float = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		return
	var direction: Vector2 = owner_node.global_position.direction_to(target.global_position)
	var rocket: RocketProjectile = SceneFactory.create_rocket_projectile()
	rocket.speed = weapon_data.bullet_speed
	var level: int = get_current_level()
	if weapon_data.explosion_radius_per_level.size() >= level:
		rocket.explosion_radius = weapon_data.explosion_radius_per_level[level - 1]
	scene_parent.add_child(rocket)
	rocket.setup(base_damage, weapon_data.knockback_force, owner_node.global_position, direction)
	AudioManager.play("shoot")
