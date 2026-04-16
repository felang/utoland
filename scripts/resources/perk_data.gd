class_name PerkData
extends Resource

# Perk 效果类型 — 每个 perk 修改 PlayerState.player_stats 中的一个字段
enum EffectType {
	HP_PERCENT,
	MOVE_SPEED_PERCENT,
	DAMAGE_PERCENT,
	ATTACK_SPEED_PERCENT,
	PICKUP_RADIUS_PERCENT,
	COIN_DROP_PERCENT,
	EXP_GAIN_PERCENT,
	POPULATION_FLAT,
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export_file("*.png") var icon_path: String = ""
@export var effect_type: EffectType = EffectType.HP_PERCENT
@export var effect_value: float = 0.0
