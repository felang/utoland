# Hurtbox — 受击检测组件，挂载于玩家、敌人和塔
# 监听进入的 Area2D，若为 Hitbox 则读取伤害数据并发射 hit_taken 信号
# repeat_damage 模式：敌人持续接触时，每 repeat_interval 秒对每个 Hitbox 独立计时重复触发伤害
class_name Hurtbox
extends Area2D

signal hit_taken(damage: float, knockback: Vector2)

@export var repeat_damage: bool = false
@export var repeat_interval: float = 1.0

# 每个 Hitbox 独立计时，避免多敌人重叠时互相影响
var _hitbox_timers: Dictionary = {}  # {Hitbox: float}

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _process(delta: float) -> void:
	if not repeat_damage or _hitbox_timers.is_empty():
		return
	var to_remove: Array = []
	for hitbox in _hitbox_timers:
		if not is_instance_valid(hitbox):
			to_remove.append(hitbox)
			continue
		_hitbox_timers[hitbox] -= delta
		if _hitbox_timers[hitbox] <= 0.0:
			_hitbox_timers[hitbox] = repeat_interval
			var dir: Vector2 = hitbox.global_position.direction_to(global_position)
			hit_taken.emit(hitbox.damage, dir * hitbox.knockback_force)
	for h in to_remove:
		_hitbox_timers.erase(h)

func _on_area_entered(area: Area2D) -> void:
	if not area is Hitbox:
		return
	var dir: Vector2 = area.global_position.direction_to(global_position)
	hit_taken.emit(area.damage, dir * area.knockback_force)
	if repeat_damage:
		_hitbox_timers[area] = repeat_interval

func _on_area_exited(area: Area2D) -> void:
	_hitbox_timers.erase(area)

## 对象池重置
func reset_for_pool() -> void:
	_hitbox_timers.clear()
