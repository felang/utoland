extends GutTest

var _original_coins: int
var _original_wave: int
var _original_character: String
var _original_purchased: Dictionary

func before_each():
	_original_coins = GameData.coins
	_original_wave = GameData.current_wave
	_original_character = GameData.current_character
	_original_purchased = GameData.purchased_items.duplicate()
	GameData.coins = 200
	GameData.current_wave = 1
	GameData.purchased_items = {}

func after_each():
	GameData.coins = _original_coins
	GameData.current_wave = _original_wave
	GameData.current_character = _original_character
	GameData.purchased_items = _original_purchased

func test_shop_panel_generates_items():
	var panel = preload("res://scripts/ui/shop_panel.gd").new()
	panel._generate_shop()
	assert_eq(panel.shop_items.size(), 4, "应生成 4 件物品")
	assert_eq(panel.shop_prices.size(), 4, "应生成 4 个价格")

func test_shop_panel_buy_deducts_coins():
	var panel = preload("res://scripts/ui/shop_panel.gd").new()
	panel._generate_shop()
	var initial_coins: int = GameData.coins
	var price: int = panel.shop_prices[0]
	panel._buy_item(0)
	assert_eq(GameData.coins, initial_coins - price, "购买应扣除金币")

func test_shop_panel_refresh_cost():
	var panel = preload("res://scripts/ui/shop_panel.gd").new()
	GameData.current_wave = 1
	assert_eq(panel._get_refresh_cost(), 5)
	GameData.current_wave = 9
	assert_eq(panel._get_refresh_cost(), 12)
	GameData.current_wave = 20
	assert_eq(panel._get_refresh_cost(), 12, "超出范围应返回最后一个值")
