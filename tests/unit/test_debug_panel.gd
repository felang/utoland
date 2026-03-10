# tests/unit/test_debug_panel.gd
extends GutTest

## DebugPanel 单元测试

var panel: CanvasLayer

func before_each():
	panel = load("res://scripts/ui/debug_panel.gd").new()
	add_child(panel)

func after_each():
	panel.queue_free()

func test_starts_hidden():
	assert_false(panel.visible, "调试面板初始应隐藏")

func test_process_mode_always():
	assert_eq(panel.process_mode, Node.PROCESS_MODE_ALWAYS)

func test_add_coins():
	var before: int = GameData.coins
	GameData.coins += 100
	assert_eq(GameData.coins, before + 100)

func test_godmode_toggle():
	assert_false(panel._godmode)
	panel._toggle_godmode()
	assert_true(panel._godmode)
	panel._toggle_godmode()
	assert_false(panel._godmode)
