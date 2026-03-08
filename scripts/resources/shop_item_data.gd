class_name ShopItemData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
## 标签数组，对应 Enums.ItemTag 常量
@export var tags: PackedStringArray = PackedStringArray()
@export var rarity: String = Enums.ItemRarity.COMMON
## 效果类型，对应 Enums.ItemEffect 常量
@export var effect_type: String = Enums.ItemEffect.STAT_BOOST
## 效果参数，key 由 effect_type 决定
## stat_boost: {"stat": Enums.Stat.X, "value": float}
## consumable:  {"effect": "heal", "value": int}
## pierce/multishot/lifesteal/kill_stack 等：自定义 key
@export var effect_params: Dictionary = {}
@export var cost_min: int = 20
@export var cost_max: int = 35
## 同一物品最多可购买次数（-1 = 无限，1 = 只能买一次）
@export var max_stack: int = 1
