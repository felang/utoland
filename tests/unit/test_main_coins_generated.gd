extends GutTest

func test_coins_generated_updates_game_data():
	var old_coins: int = GameData.coins
	var amount: int = 10
	GameData.coins += amount
	assert_eq(GameData.coins, old_coins + amount, "金币应增加")
