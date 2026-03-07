# LaserWeapon — 发射瞬发激光的武器
class_name LaserWeapon
extends Weapon

func fire(target: Node2D) -> void:
	if not owner_node:
		return
	var final_damage: float = weapon_data.damage * GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)
	var direction: Vector2 = owner_node.global_position.direction_to(target.global_position)
	var laser: LaserProjectile = SceneFactory.create_laser_projectile()
	laser.beam_range = weapon_data.beam_range
	laser.beam_duration = weapon_data.beam_duration
	var scene_parent: Node = owner_node.get_parent()
	if not scene_parent:
		push_error("LaserWeapon: owner has no parent scene")
		return
	scene_parent.add_child(laser)
	laser.setup(final_damage, 0.0, owner_node.global_position, direction)
	_spawn_laser_flash(owner_node, scene_parent)

func _spawn_laser_flash(owner_node: Node2D, scene_parent: Node) -> void:
	var fx: EffectConfigData = GameConfig.effects
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(1, 0, 0, fx.laser_flash_alpha)
	flash.size = fx.laser_flash_size
	flash.z_index = fx.laser_flash_z_index
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_parent.add_child(flash)
	flash.global_position = owner_node.global_position - fx.laser_flash_size / 2
	var tween: Tween = owner_node.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, fx.laser_flash_duration)
	tween.tween_callback(flash.queue_free)
