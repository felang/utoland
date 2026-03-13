extends GutTest

func test_map_boundary_walls_match_game_config():
	var boundary_scene = load("res://scenes/shared/map_boundary.tscn")
	var boundary = boundary_scene.instantiate()
	add_child_autoqfree(boundary)
	await get_tree().process_frame

	var half_w: float = GameConfig.MAP_HALF_WIDTH
	var half_h: float = GameConfig.MAP_HALF_HEIGHT
	var wall_thickness: float = 16.0

	# 检查墙壁位置（含半个墙厚偏移）
	var top: StaticBody2D = boundary.get_node("TopWall")
	var bottom: StaticBody2D = boundary.get_node("BottomWall")
	var left: StaticBody2D = boundary.get_node("LeftWall")
	var right: StaticBody2D = boundary.get_node("RightWall")

	assert_almost_eq(top.position.y, -(half_h + wall_thickness / 2.0), 1.0, "TopWall y 位置")
	assert_almost_eq(bottom.position.y, half_h + wall_thickness / 2.0, 1.0, "BottomWall y 位置")
	assert_almost_eq(left.position.x, -(half_w + wall_thickness / 2.0), 1.0, "LeftWall x 位置")
	assert_almost_eq(right.position.x, half_w + wall_thickness / 2.0, 1.0, "RightWall x 位置")
