extends GutTest

func test_debug_panel_has_zoom_actions():
	# 验证 input map 中存在 zoom action
	assert_true(InputMap.has_action("debug_zoom_in"), "debug_zoom_in action 应存在")
	assert_true(InputMap.has_action("debug_zoom_out"), "debug_zoom_out action 应存在")
