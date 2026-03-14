class_name ShopConfig
extends Resource

# 商店全局配置：槽位、刷新费用、背包容量、稀有度权重、升级费用、种群数量等

@export var slot_count: int = 4
@export var refresh_cost: int = 2
@export var bag_capacity: int = 10
@export var cost_by_rarity: PackedInt32Array = PackedInt32Array([3, 5, 8])
@export var level_up_costs: PackedInt32Array = PackedInt32Array([4, 8, 12, 20, 28, 36])
@export var population_per_level: PackedInt32Array = PackedInt32Array([2, 3, 4, 5, 6, 7, 8])
@export var rarity_weights: Array[PackedFloat32Array] = [
	PackedFloat32Array([100.0, 0.0, 0.0]),
	PackedFloat32Array([100.0, 0.0, 0.0]),
	PackedFloat32Array([70.0, 30.0, 0.0]),
	PackedFloat32Array([55.0, 40.0, 5.0]),
	PackedFloat32Array([40.0, 40.0, 20.0]),
	PackedFloat32Array([30.0, 40.0, 30.0]),
	PackedFloat32Array([20.0, 40.0, 40.0]),
]
