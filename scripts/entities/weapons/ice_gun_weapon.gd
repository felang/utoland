# IceGunWeapon — 子弹命中后附加减速效果
class_name IceGunWeapon
extends BulletWeapon

func _spawn_bullet(scene_parent: Node, direction: Vector2, damage: float) -> void:
	var bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
	bullet.speed = weapon_data.bullet_speed
	bullet.slow_on_hit = weapon_data.slow_on_hit
	bullet.slow_duration = weapon_data.slow_duration
	scene_parent.add_child(bullet)
	bullet.setup(damage, weapon_data.knockback_force, owner_node.global_position, direction)
