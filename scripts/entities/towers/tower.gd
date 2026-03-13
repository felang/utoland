extends StaticBody2D
class_name Tower

# 由 SceneFactory 注入的 Resource 数据
var data: TowerData = null
var tower_type: String = Enums.TowerId.STUMP

@onready var health: HealthComponent = $HealthComponent

func _ready() -> void:
	_apply_level_stats()
	health.death_color = Color.GREEN
	health.died.connect(_on_died)
	add_to_group(Enums.Group.TOWERS)
	EventBus.tower_upgraded.connect(_on_tower_upgraded)

func get_current_level() -> int:
	return GameData.owned_towers.get(data.id, 1)

func _apply_level_stats() -> void:
	var level: int = get_current_level()
	var idx: int = level - 1
	health.initialize(data.hp_per_level[idx])

func _on_tower_upgraded(upgraded_type: String) -> void:
	if upgraded_type == data.id:
		_apply_level_stats()

func take_damage(amount: float, attacker: Node2D = null) -> void:
	health.take_damage(amount, attacker)

func _on_died() -> void:
	EventBus.tower_upgraded.disconnect(_on_tower_upgraded)
	queue_free()
