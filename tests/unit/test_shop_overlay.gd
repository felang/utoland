extends GutTest

var _overlay: CanvasLayer

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	StatsTracker.reset()
	InventoryManager.coins = 100
	PlayerProgression.player_level = 1
	InventoryManager.deployed_weapons = []
	InventoryManager.deployed_towers = []
	_overlay = load("res://scenes/ui/shop_overlay.tscn").instantiate()
	add_child(_overlay)

func after_each() -> void:
	_overlay.queue_free()

func test_refresh_shop_populates_cards() -> void:
	_overlay.refresh_shop()
	assert_eq(InventoryManager.shop_slots.size(), 4)
	var has_item := false
	for label in _overlay._card_names:
		if label.text != "已售出":
			has_item = true
			break
	assert_true(has_item, "刷新后应有可购买的卡片")

func test_start_battle_signal() -> void:
	watch_signals(_overlay)
	_overlay._on_start_pressed()
	assert_signal_emitted(_overlay, "start_battle_pressed")

func test_card_disabled_when_insufficient_coins() -> void:
	InventoryManager.coins = 0
	_overlay.refresh_shop()
	for i in range(_overlay._card_buttons.size()):
		if i < InventoryManager.shop_slots.size() and not InventoryManager.shop_slots[i].is_empty():
			assert_true(_overlay._card_buttons[i].disabled, "金币不足时卡片应禁用")

func test_recycle_area_exists() -> void:
	assert_not_null(_overlay.get_recycle_area())
