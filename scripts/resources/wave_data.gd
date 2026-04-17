class_name WaveData
extends Resource

# 基础配置
@export var wave_number: int = 1
@export var time_limit: float = 60.0

# 分段生成
@export var max_alive_enemies: int = 30
@export var spawn_phases: Array[SpawnPhaseData] = []

# 敌人权重（默认，段内可覆盖）
@export var enemy_weights: Dictionary = {"normal": 100}

# 精英怪
@export var elite_chance: float = 0.0
@export var elite_hp_mult: float = 1.5
@export var elite_damage_mult: float = 1.3
@export var elite_scale: float = 1.2
@export var elite_exp_mult: float = 2.0

# Boss 波
@export var is_boss_wave: bool = false
@export var boss_id: String = ""

# 刷新点方向覆盖（空=走自动规则）
@export var active_spawn_directions: Array[String] = []
