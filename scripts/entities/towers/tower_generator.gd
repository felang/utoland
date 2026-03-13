class_name TowerGenerator
extends Tower

# 向日葵 — 定时产出金币（通过 EventBus 通知主场景）

var generate_amount: int = 5
var generate_interval: float = 10.0

@onready var _generate_timer: Timer = $GenerateTimer

func _ready() -> void:
	tower_type = Enums.TowerId.SUNFLOWER
	super._ready()
	_generate_timer.timeout.connect(_on_generate_timer_timeout)

func _apply_level_stats() -> void:
	super._apply_level_stats()
	var idx: int = get_current_level() - 1
	if data.generate_amount_per_level.size() > idx:
		generate_amount = data.generate_amount_per_level[idx]
	if data.generate_interval_per_level.size() > idx:
		generate_interval = data.generate_interval_per_level[idx]
		_generate_timer.wait_time = generate_interval
		if not _generate_timer.is_stopped():
			_generate_timer.start()

func _on_generate_timer_timeout() -> void:
	EventBus.coins_generated.emit(generate_amount, global_position)
