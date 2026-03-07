# Weapon — 武器基类（不可见 Node）
# 管理冷却时间，fire() 由子类实现
class_name Weapon
extends Node

var weapon_data: WeaponData = null
var _cooldown: float = 0.0

func initialize(data: WeaponData) -> void:
	weapon_data = data
	_cooldown = 0.0

func tick(delta: float, target: Node2D) -> void:
	_cooldown -= delta
	if _cooldown <= 0.0 and target:
		fire(target)
		var speed_mult: float = GameData.player_stats.get("attack_speed_mult", 1.0)
		_cooldown = weapon_data.fire_rate / speed_mult

func fire(_target: Node2D) -> void:
	pass  # 子类实现
