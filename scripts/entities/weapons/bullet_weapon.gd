# BulletWeapon — 发射直线子弹的武器
class_name BulletWeapon
extends Weapon

func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var base_damage: float = get_damage() * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)

	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		push_error("BulletWeapon: owner has no parent scene")
		return

	var base_dir: Vector2 = owner_node.global_position.direction_to(target.global_position)
	_spawn_bullet(scene_parent, base_dir, base_damage)

	_spawn_muzzle_flash(owner_node)
	AudioManager.play("shoot")

func _spawn_bullet(scene_parent: Node, direction: Vector2, damage: float) -> void:
	var bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
	bullet.speed = weapon_data.bullet_speed
	scene_parent.add_child(bullet)
	bullet.setup(damage, weapon_data.knockback_force, owner_node.global_position, direction)

func _spawn_muzzle_flash(owner_node: Node2D) -> void:
	var fx: EffectConfigData = GameConfig.effects
	var flash: ColorRect = ColorRect.new()
	flash.size = fx.muzzle_flash_size
	flash.color = fx.muzzle_flash_color
	flash.z_index = fx.muzzle_flash_z_index
	var parent: Node = owner_node.get_parent()
	if not parent:
		return
	parent.add_child(flash)
	flash.global_position = owner_node.global_position - fx.muzzle_flash_size / 2
	var tween: Tween = owner_node.create_tween()
	tween.tween_property(flash, "scale", Vector2(0.1, 0.1), fx.muzzle_flash_duration).set_ease(Tween.EASE_OUT)
	tween.tween_callback(flash.queue_free)
