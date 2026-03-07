extends StaticBody2D
class_name Tower

# 由 SceneFactory 注入的 Resource 数据
var data: TowerData = null

var tower_type: String = "wall"  # 默认类型，子类可以覆盖

@export var _initial_max_hp: float = 100.0
@export var cost: int = 30

@onready var _health: HealthComponent = $HealthComponent

func _ready():
	# 从注入的 Resource 初始化
	if data:
		_health.initialize(data.hp)
	elif tower_type == "wall":
		# 向后兼容
		var tower_config: Dictionary = GameConfig.TOWERS[tower_type]
		_health.initialize(tower_config["hp"])
	else:
		_health.initialize(_initial_max_hp)

	_health.death_color = Color.GREEN
	_health.died.connect(_on_died)
	add_to_group("towers")

func take_damage(amount: float):
	_health.take_damage(amount)

# 向后兼容属性
var current_hp: float:
	get: return _health.current_hp if _health else _initial_max_hp
	set(value):
		if _health:
			_health.current_hp = value

var max_hp: float:
	get: return _health.max_hp if _health else _initial_max_hp
	set(value):
		if _health:
			_health.max_hp = value
		_initial_max_hp = value

func _on_died() -> void:
	queue_free()
