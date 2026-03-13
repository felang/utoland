extends GutTest

func before_each() -> void:
	GameData.reset()

func test_xp_fields_initialized() -> void:
	assert_eq(GameData.current_level, 1)
	assert_eq(GameData.current_xp, 0)
	assert_eq(GameData.pending_upgrades, 0)

func test_get_xp_to_next_level_formula() -> void:
	GameData.current_level = 1
	assert_eq(GameData.get_xp_to_next_level(), 20)
	GameData.current_level = 2
	assert_eq(GameData.get_xp_to_next_level(), 35)
	GameData.current_level = 5
	assert_eq(GameData.get_xp_to_next_level(), 80)

func test_add_xp_accumulates() -> void:
	GameData.add_xp(10)
	assert_eq(GameData.current_xp, 10)
	assert_eq(GameData.current_level, 1)
	assert_eq(GameData.pending_upgrades, 0)

func test_add_xp_triggers_level_up() -> void:
	GameData.add_xp(20)
	assert_eq(GameData.current_level, 2)
	assert_eq(GameData.current_xp, 0)
	assert_eq(GameData.pending_upgrades, 1)

func test_add_xp_multiple_levels() -> void:
	GameData.add_xp(60)
	assert_eq(GameData.current_level, 3)
	assert_eq(GameData.current_xp, 5)
	assert_eq(GameData.pending_upgrades, 2)

func test_add_xp_emits_signals() -> void:
	var level_ups: Array[int] = []
	var xp_changes: Array[Dictionary] = []
	EventBus.player_leveled_up.connect(func(level: int): level_ups.append(level))
	EventBus.xp_changed.connect(func(xp: int, to_next: int): xp_changes.append({"xp": xp, "to_next": to_next}))
	GameData.add_xp(25)
	assert_eq(level_ups, [2])
	assert_true(xp_changes.size() > 0)
	for conn in EventBus.player_leveled_up.get_connections():
		EventBus.player_leveled_up.disconnect(conn["callable"])
	for conn in EventBus.xp_changed.get_connections():
		EventBus.xp_changed.disconnect(conn["callable"])

func test_reset_clears_xp_fields() -> void:
	GameData.add_xp(50)
	GameData.reset()
	assert_eq(GameData.current_level, 1)
	assert_eq(GameData.current_xp, 0)
	assert_eq(GameData.pending_upgrades, 0)
