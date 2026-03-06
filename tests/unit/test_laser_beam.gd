extends GutTest

# 激光视觉效果实体单元测试

func test_laser_beam_creation():
	var beam: Node2D = SceneFactory.create_laser_beam()
	assert_not_null(beam, "激光应被创建")
	beam.queue_free()

func test_laser_beam_has_line2d():
	var beam: Node2D = SceneFactory.create_laser_beam()
	add_child_autofree(beam)
	var line: Line2D = beam.get_node("Line2D")
	assert_not_null(line, "激光应包含 Line2D 子节点")

func test_laser_beam_default_duration():
	var beam: Node2D = SceneFactory.create_laser_beam()
	assert_eq(beam.beam_duration, 0.08, "默认持续时间应为 0.08 秒")
	beam.queue_free()
