extends GutTest

func test_wave_reward_tiers() -> void:
	var config: ShopConfig = GameConfig.shop_config
	# 阈值 [1, 5, 9]，奖励 [5, 8, 10]
	assert_eq(config.get_wave_reward(1), 5, "Wave 1 奖励应为 5")
	assert_eq(config.get_wave_reward(4), 5, "Wave 4 奖励应为 5")
	assert_eq(config.get_wave_reward(5), 8, "Wave 5 奖励应为 8")
	assert_eq(config.get_wave_reward(8), 8, "Wave 8 奖励应为 8")
	assert_eq(config.get_wave_reward(9), 10, "Wave 9 奖励应为 10")
	assert_eq(config.get_wave_reward(12), 10, "Wave 12 奖励应为 10")

func test_boss_bounty_config() -> void:
	var config: ShopConfig = GameConfig.shop_config
	assert_eq(config.boss_bounty.get("boss_brute", 0), 15)
	assert_eq(config.boss_bounty.get("boss_summoner", 0), 20)
	assert_eq(config.boss_bounty.get("boss_guardian", 0), 30)
	assert_eq(config.boss_bounty.get("nonexistent", 0), 0)
