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
