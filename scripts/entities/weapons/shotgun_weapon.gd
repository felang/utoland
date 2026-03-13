# ShotgunWeapon — 扇形散射多颗子弹
class_name ShotgunWeapon
extends Weapon

func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var base_damage: float = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		return
	var base_dir: Vector2 = owner_node.global_position.direction_to(target.global_position)
	var count: int = weapon_data.bullet_count
	var spread: float = deg_to_rad(25.0)  # ±25° fan spread
	for i in count:
		var angle_offset: float = lerp(-spread, spread, float(i) / max(count - 1, 1))
		var dir: Vector2 = base_dir.rotated(angle_offset)
		var bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
		bullet.speed = weapon_data.bullet_speed
		bullet.lifetime = 2.0
		scene_parent.add_child(bullet)
		bullet.setup(base_damage, weapon_data.knockback_force, owner_node.global_position, dir)
	AudioManager.play("shoot")
