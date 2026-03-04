extends StaticBody2D
class_name Tower

var tower_type: String = "wall"  # 默认类型，子类可以覆盖

@export var max_hp: float = 100.0
@export var cost: int = 30

var current_hp: float

func _ready():
	# 如果是墙塔（基类直接使用），从 GameConfig 读取配置
	if tower_type == "wall":
		var tower_data = GameConfig.TOWERS[tower_type]
		max_hp = tower_data["hp"]
		current_hp = tower_data["hp"]
	else:
		current_hp = max_hp

	add_to_group("towers")

func take_damage(amount: float):
	current_hp -= amount
	if current_hp <= 0:
		queue_free()
