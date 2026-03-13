extends GutTest

func test_setup_button_hover_connects_signals():
	var btn := Button.new()
	add_child(btn)
	UIUtils.setup_button_hover(btn)
	assert_true(btn.mouse_entered.get_connections().size() > 0, "应连接 mouse_entered")
	assert_true(btn.mouse_exited.get_connections().size() > 0, "应连接 mouse_exited")
	btn.queue_free()
