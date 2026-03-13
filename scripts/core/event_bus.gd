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

# 战斗事件
signal enemy_killed(enemy_type: String, position: Vector2, is_elite: bool)
signal boss_killed(boss_id: String)
signal player_damaged(damage: float, current_hp: float)
signal player_died()

# 经济事件
signal coins_changed(amount: int, total: int)
signal coin_collected(value: int, position: Vector2)
signal coins_generated(amount: int, position: Vector2)

# 等级系统
signal player_leveled_up(level: int)
signal xp_changed(current_xp: int, xp_to_next: int)

# 视觉反馈
signal camera_shake_requested(intensity: float, duration: float)

# 塔防事件
signal tower_placed(tower_type: String, position: Vector2)
signal tower_destroyed(tower_type: String, position: Vector2)
signal tower_upgraded(tower_type: String)
signal tower_purchased(tower_type: String)
