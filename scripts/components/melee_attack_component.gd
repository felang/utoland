class_name MeleeAttackComponent
extends Node

signal attack_executed(target: Node2D)

var attack_config: AttackConfigData = null
var melee_config: MeleeConfig = null
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var sfx_id: String = "melee"

var _base_damage: float = 0.0
var _base_cooldown: float = 1.0
var _cooldown_remaining: float = 0.0
var _target_finder: TargetFinderComponent = null
var _is_attacking: bool = false

func _ready() -> void:
	_target_finder = get_parent().get_node_or_null("TargetFinderComponent")

func set_level(level: int) -> void:
	if not attack_config:
		return
	var idx: int = level - 1
	if idx < attack_config.damage_per_level.size():
		_base_damage = attack_config.damage_per_level[idx]
	if idx < attack_config.fire_rate_per_level.size():
		_base_cooldown = attack_config.fire_rate_per_level[idx]
	if _target_finder and idx < attack_config.attack_range_per_level.size():
		_target_finder.set_range(attack_config.attack_range_per_level[idx])

func tick(delta: float) -> void:
	if _is_attacking:
		return
	_cooldown_remaining -= delta
	if _cooldown_remaining > 0.0:
		return
	if not _target_finder:
		return
	var target: Node2D = _target_finder.get_target()
	if not target or not is_instance_valid(target):
		return
	_execute_melee(target)
	_cooldown_remaining = get_final_cooldown()

func get_final_damage() -> float:
	return _base_damage * damage_multiplier

func get_final_cooldown() -> float:
	if speed_multiplier <= 0.0:
		return _base_cooldown
	return _base_cooldown / speed_multiplier

func _execute_melee(target: Node2D) -> void:
	if not melee_config:
		return
	_is_attacking = true
	var offset_node: Node2D = get_parent() as Node2D
	var pivot: Node2D = offset_node.get_parent() if offset_node else null
	var weapon_pos: Vector2 = offset_node.global_position if offset_node else Vector2.ZERO
	var direction: Vector2 = weapon_pos.direction_to(target.global_position)

	# 临时让 Pivot 朝向目标（视觉突刺方向和判定方向一致）
	var saved_rotation: float = pivot.rotation if pivot else 0.0
	if pivot:
		pivot.rotation = direction.angle()

	# 创建临时 Hitbox（加到场景根，不受 tween 影响）
	var hitbox := Hitbox.new()
	hitbox.damage = get_final_damage()
	hitbox.knockback_force = melee_config.knockback_force
	hitbox.collision_layer = 4   # HITBOX layer
	hitbox.collision_mask = 128  # HURTBOX layer
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = melee_config.hit_radius
	shape.shape = circle
	hitbox.add_child(shape)
	get_tree().current_scene.add_child(hitbox)
	hitbox.global_position = weapon_pos + direction * melee_config.thrust_distance

	# Tween 前刺动画（Pivot 已朝向目标，沿局部 X 轴前推 = 朝向目标推）
	if offset_node and offset_node.name == "WeaponOffset":
		var tween := create_tween()
		var original_pos: Vector2 = offset_node.position
		var thrust_pos: Vector2 = original_pos + Vector2(melee_config.thrust_distance, 0)
		tween.tween_property(offset_node, "position", thrust_pos, 0.1)
		tween.tween_property(offset_node, "position", original_pos, 0.1)
		tween.tween_callback(func() -> void:
			if is_instance_valid(hitbox):
				hitbox.queue_free()
			_is_attacking = false
		)
	else:
		get_tree().create_timer(0.2).timeout.connect(func() -> void:
			if is_instance_valid(hitbox):
				hitbox.queue_free()
			_is_attacking = false
		)

	attack_executed.emit(target)
	AudioManager.play(sfx_id)
