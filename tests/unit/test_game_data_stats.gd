extends GutTest

func before_each() -> void:
	GameData.reset()

func test_stats_fields_exist() -> void:
	assert_eq(GameData.total_kills, 0)
	assert_eq(GameData.total_coins_earned, 0)
	assert_eq(GameData.total_damage_taken, 0.0)
	assert_eq(GameData.max_kill_streak, 0)
	assert_eq(GameData.purchased_item_list.size(), 0)
	assert_eq(GameData.current_kill_streak, 0)

func test_record_kill_updates_stats() -> void:
	GameData.reset()
	GameData.record_kill()
	assert_eq(GameData.total_kills, 1)
	assert_eq(GameData.current_kill_streak, 1)
	assert_eq(GameData.max_kill_streak, 1)
	GameData.record_kill()
	assert_eq(GameData.total_kills, 2)
	assert_eq(GameData.current_kill_streak, 2)
	assert_eq(GameData.max_kill_streak, 2)

func test_reset_kill_streak() -> void:
	GameData.reset()
	GameData.record_kill()
	GameData.record_kill()
	GameData.reset_kill_streak()
	assert_eq(GameData.current_kill_streak, 0)
	assert_eq(GameData.max_kill_streak, 2)

func test_record_damage_taken() -> void:
	GameData.reset()
	GameData.record_damage_taken(25.5)
	assert_eq(GameData.total_damage_taken, 25.5)
	GameData.record_damage_taken(10.0)
	assert_eq(GameData.total_damage_taken, 35.5)

func test_record_coins_earned() -> void:
	GameData.reset()
	GameData.record_coins_earned(15)
	assert_eq(GameData.total_coins_earned, 15)

func test_record_item_purchased() -> void:
	GameData.reset()
	GameData.record_item_purchased("sharp_bullet")
	GameData.record_item_purchased("crit_shot")
	assert_eq(GameData.purchased_item_list, ["sharp_bullet", "crit_shot"])

func test_reset_clears_stats() -> void:
	GameData.record_kill()
	GameData.record_damage_taken(50.0)
	GameData.record_coins_earned(100)
	GameData.record_item_purchased("test")
	GameData.reset()
	assert_eq(GameData.total_kills, 0)
	assert_eq(GameData.total_coins_earned, 0)
	assert_eq(GameData.total_damage_taken, 0.0)
	assert_eq(GameData.max_kill_streak, 0)
	assert_eq(GameData.current_kill_streak, 0)
	assert_eq(GameData.purchased_item_list.size(), 0)
