class_name PassiveEvolutionData
extends Resource

## 被动进化数据：三阶进化，每阶一个属性字典
## 有效键: melee_damage_mult, melee_attack_speed_mult, kill_heal,
##         move_speed_mult, max_hp_mult, damage_reduction, dodge_chance,
##         pickup_range_mult, exp_mult

@export var passive_id: String = ""
@export var passive_name: String = ""

@export var tier_1: Dictionary = {}
@export var tier_2: Dictionary = {}
@export var tier_3: Dictionary = {}

@export var tier_2_level: int = 4
@export var tier_3_level: int = 7

func get_tier_for_level(level: int) -> Dictionary:
	if level >= tier_3_level:
		return tier_3
	elif level >= tier_2_level:
		return tier_2
	else:
		return tier_1
