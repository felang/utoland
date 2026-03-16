extends GutTest

var _overlay: CanvasLayer

func before_each() -> void:
	GameData.reset()
	GameData.coins = 100
	GameData.player_level = 1
	GameData.deployed_weapons = []
	GameData.deployed_towers = []
	_overlay = load("res://scenes/ui/shop_overlay.tscn").instantiate()
	add_child(_overlay)

func after_each() -> void:
	_overlay.queue_free()

func test_refresh_shop_populates_cards() -> void:
	_overlay.refresh_shop()
	assert_eq(GameData.shop_slots.size(), 4)
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
	GameData.coins = 0
	_overlay.refresh_shop()
	for i in range(_overlay._card_buttons.size()):
		if i < GameData.shop_slots.size() and not GameData.shop_slots[i].is_empty():
			assert_true(_overlay._card_buttons[i].disabled, "金币不足时卡片应禁用")

func test_recycle_area_exists() -> void:
	assert_not_null(_overlay.get_recycle_area())
