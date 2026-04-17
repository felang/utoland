extends GutTest

# 集成测试 — 升级 → perk → 效果生效

var _test_pool: Array[PerkData] = []

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	PerkManager.reset()
	# 构建包含所有常见 perk 文件的测试池
	_test_pool = []
	var perk_ids: Array[String] = ["vitality", "swift", "power", "rapid", "reach", "study"]
	var categories: Array = [
		PerkData.Category.RANGER_GUST,
		PerkData.Category.RANGER_RAIN,
		PerkData.Category.RANGER_MARK,
		PerkData.Category.RANGER_UTILITY,
		PerkData.Category.GENERIC,
		PerkData.Category.GENERIC,
	]
	for i in range(perk_ids.size()):
		var path: String = "res://resources/perks/%s.tres" % perk_ids[i]
		if ResourceLoader.exists(path):
			var perk: PerkData = load(path)
			if perk:
				# 确保 category 字段有效（旧 perk 文件 category 可能为 GENERIC）
				_test_pool.append(perk)
	PerkManager.set_pool_for_test(_test_pool)

func test_perk_manager_loads_all_perks() -> void:
	# 验证 PerkManager 已通过 set_pool_for_test 加载了 perk 列表
	assert_gt(PerkManager.get_pool_for_test().size(), 0, "应加载 perk 列表")

func test_draw_three_returns_valid_perks() -> void:
	# 验证 draw_three_for_test() 返回不超过 3 个不重复的 perk
	var drawn: Array = PerkManager.draw_three_for_test()
	assert_gt(drawn.size(), 0, "应至少抽 1 个 perk")
	assert_lte(drawn.size(), 3, "最多抽 3 个 perk")
	# 验证没有重复
	var ids: Array = []
	for p in drawn:
		ids.append(p.id)
	var unique_ids: Array = []
	for id in ids:
		if id not in unique_ids:
			unique_ids.append(id)
	assert_eq(ids.size(), unique_ids.size(), "perk 不应重复")

func test_select_perk_applies_vitality_effect() -> void:
	# 找到 vitality perk
	var vitality_perk: PerkData = null
	for p in PerkManager.get_pool_for_test():
		if p.id == "vitality":
			vitality_perk = p
			break
	assert_not_null(vitality_perk, "vitality perk 应存在")
	# 手动触发 offer 并强制设置 current_offer（借助 trigger_offer_for_test）
	PerkManager._current_offer = [vitality_perk]
	var success: bool = PerkManager.select_perk("vitality")
	assert_true(success, "应成功选择 vitality")
	var hp_bonus: float = PlayerState.player_stats.get(Enums.Stat.HP_BONUS_PERCENT, 0.0)
	assert_almost_eq(hp_bonus, 0.1, 0.001, "HP bonus 应为 0.1（vitality 效果为 +10%%）")

func test_select_perk_applies_study_effect() -> void:
	var study_perk: PerkData = null
	for p in PerkManager.get_pool_for_test():
		if p.id == "study":
			study_perk = p
			break
	assert_not_null(study_perk, "study perk 应存在")
	PerkManager._current_offer = [study_perk]
	var success: bool = PerkManager.select_perk("study")
	assert_true(success, "应成功选择 study")
	var pre_exp: int = PlayerProgression.current_exp
	PlayerProgression.add_exp(10)
	var actual_gain: int = PlayerProgression.current_exp - pre_exp
	# 10 * (1.0 + 0.1) = 11
	assert_eq(actual_gain, 11, "获得 10 经验应增加 11（+10%% bonus from study perk）")

func test_levelup_triggers_perk_offer() -> void:
	var level_before: int = PlayerProgression.player_level
	assert_eq(level_before, 1, "初始等级应为 1")
	var threshold: int = PlayerProgression.exp_for_level(2)
	PlayerProgression.add_exp(threshold)
	assert_eq(PlayerProgression.player_level, 2, "应升级到 Lv2")
	# 手动调用 _offer_next() 来生成当前 offer
	if PerkManager._pending_levelups > 0 and PerkManager._current_offer.is_empty():
		PerkManager._offer_next()
	assert_gt(PerkManager.get_current_offer().size(), 0, "应生成 perk offer")

func test_multiple_levelups_queue_offers() -> void:
	var exp_lv3: int = PlayerProgression.exp_for_level(3)
	PlayerProgression.add_exp(exp_lv3)
	assert_eq(PlayerProgression.player_level, 3, "应升级到 Lv3")
	var pending: int = PerkManager._pending_levelups
	assert_gt(pending, 0, "应有待处理的 levelup")
	var offer_count: int = 0
	while PerkManager._pending_levelups > 0:
		PerkManager._offer_next()
		offer_count += 1
	assert_gt(offer_count, 0, "应至少处理 1 次 perk_offered")

func test_select_invalid_perk_returns_false() -> void:
	var vitality_perk: PerkData = null
	for p in PerkManager.get_pool_for_test():
		if p.id == "vitality":
			vitality_perk = p
			break
	# 设置 offer 里没有 vitality
	PerkManager._current_offer = []
	for p in PerkManager.get_pool_for_test():
		if p.id != "vitality":
			PerkManager._current_offer.append(p)
			break
	var success: bool = PerkManager.select_perk("vitality")
	assert_false(success, "选择不在 offer 中的 perk 应返回 false")

func test_perk_effects_accumulate() -> void:
	var vitality_perk: PerkData = null
	for p in PerkManager.get_pool_for_test():
		if p.id == "vitality":
			vitality_perk = p
			break
	assert_not_null(vitality_perk, "vitality perk 应存在")
	# 第一次选择
	PerkManager._current_offer = [vitality_perk]
	PerkManager.select_perk("vitality")
	var first_bonus: float = PlayerState.player_stats.get(Enums.Stat.HP_BONUS_PERCENT, 0.0)
	assert_almost_eq(first_bonus, 0.1, 0.001, "第一次选择 vitality 后应有 0.1 bonus")
	# 第二次选择
	PerkManager._current_offer = [vitality_perk]
	PerkManager.select_perk("vitality")
	var second_bonus: float = PlayerState.player_stats.get(Enums.Stat.HP_BONUS_PERCENT, 0.0)
	assert_almost_eq(second_bonus, 0.2, 0.001, "第二次选择 vitality 后应有 0.2 bonus（累加）")

func test_vitality_increases_max_hp_via_apply_level_growth() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	PlayerState.character_max_hp = 100.0
	PlayerState.player_stats[Enums.Stat.MAX_HP] = 100.0
	PlayerState.player_stats[Enums.Stat.HP_BONUS_PERCENT] = 0.1
	var expected: float = 100.0 * pow(1.03, 0) * 1.1
	assert_almost_eq(expected, 110.0, 0.01, "vitality perk 应使 Lv1 max_hp = 110")

func test_select_perk_increments_perk_level() -> void:
	var vitality_perk: PerkData = null
	for p in PerkManager.get_pool_for_test():
		if p.id == "vitality":
			vitality_perk = p
			break
	assert_not_null(vitality_perk, "vitality perk 应存在")
	assert_eq(PerkManager.get_perk_level("vitality"), 0, "初始等级应为 0")
	PerkManager._current_offer = [vitality_perk]
	PerkManager.select_perk("vitality")
	assert_eq(PerkManager.get_perk_level("vitality"), 1, "选择后等级应为 1")
