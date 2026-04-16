extends Node
## Perk 管理器 — 监听升级 → 抽 3 个 perk → 等待 UI 选择 → 应用效果
##
## 使用流程:
##   1. PlayerProgression.add_exp() 触发 player_level_changed
##   2. PerkManager 抽 3 个 perk → emit perk_offered
##   3. UI 弹窗,玩家点选一个 → 调 select_perk(perk_id)
##   4. PerkManager 应用效果 → emit perk_applied
##
## 多次升级排队:_pending_levelups 计数,UI 关闭后立即触发下一轮。

const PERK_FILES: Array[String] = [
	"res://resources/perks/vitality.tres",
	"res://resources/perks/swift.tres",
	"res://resources/perks/power.tres",
	"res://resources/perks/rapid.tres",
	"res://resources/perks/reach.tres",
	# "res://resources/perks/greed.tres",  # 待 #5 敌人掉金币机制接入后取消注释
	"res://resources/perks/study.tres",
	"res://resources/perks/expansion.tres",
]

var _all_perks: Array = []           # Array[PerkData]
var _current_offer: Array = []       # Array[PerkData],当前等待玩家选择
var _pending_levelups: int = 0       # 排队中的升级次数

func _ready() -> void:
	_load_all_perks()
	EventBus.player_level_changed.connect(_on_player_level_changed)

func _load_all_perks() -> void:
	_all_perks.clear()
	for path in PERK_FILES:
		var perk: PerkData = load(path)
		if perk:
			_all_perks.append(perk)

func _on_player_level_changed(_new_level: int) -> void:
	_pending_levelups += 1
	if _current_offer.is_empty():
		_offer_next()

func _offer_next() -> void:
	if _pending_levelups <= 0:
		return
	_pending_levelups -= 1
	_current_offer = _draw_three()
	EventBus.perk_offered.emit(_current_offer)

func _draw_three() -> Array:
	# 抽 3 个不重复
	var pool: Array = _all_perks.duplicate()
	pool.shuffle()
	return pool.slice(0, mini(3, pool.size()))

func select_perk(perk_id: String) -> bool:
	# UI 调用,提交玩家选择
	var picked: PerkData = null
	for p in _current_offer:
		if p.id == perk_id:
			picked = p
			break
	if picked == null:
		return false
	_apply_effect(picked)
	EventBus.perk_selected.emit(perk_id)
	EventBus.perk_applied.emit(perk_id)
	_current_offer = []
	# 队列里还有等待中的升级,立刻再抽一组
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
		PerkData.EffectType.POPULATION_FLAT:
			var cur: int = PlayerState.player_stats.get(Enums.Stat.POPULATION_BONUS, 0)
			PlayerState.player_stats[Enums.Stat.POPULATION_BONUS] = cur + int(perk.effect_value)
		_:
			push_warning("未知 perk effect_type: " + str(perk.effect_type))

func _add(stat_key: String, delta: float) -> void:
	var cur: float = PlayerState.player_stats.get(stat_key, 0.0)
	PlayerState.player_stats[stat_key] = cur + delta

func reset() -> void:
	# 一局结束清理状态
	_current_offer = []
	_pending_levelups = 0

func has_pending() -> bool:
	return not _current_offer.is_empty() or _pending_levelups > 0

func get_current_offer() -> Array:
	return _current_offer.duplicate()
