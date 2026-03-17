class_name GeneratorComponent
extends Node

signal generated(amount: int, position: Vector2)

var config: GeneratorConfigData = null
var _amount: int = 0
var _interval: float = 10.0
var _timer: Timer = null

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.autostart = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

func set_level(level: int) -> void:
	if not config:
		return
	var idx: int = level - 1
	if idx < config.generate_amount_per_level.size():
		_amount = int(config.generate_amount_per_level[idx])
	if idx < config.generate_interval_per_level.size():
		_interval = config.generate_interval_per_level[idx]
	_timer.wait_time = _interval
	if is_inside_tree():
		_timer.start()

func _on_timer_timeout() -> void:
	generated.emit(_amount, get_parent().global_position if get_parent() else Vector2.ZERO)
