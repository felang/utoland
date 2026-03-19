extends GutTest

func test_wave_reward_tiers() -> void:
	var config: ShopConfig = GameConfig.shop_config
	assert_eq(config.get_wave_reward(1), 5, "Wave 1 奖励应为 5")
	assert_eq(config.get_wave_reward(5), 5, "Wave 5 奖励应为 5")
	assert_eq(config.get_wave_reward(6), 8, "Wave 6 奖励应为 8")
	assert_eq(config.get_wave_reward(10), 8, "Wave 10 奖励应为 8")
	assert_eq(config.get_wave_reward(11), 10, "Wave 11 奖励应为 10")
	assert_eq(config.get_wave_reward(15), 10, "Wave 15 奖励应为 10")

func test_boss_bounty_config() -> void:
	var config: ShopConfig = GameConfig.shop_config
	assert_eq(config.boss_bounty.get("boss_brute", 0), 15)
	assert_eq(config.boss_bounty.get("boss_summoner", 0), 20)
	assert_eq(config.boss_bounty.get("boss_guardian", 0), 30)
	assert_eq(config.boss_bounty.get("nonexistent", 0), 0)
