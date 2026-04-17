extends Node
## 全局事件总线 — 集中管理跨系统信号通信
##
## 所有系统间的事件均通过 EventBus 发布/订阅，避免系统间直接耦合。

# 波次系统
signal wave_started(wave_number: int, wave_data: WaveData)
signal wave_completed(wave_number: int)
signal wave_transition_ready()
signal game_won()
signal game_lost()
signal boss_escaped(boss_id: String)

# 战斗事件
signal enemy_killed(enemy_type: String, position: Vector2, is_elite: bool)
signal boss_killed(boss_id: String)
signal player_damaged(damage: float, current_hp: float)
signal player_died()

# 经济事件
signal coins_changed(amount: int, total: int)
signal coin_collected(value: int, position: Vector2)
signal coins_generated(amount: int, position: Vector2)

# 经验事件
signal exp_collected(value: int, position: Vector2)
signal exp_changed(current_exp: int, exp_to_next: int)

# 视觉反馈
signal camera_shake_requested(intensity: float, duration: float)

# 塔防事件
signal tower_placed(tower_type: String, position: Vector2)
signal tower_destroyed(tower_type: String, position: Vector2)

# 商店系统
signal item_purchased(item: Dictionary)
signal item_sold(item: Dictionary, refund: int)
signal item_merged(item_id: String, new_level: int)
signal player_level_changed(new_level: int)
signal tower_moved(deploy_id: int, old_pos: Vector2i, new_pos: Vector2i)

# Perk 系统(战斗中 3 选 1 升级)
signal perk_offered(perks: Array)            # Array[PerkData]
signal perk_selected(perk_id: String)
signal perk_applied(perk_id: String)         # 应用完毕广播,UI 可刷新
signal no_perk_available()                   # 所有 perk 已满级,无可抽取
signal hunt_mark_applied(enemy: Node2D)      # 猎标施加到敌人
signal hunt_mark_cleared(enemy: Node2D)      # 猎标从敌人移除

# Roll 塔系统
signal tower_rolled(candidates: Array)       # Array[String](3 个 tower_id)
signal tower_added_to_queue(tower_id: String)
signal tower_consumed_from_queue(index: int)
signal tower_roll_canceled()
