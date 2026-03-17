class_name HealthComponent
extends Node

# 生命值组件 — 管理血量、受伤、死亡、视觉反馈

signal damaged(amount: float, current_hp: float, attacker: Node2D)
signal died()
signal died_with_overkill(overkill_damage: float, death_position: Vector2)

@export var max_hp: float = 100.0
var current_hp: float = 0.0
var invincible: bool = false
var damage_reduction: float = 0.0

# 死亡特效颜色（可由宿主设置）
var death_color: Color = Color.RED

# 闪白/伤害数字的偏移位置
var damage_number_offset: Vector2 = Vector2(0, -20)

func _ready() -> void:
	if current_hp == 0.0:
		current_hp = max_hp

func initialize(hp: float) -> void:
	max_hp = hp
	current_hp = hp

func reset() -> void:
	current_hp = max_hp
	invincible = false
	damage_reduction = 0.0

func take_damage(amount: float, attacker: Node2D = null) -> void:
	if invincible:
		return
	var reduction: float = clampf(damage_reduction, 0.0, 0.75)
	amount *= (1.0 - reduction)
	current_hp -= amount
	# 闪白
	var owner_node: Node2D = get_parent() as Node2D
	if owner_node:
		EffectsManager.flash_hit(owner_node)
	# 伤害数字
	var pos: Vector2 = _get_global_position() + damage_number_offset
	EffectsManager.spawn_damage_number(pos, amount)
	# 击中火花
	EffectsManager.spawn_hit_sparks(_get_global_position())
	damaged.emit(amount, current_hp, attacker)
	if current_hp <= 0:
		# 计算溢杀伤害（current_hp 此时为负值）
		var overkill: float = absf(current_hp)
		die()
		died_with_overkill.emit(overkill, _get_global_position())

func take_damage_no_sparks(amount: float, attacker: Node2D = null) -> void:
	# 用于 Player — 不需要击中火花，需要自定义闪白后续（无敌帧）
	if invincible:
		return
	current_hp -= amount
	damaged.emit(amount, current_hp, attacker)
	if current_hp <= 0:
		died.emit()

func heal(amount: float) -> void:
	current_hp = min(current_hp + amount, max_hp)

func die() -> void:
	# 死亡特效
	EffectsManager.spawn_death_effect(_get_global_position(), death_color)
	died.emit()

func is_dead() -> bool:
	return current_hp <= 0

func _get_global_position() -> Vector2:
	var owner_node: Node2D = get_parent() as Node2D
	if owner_node:
		return owner_node.global_position
	return Vector2.ZERO
