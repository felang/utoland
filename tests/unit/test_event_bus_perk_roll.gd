extends GutTest

func test_perk_offered_signal_exists() -> void:
	assert_true(EventBus.has_signal("perk_offered"))

func test_perk_selected_signal_exists() -> void:
	assert_true(EventBus.has_signal("perk_selected"))

func test_perk_applied_signal_exists() -> void:
	assert_true(EventBus.has_signal("perk_applied"))

func test_tower_rolled_signal_exists() -> void:
	assert_true(EventBus.has_signal("tower_rolled"))

func test_tower_added_to_queue_signal_exists() -> void:
	assert_true(EventBus.has_signal("tower_added_to_queue"))

func test_tower_consumed_from_queue_signal_exists() -> void:
	assert_true(EventBus.has_signal("tower_consumed_from_queue"))

func test_tower_roll_canceled_signal_exists() -> void:
	assert_true(EventBus.has_signal("tower_roll_canceled"))
