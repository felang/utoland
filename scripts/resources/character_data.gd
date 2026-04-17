class_name CharacterData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var max_hp: float = 100.0
@export var speed: float = 100.0
@export var starting_gold: int = 0

## 精灵 SpriteFrames 资源路径
@export var sprite_frames_path: String = ""
## 头像 PNG 路径
@export var portrait_path: String = ""
## 原始精灵像素尺寸
@export var sprite_pixel_size: float = 16.0

## 专属经验曲线（null 时后备 GameConfig.exp_config）
@export var exp_config: ExpConfig = null
## 专属 perk 池
@export var perk_pool: Array[PerkData] = []
## 能力组件场景，按顺序挂到 Player $Abilities 下
@export var ability_scenes: Array[PackedScene] = []
