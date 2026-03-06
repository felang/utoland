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
	# 受击闪白
	EffectsManager.flash_white(self)
	# 伤害数字
	EffectsManager.spawn_damage_number(global_position + Vector2(0, -20), amount)
	if current_hp <= 0:
		# 死亡特效
		EffectsManager.spawn_death_effect(global_position, Color.GREEN)
		queue_free()
