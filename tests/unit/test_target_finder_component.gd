extends GutTest

var finder: TargetFinderComponent

func before_each() -> void:
	finder = TargetFinderComponent.new()
	add_child(finder)

func after_each() -> void:
	finder.queue_free()

func test_get_target_returns_null_when_no_enemies() -> void:
	assert_null(finder.get_target())

func test_set_range_updates_detect_area() -> void:
	finder.set_range(200.0)
	assert_eq(finder.detect_range, 200.0)

func test_target_changed_signal_emitted() -> void:
	watch_signals(finder)
	finder._update_target(null)
	assert_signal_not_emitted(finder, "target_changed")
