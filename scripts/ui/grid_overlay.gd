class_name GridOverlay
extends Node2D
# 全地图网格线覆层

const GRID_COLOR = Color(1, 1, 1, 0.15)
# 防止浮点数漂移导致边界线被遗漏的容差值
const FLOAT_EPSILON = 0.01

func _draw() -> void:
	var half_w: float = GameConfig.MAP_HALF_WIDTH
	var half_h: float = GameConfig.MAP_HALF_HEIGHT

	# 竖线
	for x in get_vertical_line_positions():
		draw_line(Vector2(x, -half_h), Vector2(x, half_h), GRID_COLOR)

	# 横线
	for y in get_horizontal_line_positions():
		draw_line(Vector2(-half_w, y), Vector2(half_w, y), GRID_COLOR)

func get_vertical_line_positions() -> Array[float]:
	var positions: Array[float] = []
	var gs: float = GameConfig.GRID_SIZE
	var half_w: float = GameConfig.MAP_HALF_WIDTH
	var x: float = -half_w
	while x <= half_w + FLOAT_EPSILON:
		positions.append(x)
		x += gs
	return positions

func get_horizontal_line_positions() -> Array[float]:
	var positions: Array[float] = []
	var gs: float = GameConfig.GRID_SIZE
	var half_h: float = GameConfig.MAP_HALF_HEIGHT
	var y: float = -half_h
	while y <= half_h + FLOAT_EPSILON:
		positions.append(y)
		y += gs
	return positions
