extends GutTest

func test_setup_button_hover_connects_signals():
	var btn := Button.new()
	add_child(btn)
	UIUtils.setup_button_hover(btn)
	assert_true(btn.mouse_entered.get_connections().size() > 0, "应连接 mouse_entered")
	assert_true(btn.mouse_exited.get_connections().size() > 0, "应连接 mouse_exited")
	btn.queue_free()

func test_setup_button_hover_connects_button_down():
	var btn := Button.new()
	add_child(btn)
	UIUtils.setup_button_hover(btn)
	assert_true(btn.button_down.get_connections().size() > 0, "应连接 button_down")
	btn.queue_free()

func test_setup_button_hover_connects_button_up():
	var btn := Button.new()
	add_child(btn)
	UIUtils.setup_button_hover(btn)
	assert_true(btn.button_up.get_connections().size() > 0, "应连接 button_up")
	btn.queue_free()

func test_setup_button_hover_stores_tween_meta():
	var btn := Button.new()
	add_child(btn)
	UIUtils.setup_button_hover(btn)
	btn.emit_signal("mouse_entered")
	await get_tree().process_frame
	assert_true(btn.has_meta("_hover_tween"), "应存储 _hover_tween meta")
	btn.queue_free()
