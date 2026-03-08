extends Node
## ItemEffectManager — 监听波次事件，处理物品的波次钩子效果
##
## 负责处理：
## - 金矿：每波结束给玩家加金币（GameData.wave_gold_bonus）
## - 战场维修：每波结束给所有塔回HP（GameData.wave_tower_heal_ratio）
## - 战争机器：每波开始扣玩家HP（GameData.war_machine_wave_hp_cost）

func _ready() -> void:
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.wave_started.connect(_on_wave_started)

func _on_wave_completed(wave_number: int) -> void:
	# 金矿：给玩家加金币
	if GameData.wave_gold_bonus > 0:
		GameData.coins += GameData.wave_gold_bonus
		EventBus.coins_changed.emit(GameData.wave_gold_bonus, GameData.coins)

	# 战场维修：所有塔回血
	if GameData.wave_tower_heal_ratio > 0.0:
		var towers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.TOWERS)
		for tower in towers:
			if tower.get("health") != null:
				var heal_amount: float = tower.health.max_hp * GameData.wave_tower_heal_ratio
				tower.health.heal(heal_amount)

func _on_wave_started(_wave_number: int, _wave_data: WaveData) -> void:
	# 战争机器：每波开始扣HP（最低保留1HP，不触发死亡）
	if GameData.war_machine_active and GameData.war_machine_wave_hp_cost > 0:
		var players: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.PLAYER)
		if not players.is_empty():
			var player: Node = players[0]
			if player.get("health") != null:
				player.health.current_hp = maxf(1.0, player.health.current_hp - float(GameData.war_machine_wave_hp_cost))
