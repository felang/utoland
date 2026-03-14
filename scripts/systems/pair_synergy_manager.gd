class_name PairSynergyManager
extends RefCounted

## 配对协同管理器 — 检测特定单位组合是否同时上阵，激活配对效果

const PAIR_DEFINITIONS: Array[Dictionary] = [
	{id = "frozen_cage", units = ["ice_gun", "vine"], name = "极寒囚笼"},
	{id = "chain_detonation", units = ["rocket", "bamboo"], name = "连环引爆"},
	{id = "bloodthirst", units = ["gorg", "blade"], name = "嗜血狂战"},
	{id = "magic_resonance", units = ["merlin", "mint"], name = "魔力共鸣"},
	{id = "superconductor", units = ["lightning", "ice_flower"], name = "超导风暴"},
	{id = "bullet_time", units = ["kaze", "minigun"], name = "弹幕时刻"},
]

func recalculate() -> void:
	var old_actives: Array[String] = GameData.active_pair_synergies.duplicate()
	var new_actives: Array[String] = []

	# 收集所有上阵单位 ID
	var active_ids: Array[String] = []
	if GameData.current_character != "":
		active_ids.append(GameData.current_character)
	for weapon in GameData.deployed_weapons:
		active_ids.append(weapon.id)
	for tower in GameData.deployed_towers:
		active_ids.append(tower.id)

	# 检查每个配对定义
	for pair in PAIR_DEFINITIONS:
		if active_ids.has(pair.units[0]) and active_ids.has(pair.units[1]):
			new_actives.append(pair.id)

	GameData.active_pair_synergies = new_actives

	# 发射激活/取消信号
	for sid in new_actives:
		if not old_actives.has(sid):
			EventBus.pair_synergy_activated.emit(sid)
	for sid in old_actives:
		if not new_actives.has(sid):
			EventBus.pair_synergy_deactivated.emit(sid)
