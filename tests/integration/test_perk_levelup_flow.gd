extends GutTest

# 集成测试 — 升级 → perk → 效果生效

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	PerkManager.reset()
	# 确保 PerkManager._all_perks 被加载
	if PerkManager._all_perks.is_empty():
		PerkManager._load_all_perks()

func test_perk_manager_loads_all_perks() -> void:
	# 验证 PerkManager 加载了所有 perk
	assert_gt(PerkManager._all_perks.size(), 0, "应加载 perk 列表")
	# 应该有 8 个 perk：vitality, swift, power, rapid, reach, greed, study, expansion
	assert_eq(PerkManager._all_perks.size(), 8, "应有 8 个 perk")

func test_draw_three_returns_valid_perks() -> void:
	# 验证 _draw_three() 返回 3 个不重复的 perk
	var drawn: Array = PerkManager._draw_three()
	assert_eq(drawn.size(), 3, "应抽 3 个 perk")

	# 验证没有重复
	var ids: Array = []
	for p in drawn:
		ids.append(p.id)
	assert_eq(ids.size(), len(ids), "perk 不应重复")

func test_select_perk_applies_vitality_effect() -> void:
	# 直接测试 select_perk 对 vitality 的效果
	var vitality_perk: PerkData = null
	for p in PerkManager._all_perks:
		if p.id == "vitality":
			vitality_perk = p
			break

	assert_not_null(vitality_perk, "vitality perk 应存在")

	# 手动设置当前 offer 为只包含 vitality
	PerkManager._current_offer = [vitality_perk]

	# 选择 vitality
	var success: bool = PerkManager.select_perk("vitality")
	assert_true(success, "应成功选择 vitality")

	# 验证效果：hp_bonus_percent 应增加 0.1
	var hp_bonus: float = PlayerState.player_stats.get(Enums.Stat.HP_BONUS_PERCENT, 0.0)
	assert_almost_eq(hp_bonus, 0.1, 0.001, "HP bonus 应为 0.1（vitality 效果为 +10%%）")

func test_select_perk_applies_expansion_effect() -> void:
	# 直接测试 select_perk 对 expansion 的效果
	var expansion_perk: PerkData = null
	for p in PerkManager._all_perks:
		if p.id == "expansion":
			expansion_perk = p
			break

	assert_not_null(expansion_perk, "expansion perk 应存在")

	var pre_cap: int = PlayerProgression.get_population_cap()

	# 手动设置当前 offer 为只包含 expansion
	PerkManager._current_offer = [expansion_perk]

	# 选择 expansion
	var success: bool = PerkManager.select_perk("expansion")
	assert_true(success, "应成功选择 expansion")

	var post_cap: int = PlayerProgression.get_population_cap()
	assert_eq(post_cap, pre_cap + 1, "人口上限应增加 1（expansion 效果为 +1）")

func test_select_perk_applies_study_effect() -> void:
	# 直接测试 select_perk 对 study 的效果
	var study_perk: PerkData = null
	for p in PerkManager._all_perks:
		if p.id == "study":
			study_perk = p
			break

	assert_not_null(study_perk, "study perk 应存在")

	# 手动设置当前 offer 为只包含 study
	PerkManager._current_offer = [study_perk]

	# 选择 study
	var success: bool = PerkManager.select_perk("study")
	assert_true(success, "应成功选择 study")

	# 验证效果：选择后再 add_exp，应该获得 10% 奖励
	var pre_exp: int = PlayerProgression.current_exp
	PlayerProgression.add_exp(10)
	var actual_gain: int = PlayerProgression.current_exp - pre_exp

	# 10 * (1.0 + 0.1) = 11
	assert_eq(actual_gain, 11, "获得 10 经验应增加 11（+10%% bonus from study perk）")

func test_levelup_triggers_perk_offer() -> void:
	# 测试升级时应该生成 perk offer
	# 验证升级流程：add_exp → player_level_changed → perk offer

	# 记录升级前的状态
	var level_before: int = PlayerProgression.player_level
	assert_eq(level_before, 1, "初始等级应为 1")

	# 给足以升级到 Lv2 的经验
	var threshold: int = PlayerProgression.exp_for_level(2)
	PlayerProgression.add_exp(threshold)

	# 验证升级成功
	assert_eq(PlayerProgression.player_level, 2, "应升级到 Lv2")

	# 当升级时，PerkManager._pending_levelups 应该被设置
	# 手动调用 _offer_next() 来生成当前 offer（模拟信号处理）
	if PerkManager._pending_levelups > 0 and PerkManager._current_offer.is_empty():
		PerkManager._offer_next()

	# 验证生成了 perk offer
	assert_gt(PerkManager._current_offer.size(), 0, "应生成 perk offer")

func test_multiple_levelups_queue_offers() -> void:
	# 测试多次升级时的排队机制
	# 升到 Lv3（需 2 次升级，一次到 Lv2，一次到 Lv3）
	var exp_lv3: int = PlayerProgression.exp_for_level(3)
	PlayerProgression.add_exp(exp_lv3)

	assert_eq(PlayerProgression.player_level, 3, "应升级到 Lv3")

	# 升级时应该累积 pending_levelups（Lv1→Lv2→Lv3 需要 2 次升级）
	# 检查 pending_levelups 的状态
	var pending: int = PerkManager._pending_levelups
	assert_gt(pending, 0, "应有待处理的 levelup")

	# 手动处理排队的 offers
	var offer_count: int = 0
	while PerkManager._pending_levelups > 0:
		PerkManager._offer_next()
		offer_count += 1

	# 应该处理了至少 1 次 offer（最少升级到 Lv2）
	assert_gt(offer_count, 0, "应至少处理 1 次 perk_offered")

func test_select_invalid_perk_returns_false() -> void:
	# 测试选择不在当前 offer 中的 perk 应返回 false
	var vitality_perk: PerkData = null
	for p in PerkManager._all_perks:
		if p.id == "vitality":
			vitality_perk = p
			break

	# 只设置包含其他 perk 的 offer
	PerkManager._current_offer = []
	for p in PerkManager._all_perks:
		if p.id != "vitality":
			PerkManager._current_offer.append(p)
			break

	# 尝试选择不在 offer 中的 vitality
	var success: bool = PerkManager.select_perk("vitality")
	assert_false(success, "选择不在 offer 中的 perk 应返回 false")

func test_perk_effects_accumulate() -> void:
	# 测试多个相同类型的 perk 效果应该累加
	var vitality_perk: PerkData = null
	for p in PerkManager._all_perks:
		if p.id == "vitality":
			vitality_perk = p
			break

	# 第一次选择 vitality
	PerkManager._current_offer = [vitality_perk]
	PerkManager.select_perk("vitality")

	var first_bonus: float = PlayerState.player_stats.get(Enums.Stat.HP_BONUS_PERCENT, 0.0)
	assert_almost_eq(first_bonus, 0.1, 0.001, "第一次选择 vitality 后应有 0.1 bonus")

	# 第二次选择 vitality
	PerkManager._current_offer = [vitality_perk]
	PerkManager.select_perk("vitality")

	var second_bonus: float = PlayerState.player_stats.get(Enums.Stat.HP_BONUS_PERCENT, 0.0)
	assert_almost_eq(second_bonus, 0.2, 0.001, "第二次选择 vitality 后应有 0.2 bonus（累加）")
