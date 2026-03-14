class_name SynergyData
extends Resource

## 羁绊数据资源 — 定义单个标签的羁绊效果

@export var id: String = ""
@export var tag: String = ""
@export var display_name: String = ""
@export var tier_thresholds: PackedInt32Array = PackedInt32Array([2, 3, 5])

# 2 档效果参数（纯数值加成）
@export var tier2_stat: String = ""  # damage_mult / control_duration / aoe_range / max_hp / boost_strength
@export var tier2_value: float = 0.0

# 3 档效果参数（机制型）
@export var tier3_id: String = ""  # frenzy / vulnerable / chain_blast / emergency_shield / self_boost
@export var tier3_value: float = 0.0
@export var tier3_value_2: float = 0.0
@export var tier3_duration: float = 0.0

# 5 档效果参数（终极机制型）
@export var tier5_id: String = ""  # overkill / chain_freeze / tactical_bomb / undying / global_boost
@export var tier5_value: float = 0.0
@export var tier5_value_2: float = 0.0
@export var tier5_duration: float = 0.0
