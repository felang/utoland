class_name ShopConfig
extends Resource

# 商店全局配置：槽位、刷新费用、物品费用、波次奖励

@export var slot_count: int = 4
@export var refresh_cost: int = 2
@export var item_cost: int = 3
@export var wave_reward: int = 10
@export var level_up_base_cost: int = 4
@export var level_up_cost_increment: int = 2

func get_level_up_cost(current_level: int) -> int:
	return level_up_base_cost + (current_level - 1) * level_up_cost_increment
