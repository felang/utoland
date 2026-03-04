extends Tower

var tower_type: String = "slow"

@export var slow_radius: float = 200.0
@export var slow_percent: float = 0.5

@onready var slow_area: Area2D = $SlowArea

func _ready():
	# 从 GameConfig 读取配置
	var tower_data = GameConfig.TOWERS[tower_type]
	max_hp = tower_data["hp"]
	current_hp = tower_data["hp"]
	slow_radius = tower_data["range"]
	slow_percent = tower_data["slow_percent"]

	super._ready()

	# 连接信号
	slow_area.body_entered.connect(_on_enemy_entered)
	slow_area.body_exited.connect(_on_enemy_exited)

func _on_enemy_entered(body):
	if body.is_in_group("enemies") and body.has_method("apply_slow"):
		body.apply_slow(slow_percent)

func _on_enemy_exited(body):
	if body.is_in_group("enemies") and body.has_method("remove_slow"):
		body.remove_slow(slow_percent)
