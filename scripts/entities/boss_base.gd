extends "res://scripts/entities/enemy.gd"

# Boss 基类 — 死亡时额外发出 boss_killed 信号

func _on_died() -> void:
	EventBus.boss_killed.emit(enemy_type)
	super._on_died()
