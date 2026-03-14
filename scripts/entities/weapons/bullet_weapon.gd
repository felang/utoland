# BulletWeapon — 发射直线子弹的武器
class_name BulletWeapon
extends Weapon

## 弹幕时刻：minigun 射击计数
var _bullet_time_shot_count: int = 0
const _BULLET_TIME_THRESHOLD: int = 50
const _BULLET_TIME_SLOW_PERCENT: float = 0.8
const _BULLET_TIME_SLOW_DURATION: float = 0.5

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

	# 弹幕时刻：minigun 每 50 发全场减速
	if weapon_data and weapon_data.weapon_type == "minigun" and GameData.active_pair_synergies.has("bullet_time"):
		_bullet_time_shot_count += 1
		if _bullet_time_shot_count >= _BULLET_TIME_THRESHOLD:
			_bullet_time_shot_count = 0
			_trigger_bullet_time()

## 弹幕时刻：对全场敌人施加 0.5 秒 80% 减速
func _trigger_bullet_time() -> void:
	if not is_inside_tree():
		return
	for enemy in get_tree().get_nodes_in_group(Enums.Group.ENEMIES):
		if enemy.has_node("SlowHandler"):
			var sh: SlowHandler = enemy.get_node("SlowHandler") as SlowHandler
			if sh:
				sh.apply_timed_slow(_BULLET_TIME_SLOW_PERCENT, _BULLET_TIME_SLOW_DURATION, "bullet_time")

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
