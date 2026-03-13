extends GutTest

var _original_owned_towers: Dictionary
var _generator: TowerShopGenerator

func before_each():
	_original_owned_towers = GameData.owned_towers.duplicate()
	_generator = TowerShopGenerator.new()

func after_each():
	GameData.owned_towers = _original_owned_towers

func test_generates_options_with_prices():
	GameData.owned_towers = {"shooter": 1}
	var result: Dictionary = _generator.generate_options()
	assert_true(result.has("items"), "应有 items 数组")
	assert_true(result.has("prices"), "应有 prices 数组")
	assert_gt(result["items"].size(), 0, "应有至少 1 个选项")
	assert_lte(result["items"].size(), 3, "最多 3 个选项")
	assert_eq(result["items"].size(), result["prices"].size(), "items 和 prices 等长")

func test_new_tower_price_is_level_1():
	GameData.owned_towers = {"shooter": 5}
	var result: Dictionary = _generator.generate_options()
	for i in range(result["items"].size()):
		var item: Dictionary = result["items"][i]
		if item["is_new"]:
			var td: TowerData = GameConfig.towers[item["tower_id"]]
			assert_eq(result["prices"][i], td.shop_price_per_level[0], "新塔价格应为 Lv1 购买价")

func test_upgrade_price_reads_per_level():
	GameData.owned_towers = {"shooter": 2}
	var result: Dictionary = _generator.generate_options()
	for i in range(result["items"].size()):
		var item: Dictionary = result["items"][i]
		if item["tower_id"] == "shooter" and not item["is_new"]:
			var td: TowerData = GameConfig.towers["shooter"]
			assert_eq(result["prices"][i], td.shop_price_per_level[2], "Lv2→3 价格应读 shop_price_per_level[2]")

func test_max_level_excluded():
	GameData.owned_towers = {"shooter": 5, "wall": 5, "slow": 5}
	var result: Dictionary = _generator.generate_options()
	assert_eq(result["items"].size(), 0, "全部满级应返回空")

func test_empty_slots_when_pool_small():
	GameData.owned_towers = {"shooter": 5, "wall": 5}
	var result: Dictionary = _generator.generate_options()
	assert_lte(result["items"].size(), 1, "只剩 slow 一个选项")
