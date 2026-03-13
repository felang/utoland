extends GutTest

var _original_owned_weapons: Dictionary
var _original_owned_towers: Dictionary
var _generator: UpgradeGenerator

func before_each():
	_original_owned_weapons = GameData.owned_weapons.duplicate()
	_original_owned_towers = GameData.owned_towers.duplicate()
	_generator = UpgradeGenerator.new()

func after_each():
	GameData.owned_weapons = _original_owned_weapons
	GameData.owned_towers = _original_owned_towers

func test_generates_mixed_options():
	GameData.owned_weapons = {"rifle": 1}
	GameData.owned_towers = {"pea_shooter": 1}
	var options: Array[Dictionary] = _generator.generate_options()
	assert_gt(options.size(), 0, "应生成至少 1 个选项")
	assert_lte(options.size(), 3, "最多 3 个选项")
	for opt in options:
		assert_true(opt["type"] in ["weapon", "tower"], "type 应为 weapon 或 tower")
		assert_true(opt.has("id"), "应有 id 字段")
		assert_true(opt.has("target_level"), "应有 target_level 字段")
		assert_true(opt.has("is_new"), "应有 is_new 字段")
		assert_true(opt.has("current_level"), "应有 current_level 字段")

func test_new_item_has_level_1():
	GameData.owned_weapons = {"rifle": 5, "boomerang": 5, "laser": 5}
	GameData.owned_towers = {"pea_shooter": 5, "stump": 5}
	var options: Array[Dictionary] = _generator.generate_options()
	for opt in options:
		if opt["is_new"]:
			assert_eq(opt["target_level"], 1, "新物品应为 Lv1")
			assert_eq(opt["current_level"], 0, "新物品 current_level 应为 0")

func test_upgrade_has_next_level():
	GameData.owned_weapons = {"rifle": 2}
	GameData.owned_towers = {"pea_shooter": 3}
	var options: Array[Dictionary] = _generator.generate_options()
	for opt in options:
		if opt["id"] == "rifle":
			assert_eq(opt["target_level"], 3)
			assert_eq(opt["current_level"], 2)
		if opt["id"] == "pea_shooter":
			assert_eq(opt["target_level"], 4)
			assert_eq(opt["current_level"], 3)

func test_max_level_excluded():
	GameData.owned_weapons = {"rifle": 5, "boomerang": 5, "laser": 5, "shotgun": 5, "minigun": 5, "ice_gun": 5}
	GameData.owned_towers = {"pea_shooter": 5, "stump": 5, "ice_flower": 5}
	var options: Array[Dictionary] = _generator.generate_options()
	assert_eq(options.size(), 0, "全部满级应返回空")

func test_no_duplicate_options():
	GameData.owned_weapons = {"rifle": 1}
	GameData.owned_towers = {"pea_shooter": 1}
	var options: Array[Dictionary] = _generator.generate_options()
	var keys: Array[String] = []
	for opt in options:
		var key: String = opt["type"] + ":" + opt["id"]
		assert_false(key in keys, "不应有重复选项")
		keys.append(key)

func test_exclude_filters_options():
	GameData.owned_weapons = {"rifle": 1}
	GameData.owned_towers = {"pea_shooter": 1}
	var first: Array[Dictionary] = _generator.generate_options()
	if first.size() > 0:
		var second: Array[Dictionary] = _generator.generate_options(first)
		for opt in second:
			var key: String = opt["type"] + ":" + opt["id"]
			for excluded in first:
				var ex_key: String = excluded["type"] + ":" + excluded["id"]
				assert_ne(key, ex_key, "排除的选项不应再出现")

func test_refresh_cost_formula():
	assert_eq(_generator.get_refresh_cost(0), 0, "首次刷新免费")
	assert_eq(_generator.get_refresh_cost(1), 5, "第二次刷新 5 金币")
	assert_eq(_generator.get_refresh_cost(2), 10, "第三次刷新 10 金币")
	assert_eq(_generator.get_refresh_cost(3), 15, "第四次刷新 15 金币")
