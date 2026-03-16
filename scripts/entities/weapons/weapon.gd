# Weapon — 武器基类
# 组合 AttackerComponent 管理攻击逻辑
class_name Weapon
extends Node

signal projectile_created(proj: ProjectileBase)

var weapon_data: WeaponData = null
var owner_node: Node2D = null
var sprite: Sprite2D = null  # 漂浮精灵引用，由 WeaponManager 注入
var attacker: AttackerComponent = null
var _level: int = 1

func initialize(data: WeaponData) -> void:
	weapon_data = data
	attacker = AttackerComponent.new()
	add_child(attacker)
	attacker.attack_fired.connect(_on_attack_fired)
	attacker.melee_triggered.connect(_on_melee_triggered)

func set_level(level: int) -> void:
	_level = level
	if not attacker:
		return
	var idx: int = level - 1
	attacker.update_stats(
		weapon_data.damage_per_level[idx],
		weapon_data.weapon_range_per_level[idx],
		weapon_data.fire_rate_per_level[idx]
	)
	attacker.attack_mode = weapon_data.attack_mode as AttackerComponent.AttackMode
	attacker.projectile_data = weapon_data.projectile_data
	attacker.melee_config = weapon_data.melee_config

func get_current_level() -> int:
	return _level

func get_fire_position() -> Vector2:
	if sprite and is_instance_valid(sprite):
		return sprite.global_position
	if owner_node:
		return owner_node.global_position
	return Vector2.ZERO

func _on_attack_fired(target: Node2D, proj_data: ProjectileData) -> void:
	if not owner_node:
		return
	var fire_pos: Vector2 = get_fire_position()
	var direction: Vector2 = fire_pos.direction_to(target.global_position)
	var damage: float = attacker.get_final_damage()
	var extra_pierce: int = GameData.pierce_count
	var proj: ProjectileBase = SceneFactory.create_projectile(proj_data, damage, fire_pos, direction, extra_pierce)
	var scene_parent: Node = owner_node.get_parent()
	if scene_parent:
		scene_parent.add_child(proj)
	projectile_created.emit(proj)
	AudioManager.play("shoot")

func _on_melee_triggered(target: Node2D, config: MeleeConfig) -> void:
	if not owner_node or not sprite or not is_instance_valid(sprite):
		return
	var damage: float = attacker.get_final_damage()
	var thrust_direction: Vector2 = sprite.global_position.direction_to(target.global_position)
	var hit_enemies: Array[Node2D] = []
	# 临时 hitbox
	var thrust_hitbox := Area2D.new()
	thrust_hitbox.collision_layer = CollisionLayers.HITBOX
	thrust_hitbox.collision_mask = CollisionLayers.HURTBOX
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = config.hit_radius
	shape.shape = circle
	thrust_hitbox.add_child(shape)
	thrust_hitbox.area_entered.connect(func(area: Area2D) -> void:
		if not area is Hurtbox:
			return
		var enemy: Node2D = area.get_parent()
		if enemy in hit_enemies:
			return
		hit_enemies.append(enemy)
		area.hit_taken.emit(damage, thrust_direction * config.knockback_force)
		EffectsManager.spawn_hit_sparks(enemy.global_position)
	)
	sprite.add_child(thrust_hitbox)
	# 突刺动画
	var original_pos: Vector2 = sprite.position
	var thrust_pos: Vector2 = original_pos + thrust_direction * attacker.attack_range
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "position", thrust_pos, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sprite, "position", original_pos, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func():
		if thrust_hitbox and is_instance_valid(thrust_hitbox):
			thrust_hitbox.queue_free()
	)
	AudioManager.play("shoot")
