extends GutTest

var _overlay: CanvasLayer

func before_each() -> void:
	GameData.reset()
	GameData.coins = 20
	GameData.deployed_weapons = []
	GameData.deployed_towers = []
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

func test_buy_weapon_updates_deployed() -> void:
	GameData.coins = 100
	GameData.shop_slots = [
		{id = "bow", type = "weapon", cost = 3},
		{}, {}, {}
	]
	_overlay._on_shop_slot_pressed(0)
	assert_eq(GameData.deployed_weapons.size(), 1, "购买武器后应出现在 deployed_weapons")
	assert_eq(GameData.deployed_weapons[0].id, "bow")
