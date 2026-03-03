extends Tower

@export var slow_radius: float = 200.0
@export var slow_percent: float = 0.5

@onready var slow_area: Area2D = $SlowArea

func _ready():
	super._ready()

	# 连接信号
	slow_area.body_entered.connect(_on_enemy_entered)
	slow_area.body_exited.connect(_on_enemy_exited)

func _on_enemy_entered(body):
	if body.is_in_group("enemies"):
		body.speed *= (1.0 - slow_percent)

func _on_enemy_exited(body):
	if body.is_in_group("enemies"):
		body.speed /= (1.0 - slow_percent)
