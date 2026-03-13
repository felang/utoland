class_name EnemyData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var hp: float = 50.0
@export var speed: float = 50.0
@export var damage: float = 10.0
@export var coin_drop_min: int = 1
@export var coin_drop_max: int = 3

# Boss 冲锋参数（可选，普通敌人留默认值 0）
@export var charge_cooldown: float = 0.0
@export var charge_speed_mult: float = 0.0
@export var charge_damage_mult: float = 0.0
@export var charge_windup_time: float = 0.0

# Boss 标识
@export var is_boss: bool = false
