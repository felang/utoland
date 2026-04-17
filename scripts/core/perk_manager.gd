extends Node
## PerkManager — 按角色专属 perk_pool 抽取，分类 + max_level 限流
##
## 使用流程:
##   1. PlayerProgression.add_exp() 触发 player_level_changed
##   2. PerkManager 按分类抽 3 个 perk → emit perk_offered
##   3. UI 弹窗，玩家点选一个 → 调 select_perk(perk_id)
##   4. PerkManager 应用效果 → emit perk_applied
##
## 分类抽取规则:将可用 perk 按 Category 分组，随机选 3 个分类，
## 各抽 1 个未满级的 perk。若可用分类不足 3 个，则尽量多抽。
## 多次升级排队:_pending_levelups 计数，UI 关闭后立即触发下一轮。

var _all_perks: Array[PerkData] = []
var _current_offer: Array[PerkData] = []
var _pending_levelups: int = 0
var _perk_levels: Dictionary = {}  # perk_id -> int

func _ready() -> void:
	EventBus.player_level_changed.connect(_on_player_level_changed)

## 从当前角色的 CharacterData.perk_pool 加载 perk 池
func refresh_pool_for_current_character() -> void:
	_all_perks.clear()
	var char_data: CharacterData = GameConfig.characters.get(PlayerState.current_character)
	if char_data and char_data.perk_pool:
		for p in char_data.perk_pool:
			if p:
				_all_perks.append(p)

func _on_player_level_changed(_new_level: int) -> void:
	_pending_levelups += 1
	if _current_offer.is_empty():
		_offer_next()

func _offer_next() -> void:
	if _pending_levelups <= 0:
		return
	_pending_levelups -= 1
	var drawn: Array[PerkData] = _draw_three()
	if drawn.is_empty():
		EventBus.no_perk_available.emit()
		return
	_current_offer = drawn
	EventBus.perk_offered.emit(_current_offer)

func _draw_three() -> Array[PerkData]:
	# 按分类分组，只保留未满级的 perk
	var by_cat: Dictionary = {}
	for p in _all_perks:
		if get_perk_level(p.id) >= p.max_level:
			continue
		if not by_cat.has(p.category):
			by_cat[p.category] = []
		by_cat[p.category].append(p)
	var cats: Array = by_cat.keys()
	if cats.is_empty():
		return []
	cats.shuffle()
	var picked: Array[PerkData] = []
	for cat in cats:
		if picked.size() >= 3:
			break
		var arr: Array = by_cat[cat]
		if arr.is_empty():
			continue
		picked.append(arr[randi() % arr.size()])
	return picked

func select_perk(perk_id: String) -> bool:
	# UI 调用，提交玩家选择
	var picked: PerkData = null
	for p in _current_offer:
		if p.id == perk_id:
			picked = p
			break
	if picked == null:
		return false
	_apply_effect(picked)
	_perk_levels[perk_id] = get_perk_level(perk_id) + 1
	EventBus.perk_selected.emit(perk_id)
	EventBus.perk_applied.emit(perk_id)
	_current_offer = []
	# 队列里还有等待中的升级，立刻再抽一组
	if _pending_levelups > 0:
		_offer_next()
	return true

func _apply_effect(perk: PerkData) -> void:
	match perk.effect_type:
		PerkData.EffectType.HP_PERCENT:
			_add(Enums.Stat.HP_BONUS_PERCENT, perk.effect_value)
		PerkData.EffectType.MOVE_SPEED_PERCENT:
			_add(Enums.Stat.MOVE_SPEED_BONUS_PERCENT, perk.effect_value)
		PerkData.EffectType.DAMAGE_PERCENT:
			_add(Enums.Stat.DAMAGE_BONUS_PERCENT, perk.effect_value)
		PerkData.EffectType.ATTACK_SPEED_PERCENT:
			_add(Enums.Stat.ATTACK_SPEED_BONUS_PERCENT, perk.effect_value)
		PerkData.EffectType.PICKUP_RADIUS_PERCENT:
			_add(Enums.Stat.PICKUP_RADIUS_BONUS_PERCENT, perk.effect_value)
		PerkData.EffectType.COIN_DROP_PERCENT:
			_add(Enums.Stat.COIN_DROP_BONUS_PERCENT, perk.effect_value)
		PerkData.EffectType.EXP_GAIN_PERCENT:
			_add(Enums.Stat.EXP_GAIN_BONUS_PERCENT, perk.effect_value)
		PerkData.EffectType.ABILITY_CUSTOM:
			pass  # 能力组件自行监听 perk_applied 信号处理
		_:
			push_warning("未知 perk effect_type: " + str(perk.effect_type))

func _add(stat_key: String, delta: float) -> void:
	var cur: float = PlayerState.player_stats.get(stat_key, 0.0)
	PlayerState.player_stats[stat_key] = cur + delta

func reset() -> void:
	# 一局结束清理状态（_all_perks 保留，避免需要重新加载）
	_current_offer = []
	_pending_levelups = 0
	_perk_levels.clear()

func has_pending() -> bool:
	return not _current_offer.is_empty() or _pending_levelups > 0

func get_current_offer() -> Array:
	return _current_offer.duplicate()

func get_perk_level(perk_id: String) -> int:
	return _perk_levels.get(perk_id, 0)

# ===== 测试辅助方法 =====

func set_pool_for_test(pool: Array[PerkData]) -> void:
	_all_perks = pool.duplicate()

func get_pool_for_test() -> Array[PerkData]:
	return _all_perks

func force_level_for_test(perk_id: String, level: int) -> void:
	_perk_levels[perk_id] = level

func draw_three_for_test() -> Array[PerkData]:
	return _draw_three()

func trigger_offer_for_test() -> void:
	_pending_levelups = maxi(_pending_levelups, 1)
	_offer_next()
