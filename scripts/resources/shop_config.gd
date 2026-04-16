class_name ShopConfig
extends Resource

# 商店全局配置(#1 流程骨架重构后,主要服务于 Roll 塔机制)

# Roll 塔配置
@export var roll_cost: int = 3
@export var pending_queue_size: int = 3
@export var dynamic_weight_multiplier: float = 1.5  # 已部署同款塔的 roll 权重倍率

# 卖出配置
@export var sell_return_ratio: float = 0.7  # 卖出返还比例(总投入 × 0.7)

# 兼容字段(暂留 = 0,后续子项目用):波次奖励、Boss 赏金已废弃,金币全靠敌人掉 + 塔生成
