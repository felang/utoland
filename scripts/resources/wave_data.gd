class_name WaveData
extends Resource

# 基础配置
@export var wave_number: int = 1
@export var total_enemies: int = 15
@export var time_limit: float = 60.0
@export var spawn_interval: float = 1.5

# 敌人权重
@export var enemy_weights: Dictionary = {"normal": 100}

# 精英怪
@export var elite_chance: float = 0.0
@export var elite_hp_mult: float = 1.5
@export var elite_damage_mult: float = 1.3
@export var elite_coin_mult: float = 2.0
@export var elite_scale: float = 1.2
@export var elite_exp_mult: float = 2.0

# Boss 波
@export var is_boss_wave: bool = false
@export var boss_id: String = ""
@export var boss_escort_count: int = 0
