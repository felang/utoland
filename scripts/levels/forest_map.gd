extends Node2D

# 随机装饰生成器
# 每次加载地图时在 Decoration 层随机放置装饰 tile

## 装饰 tile 的 atlas 坐标列表（在 TileSet 编辑器中查看每个装饰 tile 的坐标）
## 示例：Vector2i(3, 1) 表示 tileset 图片中第 4 列第 2 行的 tile
@export var decoration_tiles: Array[Vector2i] = []

## 装饰密度：0.0 ~ 1.0，表示可用格子中放置装饰的概率
@export_range(0.0, 1.0, 0.01) var decoration_density: float = 0.05

## 边缘留白：距离地图边界多少格不放装饰
@export var edge_margin: int = 2

## TileSet source id（通常为 0）
@export var source_id: int = 1

@onready var _decoration_layer: TileMapLayer = $Decoration


func _ready() -> void:
	if decoration_tiles.is_empty():
		return
	_randomize_decorations()


func _randomize_decorations() -> void:
	# 保留手动绘制的装饰，只在空格子上随机添加

	var grid_w: int = GameConfig.MAP_GRID_WIDTH
	var grid_h: int = GameConfig.MAP_GRID_HEIGHT
	var count: int = 0

	print("装饰生成: tileset=", _decoration_layer.tile_set, " tiles=", decoration_tiles, " density=", decoration_density)

	for x in range(edge_margin, grid_w - edge_margin):
		for y in range(edge_margin, grid_h - edge_margin):
			var cell := Vector2i(x, y)
			if _decoration_layer.get_cell_source_id(cell) == -1 and randf() < decoration_density:
				var tile: Vector2i = decoration_tiles[randi() % decoration_tiles.size()]
				_decoration_layer.set_cell(cell, source_id, tile)
				count += 1

	print("装饰生成完成: 共放置 ", count, " 个装饰 tile")
