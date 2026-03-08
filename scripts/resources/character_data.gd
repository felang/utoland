class_name CharacterData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var max_hp: float = 100.0
@export var speed: float = 200.0
@export var damage_mult: float = 1.0
@export var attack_speed_mult: float = 1.0
@export var move_speed_mult: float = 1.0
@export var hp_regen: float = 0.0
## 角色默认武器 ID（对应 Enums.WeaponId）
@export var default_weapon: String = ""
## 亲和标签数组（对应 Enums.ItemTag 常量）
@export var affinity_tags: PackedStringArray = PackedStringArray()
## 亲和折扣倍率（0.15 = 亲和物品降价15%）
@export var affinity_discount: float = 0.15
## 角色特色被动描述（展示用）
@export var passive_description: String = ""
