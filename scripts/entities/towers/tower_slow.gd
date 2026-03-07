extends Tower

@export var slow_radius: float = 200.0
@export var slow_percent: float = 0.5

@onready var slow_area: Area2D = $SlowArea

func _ready():
	# 设置塔类型
	tower_type = "slow"

	# 从注入的 Resource 初始化（HP 由 super._ready() 处理）
	if data:
		_initial_max_hp = data.hp
		slow_radius = data.attack_range
		slow_percent = data.slow_percent
	else:
		# 向后兼容
		var tower_config: Dictionary = GameConfig.TOWERS[tower_type]
		_initial_max_hp = tower_config["hp"]
		slow_radius = tower_config["range"]
		slow_percent = tower_config["slow_percent"]

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
