class_name ShopConfig
extends Resource

# 商店全局配置

@export var slot_count: int = 4
@export var refresh_cost: int = 2
@export var item_cost: int = 3

# 分段波次奖励
@export var wave_reward_per_tier: PackedInt32Array = [5, 8, 10]
@export var wave_reward_tier_thresholds: PackedInt32Array = [1, 6, 11]

# Boss 赏金
@export var boss_bounty: Dictionary = {
	"boss_brute": 15,
	"boss_summoner": 20,
	"boss_guardian": 30,
}

func get_wave_reward(wave_number: int) -> int:
	for i in range(wave_reward_tier_thresholds.size() - 1, -1, -1):
		if wave_number >= wave_reward_tier_thresholds[i]:
			return wave_reward_per_tier[i]
	return wave_reward_per_tier[0]
