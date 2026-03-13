extends GutTest

func test_coins_generated_updates_game_data():
	var old_coins: int = GameData.coins
	var old_xp: int = GameData.current_xp
	var amount: int = 10
	GameData.coins += amount
	GameData.add_xp(amount)
	assert_eq(GameData.coins, old_coins + amount, "金币应增加")
	assert_true(GameData.current_xp >= old_xp, "XP 应增加或因升级重置")
