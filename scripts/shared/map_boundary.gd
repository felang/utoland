extends Node2D

# 根据 GameConfig 动态计算的地图尺寸设置碰撞墙位置和大小

const WALL_THICKNESS: float = 32.0

func _ready() -> void:
	var half_w: float = GameConfig.PLAY_HALF_WIDTH
	var half_h: float = GameConfig.PLAY_HALF_HEIGHT
	var play_w: float = GameConfig.PLAY_HALF_WIDTH * 2.0 + WALL_THICKNESS
	var play_h: float = GameConfig.PLAY_HALF_HEIGHT * 2.0 + WALL_THICKNESS

	# TopWall
	var top: StaticBody2D = $TopWall
	top.position = Vector2(0, -(half_h + WALL_THICKNESS / 2.0))
	_set_wall_shape(top, Vector2(play_w, WALL_THICKNESS))

	# BottomWall
	var bottom: StaticBody2D = $BottomWall
	bottom.position = Vector2(0, half_h + WALL_THICKNESS / 2.0)
	_set_wall_shape(bottom, Vector2(play_w, WALL_THICKNESS))

	# LeftWall
	var left: StaticBody2D = $LeftWall
	left.position = Vector2(-(half_w + WALL_THICKNESS / 2.0), 0)
	_set_wall_shape(left, Vector2(WALL_THICKNESS, play_h))

	# RightWall
	var right: StaticBody2D = $RightWall
	right.position = Vector2(half_w + WALL_THICKNESS / 2.0, 0)
	_set_wall_shape(right, Vector2(WALL_THICKNESS, play_h))

func _set_wall_shape(wall: StaticBody2D, size: Vector2) -> void:
	var shape: CollisionShape2D = wall.get_node("CollisionShape2D")
	if shape and shape.shape is RectangleShape2D:
		shape.shape.size = size
