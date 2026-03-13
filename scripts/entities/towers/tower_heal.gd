extends Tower
class_name TowerHeal

# 治愈花 — 定时治疗范围内血量最低的友方塔

var heal_amount: float = 20.0
var heal_interval: float = 3.0

@onready var _heal_area: Area2D = $HealArea
@onready var _heal_timer: Timer = $HealTimer

func _ready() -> void:
	tower_type = Enums.TowerId.HEAL_FLOWER
	super._ready()
	_heal_timer.timeout.connect(_on_heal_timer_timeout)

func _apply_level_stats() -> void:
	super._apply_level_stats()
	var idx: int = get_current_level() - 1
	if data.heal_amount_per_level.size() > idx:
		heal_amount = data.heal_amount_per_level[idx]
	if data.heal_interval_per_level.size() > idx:
		heal_interval = data.heal_interval_per_level[idx]
		_heal_timer.wait_time = heal_interval
		if not _heal_timer.is_stopped():
			_heal_timer.start()

func _on_heal_timer_timeout() -> void:
	var bodies: Array[Node2D] = []
	for body in _heal_area.get_overlapping_bodies():
		if body is Tower and body != self:
			bodies.append(body)
	if bodies.is_empty():
		return
	var lowest: Tower = null
	var lowest_ratio: float = 1.0
	for body in bodies:
		var t: Tower = body as Tower
		var ratio: float = t.health.current_hp / t.health.max_hp
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			lowest = t
	if lowest and lowest_ratio < 1.0:
		lowest.health.heal(heal_amount)
