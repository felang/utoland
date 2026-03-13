extends GutTest

var _original_owned_weapons: Dictionary
var _generator: WeaponUpgradeGenerator

func before_each():
	_original_owned_weapons = GameData.owned_weapons.duplicate()
	_generator = WeaponUpgradeGenerator.new()

func after_each():
	GameData.owned_weapons = _original_owned_weapons

func test_generates_new_weapons_and_upgrades():
	GameData.owned_weapons = {"rifle": 1}
	var options: Array[Dictionary] = _generator.generate_options()
	assert_gt(options.size(), 0, "应生成至少 1 个选项")
	assert_lte(options.size(), 3, "最多 3 个选项")

func test_new_weapon_option_has_level_1():
	GameData.owned_weapons = {"rifle": 5}
	var options: Array[Dictionary] = _generator.generate_options()
	var has_new: bool = false
	for opt in options:
		if opt["weapon_id"] != "rifle":
			assert_eq(opt["target_level"], 1, "新武器应为 Lv1")
			has_new = true
	assert_true(has_new, "应有新武器选项")

func test_upgrade_option_has_next_level():
	GameData.owned_weapons = {"rifle": 2}
	var options: Array[Dictionary] = _generator.generate_options()
	for opt in options:
		if opt["weapon_id"] == "rifle":
			assert_eq(opt["target_level"], 3, "已有 Lv2 武器应升到 Lv3")

func test_max_level_weapon_excluded():
	GameData.owned_weapons = {"rifle": 5, "boomerang": 5, "laser": 5}
	var options: Array[Dictionary] = _generator.generate_options()
	assert_eq(options.size(), 0, "全部满级应返回空")

func test_no_duplicate_options():
	GameData.owned_weapons = {"rifle": 1}
	var options: Array[Dictionary] = _generator.generate_options()
	var ids: Array[String] = []
	for opt in options:
		assert_false(opt["weapon_id"] in ids, "不应有重复武器")
		ids.append(opt["weapon_id"])
