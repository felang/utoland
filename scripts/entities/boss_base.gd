extends "res://scripts/entities/enemy.gd"

# Boss 基类 — 死亡时额外发出 boss_killed 信号 + 慢动作

func _on_died() -> void:
	EventBus.boss_killed.emit(enemy_type)
	var fx: EffectConfigData = GameConfig.effects
	EffectsManager.hitstop(fx.hitstop_time_scale, fx.hitstop_duration)
	super._on_died()
