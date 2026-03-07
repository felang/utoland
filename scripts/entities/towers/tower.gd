extends StaticBody2D
class_name Tower

# 由 SceneFactory 注入的 Resource 数据
var data: TowerData = null

var tower_type: String = Enums.Tower.WALL  # 默认类型，子类可以覆盖

@onready var health: HealthComponent = $HealthComponent

func _ready() -> void:
	health.initialize(data.hp)
	health.death_color = Color.GREEN
	health.died.connect(_on_died)
	add_to_group(Enums.Group.TOWERS)

func take_damage(amount: float) -> void:
	health.take_damage(amount)

func _on_died() -> void:
	queue_free()
