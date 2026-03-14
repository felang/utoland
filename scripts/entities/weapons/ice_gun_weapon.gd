# IceGunWeapon — 子弹命中后附加减速效果
class_name IceGunWeapon
extends BulletWeapon

func _spawn_bullet(scene_parent: Node, direction: Vector2, damage: float) -> void:
	var bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
	bullet.speed = weapon_data.bullet_speed
	bullet.slow_on_hit = weapon_data.slow_on_hit
	# 控场大师（Nemo）— 控制效果持续时间 +30%
	var slow_dur: float = weapon_data.slow_duration
	if GameData.new_passive_id == "field_master":
		slow_dur *= (1.0 + GameData.new_passive_value)
	bullet.slow_duration = slow_dur
	scene_parent.add_child(bullet)
	bullet.setup(damage, weapon_data.knockback_force, owner_node.global_position, direction)
