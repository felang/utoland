class_name MapRenderer
extends RefCounted

const GROUND_COLOR := Color("#4a7c3f")
const OBSTACLE_COLOR := Color("#555555")
const SPAWN_MARKER_COLOR := Color("#cc3333")

func render(layout: MapLayout, tilemap: TileMapLayer) -> void:
	var tileset := _create_tileset()
	tilemap.tile_set = tileset
	tilemap.position = Vector2(-GameConfig.MAP_HALF_WIDTH, -GameConfig.MAP_HALF_HEIGHT)
	for y in range(layout.grid_height):
		for x in range(layout.grid_width):
			var grid_pos := Vector2i(x, y)
			var tile_pos := Vector2i(GameConfig.PLAYABLE_ORIGIN_X + x, GameConfig.PLAYABLE_ORIGIN_Y + y)
			var cell := layout.get_cell(grid_pos)
			if cell == MapLayout.CellType.OBSTACLE:
				tilemap.set_cell(tile_pos, 0, Vector2i(1, 0))
			else:
				tilemap.set_cell(tile_pos, 0, Vector2i(0, 0))

func create_colliders(layout: MapLayout, parent: Node2D) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 4  # Layer 3 (Solid) = bitmask 4
	body.collision_mask = 0
	parent.add_child(body)
	for y in range(layout.grid_height):
		for x in range(layout.grid_width):
			if layout.get_cell(Vector2i(x, y)) == MapLayout.CellType.OBSTACLE:
				var shape := CollisionShape2D.new()
				var rect := RectangleShape2D.new()
				rect.size = Vector2(GameConfig.GRID_SIZE, GameConfig.GRID_SIZE)
				shape.shape = rect
				shape.position = layout.grid_to_world(Vector2i(x, y))
				body.add_child(shape)

func create_spawn_markers(layout: MapLayout, parent: Node2D) -> void:
	for dir in layout.spawn_points:
		var world_pos: Vector2 = layout.grid_to_world(layout.spawn_points[dir])
		var marker := Sprite2D.new()
		marker.name = "SpawnMarker_" + dir
		var img := Image.create(GameConfig.GRID_SIZE, GameConfig.GRID_SIZE, false, Image.FORMAT_RGBA8)
		img.fill(SPAWN_MARKER_COLOR)
		marker.texture = ImageTexture.create_from_image(img)
		marker.position = world_pos
		parent.add_child(marker)

func _create_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(GameConfig.GRID_SIZE, GameConfig.GRID_SIZE)
	var img := Image.create(GameConfig.GRID_SIZE * 2, GameConfig.GRID_SIZE, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, GameConfig.GRID_SIZE, GameConfig.GRID_SIZE), GROUND_COLOR)
	img.fill_rect(Rect2i(GameConfig.GRID_SIZE, 0, GameConfig.GRID_SIZE, GameConfig.GRID_SIZE), OBSTACLE_COLOR)
	var tex := ImageTexture.create_from_image(img)
	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(GameConfig.GRID_SIZE, GameConfig.GRID_SIZE)
	ts.add_source(source)
	return ts
