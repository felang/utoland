class_name SpriteConfigData
extends Resource

@export var idle_texture_path: String = ""
@export var walk_texture_path: String = ""
@export var spritesheet_path: String = ""
@export var frame_size: Vector2 = Vector2(16, 16)
@export var idle_frames: int = 4
@export var walk_frames: int = 4
@export var walk_directions: int = 4
@export var fps: float = 8.0

# 方向判定滞后阈值
@export var direction_hysteresis_keep: float = 0.7
@export var direction_hysteresis_switch: float = 1.4
