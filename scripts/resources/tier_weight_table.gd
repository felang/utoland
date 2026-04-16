class_name TierWeightTable
extends Resource

## Tier 权重表 — 按英雄等级分段配置 4 个 Tier 的抽中权重
##
## entries 是按 level_min 升序排列的数组，每项:
##   {
##     "level_min": int,        # 该段起始等级(含)
##     "weights": Array[float], # 长度 4，对应 Tier 1-4 的权重(归一化用)
##   }
##
## 查找规则: 取 level_min <= player_level 的最大段。

@export var entries: Array = []

func get_tier_weights(player_level: int) -> Array:
	var matched: Array = [1.0, 0.0, 0.0, 0.0]  # 兜底
	for entry in entries:
		if entry.get("level_min", 99999) <= player_level:
			matched = entry.get("weights", matched)
	return matched
