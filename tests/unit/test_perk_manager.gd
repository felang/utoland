extends GutTest

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	PerkManager.reset()
	# 确保信号连接未被其他测试断开
	if not EventBus.player_level_changed.is_connected(PerkManager._on_player_level_changed):
		EventBus.player_level_changed.connect(PerkManager._on_player_level_changed)

func test_perk_manager_loads_all_perks() -> void:
	# _all_perks 私有,通过抽 3 个验证池子可用
	var offer: Array = PerkManager._draw_three()
	assert_eq(offer.size(), 3)

func test_player_level_changed_offers_perks() -> void:
	var emitted: Array = []
	var conn := func(perks: Array) -> void:
		emitted.append_array(perks)
	EventBus.perk_offered.connect(conn)
	EventBus.player_level_changed.emit(2)
	assert_eq(emitted.size(), 3)
	EventBus.perk_offered.disconnect(conn)

func test_select_perk_applies_hp_bonus() -> void:
	EventBus.player_level_changed.emit(2)
	var offer: Array = PerkManager.get_current_offer()
	# 强制选 vitality(把 vitality 放进 offer)
	for p in PerkManager._all_perks:
		if p.id == "vitality":
			PerkManager._current_offer = [p]
			break
	var ok: bool = PerkManager.select_perk("vitality")
	assert_true(ok)
	assert_almost_eq(PlayerState.player_stats[Enums.Stat.HP_BONUS_PERCENT], 0.1, 0.001)

func test_select_unknown_perk_returns_false() -> void:
	EventBus.player_level_changed.emit(2)
	var ok: bool = PerkManager.select_perk("nonexistent_perk_id")
	assert_false(ok)

func test_multiple_levelups_queue() -> void:
	EventBus.player_level_changed.emit(2)
	EventBus.player_level_changed.emit(3)
	# 第一次 offer 已发出,第二次进队列
	assert_eq(PerkManager._pending_levelups, 1)

func test_select_triggers_next_offer() -> void:
	# 模拟两次升级排队 → 选完第一个后第二个自动弹出
	EventBus.player_level_changed.emit(2)
	EventBus.player_level_changed.emit(3)
	var first_offer: Array = PerkManager.get_current_offer()
	var first_perk_id: String = first_offer[0].id
	PerkManager.select_perk(first_perk_id)
	# 选完后 _current_offer 应该重新被填(因为 _pending_levelups 还有)
	var next_offer: Array = PerkManager.get_current_offer()
	assert_eq(next_offer.size(), 3)

func test_reset_clears_state() -> void:
	EventBus.player_level_changed.emit(2)
	EventBus.player_level_changed.emit(3)
	PerkManager.reset()
	assert_eq(PerkManager.get_current_offer().size(), 0)
	assert_false(PerkManager.has_pending())
