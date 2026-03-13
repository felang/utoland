extends GutTest

var _original_coins: int
var _original_wave: int
var _original_owned_towers: Dictionary

func before_each():
	_original_coins = GameData.coins
	_original_wave = GameData.current_wave
	_original_owned_towers = GameData.owned_towers.duplicate()
	GameData.coins = 200
	GameData.current_wave = 2
	GameData.owned_towers = {"shooter": 1}

func after_each():
	GameData.coins = _original_coins
	GameData.current_wave = _original_wave
	GameData.owned_towers = _original_owned_towers

func test_shop_generates_tower_options():
	var panel = preload("res://scripts/ui/shop_panel.gd").new()
	panel._generate_shop()
	assert_lte(panel.shop_items.size(), 3, "最多 3 个选项")
	assert_eq(panel.shop_items.size(), panel.shop_prices.size(), "items 和 prices 等长")

func test_shop_buy_upgrades_tower():
	GameData.owned_towers = {"shooter": 1, "wall": 1, "slow": 1}
	var panel = preload("res://scripts/ui/shop_panel.gd").new()
	panel._generate_shop()
	for i in range(panel.shop_items.size()):
		if panel.shop_items[i]["tower_id"] == "shooter":
			var price: int = panel.shop_prices[i]
			GameData.coins = price + 10
			panel._buy_item(i)
			assert_eq(GameData.owned_towers["shooter"], 2, "购买后应升级到 Lv2")
			return
	pass_test("随机未出现 shooter 选项")

func test_shop_refresh_cost():
	var panel = preload("res://scripts/ui/shop_panel.gd").new()
	GameData.current_wave = 1
	assert_eq(panel._get_refresh_cost(), 5)
	GameData.current_wave = 9
	assert_eq(panel._get_refresh_cost(), 12)
