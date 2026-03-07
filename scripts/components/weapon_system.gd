class_name WeaponSystem
extends Node

# 武器系统组件 — 管理自动射击、投射物创建

var weapon_data: WeaponData = null
var weapon_damage: float = 10.0
var fire_rate: float = 0.1
var weapon_range: float = 300.0

var _shoot_timer: float = 0.0

func initialize(data: WeaponData, damage_mult: float, attack_speed_mult: float) -> void:
	weapon_data = data
	fire_rate = data.fire_rate / attack_speed_mult
	weapon_damage = data.damage * damage_mult
	weapon_range = data.weapon_range

func process(delta: float) -> void:
	_shoot_timer -= delta
	if _shoot_timer <= 0:
		auto_shoot()

func auto_shoot() -> void:
	var owner_node: Node2D = get_parent() as Node2D
	if not owner_node:
		return

	var enemies: Array[Node] = owner_node.get_tree().get_nodes_in_group("enemies")
	var closest_enemy: Node2D = null
	var min_distance: float = weapon_range

	for enemy in enemies:
		if enemy is Node2D:
			var distance: float = owner_node.global_position.distance_to(enemy.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_enemy = enemy

	if closest_enemy:
		shoot_weapon(closest_enemy.global_position)

	_shoot_timer = fire_rate

func shoot_weapon(target_pos: Vector2) -> void:
	if not weapon_data:
		return

	match weapon_data.projectile_type:
		"bullet":
			_shoot_bullet(target_pos)
		"boomerang":
			_shoot_boomerang(target_pos)
		"laser":
			_shoot_laser(target_pos)

func _shoot_bullet(target_pos: Vector2) -> void:
	var owner_node: Node2D = get_parent() as Node2D
	if not owner_node:
		return
	var bullet: Area2D = SceneFactory.create_bullet()
	bullet.global_position = owner_node.global_position
	bullet.direction = owner_node.global_position.direction_to(target_pos)
	bullet.damage = weapon_damage
	var parent: Node = owner_node.get_parent()
	if parent:
		parent.add_child(bullet)
		_spawn_muzzle_flash(owner_node.global_position, owner_node)
	else:
		push_error("WeaponSystem owner has no parent to add bullet to")
		bullet.queue_free()

func _shoot_boomerang(target_pos: Vector2) -> void:
	var owner_node: Node2D = get_parent() as Node2D
	if not owner_node:
		return
	var boomerang: Area2D = SceneFactory.create_boomerang()
	boomerang.global_position = owner_node.global_position
	boomerang.direction = owner_node.global_position.direction_to(target_pos)
	boomerang.damage = weapon_damage
	boomerang.player = owner_node
	var parent: Node = owner_node.get_parent()
	if parent:
		parent.add_child(boomerang)
	else:
		push_error("WeaponSystem owner has no parent to add boomerang to")
		boomerang.queue_free()

func _shoot_laser(target_pos: Vector2) -> void:
	var owner_node: Node2D = get_parent() as Node2D
	if not owner_node:
		return

	var beam_range: float = weapon_data.beam_range
	var direction: Vector2 = owner_node.global_position.direction_to(target_pos)
	var end_pos: Vector2 = owner_node.global_position + direction * beam_range

	# 射线查询：检测线上所有敌人（贯穿）
	var space_state: PhysicsDirectSpaceState2D = owner_node.get_world_2d().direct_space_state
	var laser_mask: int = GameConfig.effects.laser_collision_mask
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		owner_node.global_position, end_pos, laser_mask
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	# 循环射线查询实现贯穿
	var hit_enemies: Array = []
	var from: Vector2 = owner_node.global_position
	var ray_limit: int = GameConfig.effects.laser_ray_query_limit
	for i in range(ray_limit):
		query.from = from
		var result: Dictionary = space_state.intersect_ray(query)
		if result.is_empty():
			break
		var collider: Node2D = result["collider"]
		if collider.is_in_group("enemies") and collider not in hit_enemies:
			hit_enemies.append(collider)
			if collider.has_method("take_damage"):
				collider.take_damage(weapon_damage)
			if collider.has_method("apply_knockback"):
				collider.apply_knockback(direction)
		from = result["position"] + direction * 1.0
		query.exclude.append(collider.get_rid())

	# 生成视觉效果
	var beam: Node2D = SceneFactory.create_laser_beam()
	var scene_parent: Node = owner_node.get_parent()
	if scene_parent:
		scene_parent.add_child(beam)
		beam.fire(owner_node.global_position, end_pos)
		# 全屏红色频闪
		var fx: EffectConfigData = GameConfig.effects
		var flash: ColorRect = ColorRect.new()
		flash.color = Color(1, 0, 0, fx.laser_flash_alpha)
		flash.size = fx.laser_flash_size
		flash.position = owner_node.global_position - fx.laser_flash_size / 2
		flash.z_index = fx.laser_flash_z_index
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scene_parent.add_child(flash)
		var flash_tween: Tween = owner_node.create_tween()
		flash_tween.tween_property(flash, "modulate:a", 0.0, fx.laser_flash_duration)
		flash_tween.tween_callback(flash.queue_free)
	else:
		push_error("WeaponSystem owner has no parent to add laser beam to")
		beam.queue_free()

func _spawn_muzzle_flash(pos: Vector2, node: Node2D) -> void:
	var fx: EffectConfigData = GameConfig.effects
	var flash: ColorRect = ColorRect.new()
	flash.size = fx.muzzle_flash_size
	flash.position = pos - fx.muzzle_flash_size / 2
	flash.color = fx.muzzle_flash_color
	flash.z_index = fx.muzzle_flash_z_index
	var parent_node: Node = node.get_parent()
	if parent_node:
		parent_node.add_child(flash)
		var tween: Tween = node.create_tween()
		tween.tween_property(flash, "scale", Vector2(0.1, 0.1), fx.muzzle_flash_duration).set_ease(Tween.EASE_OUT)
		tween.tween_callback(flash.queue_free)
