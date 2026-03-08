# Weapon — 武器基类（不可见 Node）
# 管理冷却时间，fire() 由子类实现
class_name Weapon
extends Node

var weapon_data: WeaponData = null
var owner_node: Node2D = null
var _cooldown: float = 0.0

func initialize(data: WeaponData) -> void:
	weapon_data = data
	_cooldown = 0.0
	# 蓄力：监听敌人击杀事件，累计层数
	if not EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.connect(_on_enemy_killed)

func _on_enemy_killed(_enemy_type: String, _position: Vector2) -> void:
	# 蓄力：击杀时叠加层数（未达上限则增加）
	if GameData.kill_stack_max > 0 and GameData.kill_stack_count < GameData.kill_stack_max:
		GameData.kill_stack_count += 1

func tick(delta: float, target: Node2D) -> void:
	_cooldown -= delta
	if _cooldown <= 0.0 and target:
		fire(target)
		var speed_mult: float = GameData.player_stats.get(Enums.Stat.ATTACK_SPEED_MULT, 1.0)
		_cooldown = weapon_data.fire_rate / speed_mult

func fire(_target: Node2D) -> void:
	pass  # 子类实现
