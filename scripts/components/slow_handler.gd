class_name SlowHandler
extends Node

# 减速处理组件 — 管理多源减速效果，取最大值

signal speed_changed(new_speed: float)

var base_speed: float = 0.0
var _active_slows: Dictionary = {}  # {source_id: {percent: float}}
var _timed_slow_timers: Dictionary = {}  # {source_id: SceneTreeTimer}

func initialize(initial_speed: float) -> void:
	base_speed = initial_speed

func apply_slow(percent: float, source_id: String) -> void:
	_active_slows[source_id] = {"percent": percent}
	_recalc_speed()

func remove_slow(source_id: String) -> void:
	_active_slows.erase(source_id)
	_recalc_speed()

func apply_timed_slow(percent: float, duration: float, source_id: String) -> void:
	apply_slow(percent, source_id)
	# 若同 source_id 已有计时器，断开旧回调
	if _timed_slow_timers.has(source_id):
		var old_timer = _timed_slow_timers[source_id]
		if old_timer and is_instance_valid(old_timer):
			if old_timer.timeout.is_connected(_on_timed_slow_expired.bind(source_id)):
				old_timer.timeout.disconnect(_on_timed_slow_expired.bind(source_id))
	var timer: SceneTreeTimer = get_tree().create_timer(duration)
	timer.timeout.connect(_on_timed_slow_expired.bind(source_id))
	_timed_slow_timers[source_id] = timer

func _on_timed_slow_expired(source_id: String) -> void:
	_timed_slow_timers.erase(source_id)
	remove_slow(source_id)

func _recalc_speed() -> void:
	if _active_slows.is_empty():
		speed_changed.emit(base_speed)
		return
	var max_percent: float = 0.0
	for data in _active_slows.values():
		if data["percent"] > max_percent:
			max_percent = data["percent"]
	speed_changed.emit(base_speed * (1.0 - max_percent))
