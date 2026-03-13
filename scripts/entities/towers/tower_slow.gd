extends Tower

@export var slow_radius: float = 200.0
@export var slow_percent: float = 0.5

@onready var slow_area: Area2D = $SlowArea

func _ready() -> void:
	# 设置塔类型
	tower_type = Enums.TowerId.SLOW

	super._ready()

	# 连接信号
	slow_area.body_entered.connect(_on_enemy_entered)
	slow_area.body_exited.connect(_on_enemy_exited)

func _apply_level_stats() -> void:
	super._apply_level_stats()
	var idx: int = get_current_level() - 1
	slow_radius = data.attack_range_per_level[idx]
	slow_percent = data.slow_ratio_per_level[idx]

func _on_enemy_entered(body: Node2D) -> void:
	if body.is_in_group(Enums.Group.ENEMIES) and body.has_method("apply_slow"):
		body.apply_slow(slow_percent)

func _on_enemy_exited(body: Node2D) -> void:
	if body.is_in_group(Enums.Group.ENEMIES) and body.has_method("remove_slow"):
		body.remove_slow(slow_percent)
