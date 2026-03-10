class_name MapData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var preview_image: String = ""
@export var background: String = ""
@export var fallback_color: String = "#2d5016"
@export var wave_count: int = 10
@export var map_scene: String = ""  # 指向对应地图场景，如 res://scenes/levels/maps/forest.tscn
