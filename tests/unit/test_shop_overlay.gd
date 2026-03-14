extends GutTest

var _overlay: CanvasLayer

func before_each() -> void:
	GameData.reset()
	GameData.coins = 20
	_overlay = load("res://scenes/ui/shop_overlay.tscn").instantiate()
	add_child(_overlay)

func after_each() -> void:
	_overlay.queue_free()

func test_refresh_shop_populates_slots() -> void:
	_overlay.refresh_shop(true)
	var has_items := false
	for slot in GameData.shop_slots:
		if slot != null and not slot.is_empty():
			has_items = true
			break
	assert_true(has_items, "刷新后商店应有物品")

func test_start_battle_signal() -> void:
	watch_signals(_overlay)
	_overlay._on_start_pressed()
	assert_signal_emitted(_overlay, "start_battle_pressed")

func test_buy_item_updates_bag() -> void:
	_overlay.refresh_shop(true)
	var slot_index := -1
	for i in range(GameData.shop_slots.size()):
		if GameData.shop_slots[i] != null and not GameData.shop_slots[i].is_empty():
			slot_index = i
			break
	if slot_index >= 0:
		var old_bag_size: int = GameData.bag.size()
		_overlay._on_shop_slot_pressed(slot_index)
		assert_gt(GameData.bag.size(), old_bag_size, "购买后背包应增加物品")
