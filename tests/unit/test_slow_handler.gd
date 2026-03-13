extends GutTest

func test_single_slow_applies():
	var sh := SlowHandler.new()
	add_child(sh)
	sh.initialize(100.0)
	watch_signals(sh)
	sh.apply_slow(0.3, "tower_1")
	assert_signal_emitted(sh, "speed_changed")
	var params = get_signal_parameters(sh, "speed_changed")
	assert_almost_eq(params[0], 70.0, 0.01, "减速 30% 后速度应为 70")
	sh.queue_free()

func test_remove_slow_restores():
	var sh := SlowHandler.new()
	add_child(sh)
	sh.initialize(100.0)
	sh.apply_slow(0.3, "tower_1")
	watch_signals(sh)
	sh.remove_slow("tower_1")
	assert_signal_emitted(sh, "speed_changed")
	var params = get_signal_parameters(sh, "speed_changed")
	assert_almost_eq(params[0], 100.0, 0.01, "移除减速后速度应恢复")
	sh.queue_free()

func test_max_value_stacking():
	var sh := SlowHandler.new()
	add_child(sh)
	sh.initialize(100.0)
	sh.apply_slow(0.3, "tower_1")
	watch_signals(sh)
	sh.apply_slow(0.5, "tower_2")
	# max(0.3, 0.5) = 0.5 → speed = 50
	assert_signal_emitted(sh, "speed_changed")
	var params = get_signal_parameters(sh, "speed_changed")
	assert_almost_eq(params[0], 50.0, 0.01, "取最大减速值 50%，速度应为 50")
	sh.queue_free()

func test_remove_one_of_two_slows():
	var sh := SlowHandler.new()
	add_child(sh)
	sh.initialize(100.0)
	sh.apply_slow(0.3, "tower_1")
	sh.apply_slow(0.5, "tower_2")
	watch_signals(sh)
	sh.remove_slow("tower_2")
	# only tower_1's 0.3 → speed = 70
	assert_signal_emitted(sh, "speed_changed")
	var params = get_signal_parameters(sh, "speed_changed")
	assert_almost_eq(params[0], 70.0, 0.01, "移除较大减速源后应用 30% 减速")
	sh.queue_free()

func test_timed_slow_expires():
	var sh := SlowHandler.new()
	add_child(sh)
	sh.initialize(100.0)
	watch_signals(sh)
	sh.apply_timed_slow(0.3, 0.1, "bullet_1")
	assert_signal_emitted(sh, "speed_changed", "定时减速应立即生效")
	var params = get_signal_parameters(sh, "speed_changed")
	assert_almost_eq(params[0], 70.0, 0.01, "减速 30% 后速度应为 70")
	# wait for expiry
	await get_tree().create_timer(0.2).timeout
	var params2 = get_signal_parameters(sh, "speed_changed")
	assert_almost_eq(params2[0], 100.0, 0.01, "定时减速应已过期，速度恢复")
	sh.queue_free()
