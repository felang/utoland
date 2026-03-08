# BulletWeapon — 发射直线子弹的武器
class_name BulletWeapon
extends Weapon

func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var base_damage: float = weapon_data.damage * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)

	# 蓄力：若有层数则本次攻击爆发，清零
	if GameData.kill_stack_count > 0:
		base_damage *= (1.0 + GameData.kill_stack_count * GameData.kill_stack_damage_per_stack)
		GameData.kill_stack_count = 0

	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		push_error("BulletWeapon: owner has no parent scene")
		return

	var base_dir: Vector2 = owner_node.global_position.direction_to(target.global_position)

	# 弹幕：激活时发射 3 发，各偏转 -15°/0°/+15°，每发伤害乘以倍率
	if GameData.multishot_active:
		for angle_offset: float in [-15.0, 0.0, 15.0]:
			var rotated_dir: Vector2 = base_dir.rotated(deg_to_rad(angle_offset))
			_spawn_bullet(scene_parent, rotated_dir, base_damage * GameData.multishot_damage_mult)
	else:
		_spawn_bullet(scene_parent, base_dir, base_damage)

	_spawn_muzzle_flash(owner_node)

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
