extends GutTest

## PauseOverlay 单元测试

var overlay: CanvasLayer

func before_each():
	overlay = load("res://scripts/ui/pause_overlay.gd").new()
	add_child(overlay)

func after_each():
	overlay.queue_free()
	get_tree().paused = false

func test_starts_hidden():
	assert_false(overlay.visible, "暂停覆盖层初始应隐藏")

func test_toggle_pause_shows_overlay():
	overlay._toggle_pause()
	assert_true(overlay.visible, "暂停后应显示")
	assert_true(get_tree().paused, "暂停后 tree.paused 应为 true")

func test_toggle_pause_twice_resumes():
	overlay._toggle_pause()
	overlay._toggle_pause()
	assert_false(overlay.visible, "恢复后应隐藏")
	assert_false(get_tree().paused, "恢复后 tree.paused 应为 false")

func test_process_mode_always():
	assert_eq(overlay.process_mode, Node.PROCESS_MODE_ALWAYS, "暂停时仍需处理输入")
