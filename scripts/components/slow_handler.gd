class_name SlowHandler
extends Node

# 减速处理组件 — 管理减速效果叠加

signal speed_changed(new_speed: float)

var base_speed: float = 0.0
var slow_effects: int = 0

func initialize(initial_speed: float) -> void:
	base_speed = initial_speed

func apply_slow(slow_percent: float) -> void:
	slow_effects += 1
	if slow_effects == 1:
		speed_changed.emit(base_speed * (1.0 - slow_percent))

func remove_slow(_slow_percent: float) -> void:
	slow_effects -= 1
	if slow_effects <= 0:
		slow_effects = 0
		speed_changed.emit(base_speed)
