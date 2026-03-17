extends GutTest

func before_each() -> void:
	StatsTracker.reset()

# ===== record_kill =====

func test_record_kill_increments_total() -> void:
	StatsTracker.record_kill()
	assert_eq(StatsTracker.total_kills, 1)
	StatsTracker.record_kill()
	assert_eq(StatsTracker.total_kills, 2)

func test_record_kill_updates_streak() -> void:
	StatsTracker.record_kill()
	assert_eq(StatsTracker.current_kill_streak, 1)
	assert_eq(StatsTracker.max_kill_streak, 1)
	StatsTracker.record_kill()
	assert_eq(StatsTracker.current_kill_streak, 2)
	assert_eq(StatsTracker.max_kill_streak, 2)

# ===== reset_kill_streak =====

func test_reset_kill_streak_keeps_max() -> void:
	StatsTracker.record_kill()
	StatsTracker.record_kill()
	StatsTracker.reset_kill_streak()
	assert_eq(StatsTracker.current_kill_streak, 0)
	assert_eq(StatsTracker.max_kill_streak, 2)

func test_new_streak_after_reset_updates_max() -> void:
	StatsTracker.record_kill()
	StatsTracker.reset_kill_streak()
	StatsTracker.record_kill()
	StatsTracker.record_kill()
	StatsTracker.record_kill()
	assert_eq(StatsTracker.max_kill_streak, 3)

# ===== record_damage_taken =====

func test_record_damage_taken_accumulates() -> void:
	StatsTracker.record_damage_taken(25.5)
	assert_eq(StatsTracker.total_damage_taken, 25.5)
	StatsTracker.record_damage_taken(10.0)
	assert_eq(StatsTracker.total_damage_taken, 35.5)

# ===== record_coins_earned =====

func test_record_coins_earned_accumulates() -> void:
	StatsTracker.record_coins_earned(15)
	assert_eq(StatsTracker.total_coins_earned, 15)
	StatsTracker.record_coins_earned(20)
	assert_eq(StatsTracker.total_coins_earned, 35)

# ===== reset =====

func test_reset_clears_all_stats() -> void:
	StatsTracker.record_kill()
	StatsTracker.record_kill()
	StatsTracker.record_damage_taken(50.0)
	StatsTracker.record_coins_earned(100)
	StatsTracker.reset()
	assert_eq(StatsTracker.total_kills, 0)
	assert_eq(StatsTracker.total_coins_earned, 0)
	assert_eq(StatsTracker.total_damage_taken, 0.0)
	assert_eq(StatsTracker.max_kill_streak, 0)
	assert_eq(StatsTracker.current_kill_streak, 0)
