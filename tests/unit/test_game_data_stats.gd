extends GutTest

func before_each() -> void:
	StatsTracker.reset()

func test_stats_fields_exist() -> void:
	assert_eq(StatsTracker.total_kills, 0)
	assert_eq(StatsTracker.total_coins_earned, 0)
	assert_eq(StatsTracker.total_damage_taken, 0.0)
	assert_eq(StatsTracker.max_kill_streak, 0)
	assert_eq(StatsTracker.current_kill_streak, 0)

func test_record_kill_updates_stats() -> void:
	StatsTracker.reset()
	StatsTracker.record_kill()
	assert_eq(StatsTracker.total_kills, 1)
	assert_eq(StatsTracker.current_kill_streak, 1)
	assert_eq(StatsTracker.max_kill_streak, 1)
	StatsTracker.record_kill()
	assert_eq(StatsTracker.total_kills, 2)
	assert_eq(StatsTracker.current_kill_streak, 2)
	assert_eq(StatsTracker.max_kill_streak, 2)

func test_reset_kill_streak() -> void:
	StatsTracker.reset()
	StatsTracker.record_kill()
	StatsTracker.record_kill()
	StatsTracker.reset_kill_streak()
	assert_eq(StatsTracker.current_kill_streak, 0)
	assert_eq(StatsTracker.max_kill_streak, 2)

func test_record_damage_taken() -> void:
	StatsTracker.reset()
	StatsTracker.record_damage_taken(25.5)
	assert_eq(StatsTracker.total_damage_taken, 25.5)
	StatsTracker.record_damage_taken(10.0)
	assert_eq(StatsTracker.total_damage_taken, 35.5)

func test_record_coins_earned() -> void:
	StatsTracker.reset()
	StatsTracker.record_coins_earned(15)
	assert_eq(StatsTracker.total_coins_earned, 15)

func test_reset_clears_stats() -> void:
	StatsTracker.record_kill()
	StatsTracker.record_damage_taken(50.0)
	StatsTracker.record_coins_earned(100)
	StatsTracker.reset()
	assert_eq(StatsTracker.total_kills, 0)
	assert_eq(StatsTracker.total_coins_earned, 0)
	assert_eq(StatsTracker.total_damage_taken, 0.0)
	assert_eq(StatsTracker.max_kill_streak, 0)
	assert_eq(StatsTracker.current_kill_streak, 0)
