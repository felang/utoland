class_name ExpConfig
extends Resource

## 经验升级公式参数：exp_for_level(n) = floor(base_exp * n ^ exp_exponent)
@export var base_exp: float = 5.0
@export var exp_exponent: float = 2.0

## 人口系统
@export var initial_population: int = 2
@export var population_per_level: int = 1
