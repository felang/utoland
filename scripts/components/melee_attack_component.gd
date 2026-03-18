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
var _attack_range: float = 50.0
var _cooldown_remaining: float = 0.0
var _target_finder: TargetFinderComponent = null
var _is_attacking: bool = false
var _hit_enemies: Array[Node2D] = []

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
	if idx < attack_config.attack_range_per_level.size():
		_attack_range = attack_config.attack_range_per_level[idx]
		if _target_finder:
			_target_finder.set_range(_attack_range)

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
	_hit_enemies.clear()
	var offset_node: Node2D = get_parent().get_node_or_null("WeaponOffset") if get_parent() else null
	if not offset_node:
		_is_attacking = false
		return
	var direction: Vector2 = offset_node.global_position.direction_to(target.global_position)

	# Hitbox 作为 Offset 子节点，跟随 tween 移动扫过敌人
	var hitbox := Hitbox.new()
	hitbox.damage = get_final_damage()
	hitbox.knockback_force = melee_config.knockback_force
	hitbox.collision_layer = 16  # PlayerAttack layer (层5)
	hitbox.collision_mask = 128  # EnemyHurt layer (层8)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = melee_config.hit_radius
	shape.shape = circle
	hitbox.add_child(shape)
	offset_node.add_child(hitbox)
	hitbox.position = Vector2(melee_config.hit_radius, 0)
	# 连接碰撞信号，防重复命中
	hitbox.area_entered.connect(_on_melee_hitbox_entered)

	# Tween 突刺 — Offset 推出去再收回来，Hitbox 跟着扫
	var tween := create_tween()
	var thrust_target: Vector2 = direction * _attack_range
	tween.tween_property(offset_node, "position", thrust_target, 0.1)
	tween.tween_property(offset_node, "position", Vector2.ZERO, 0.1)
	tween.tween_callback(func() -> void:
		if is_instance_valid(hitbox):
			hitbox.queue_free()
		_is_attacking = false
		_hit_enemies.clear()
	)

	attack_executed.emit(target)
	AudioManager.play(sfx_id)

func _on_melee_hitbox_entered(area: Area2D) -> void:
	if not area is Hurtbox:
		return
	var enemy: Node2D = area.get_parent()
	if not enemy or enemy in _hit_enemies:
		return
	_hit_enemies.append(enemy)
	# 伤害由 Hurtbox 自动处理（读 Hitbox.damage → hit_taken 信号）
	EffectsManager.spawn_hit_sparks(enemy.global_position)
