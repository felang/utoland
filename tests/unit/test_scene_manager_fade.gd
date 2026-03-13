extends GutTest

func test_scene_manager_has_fade_overlay():
	var canvas: CanvasLayer = null
	for child in SceneManager.get_children():
		if child is CanvasLayer:
			canvas = child
			break
	assert_not_null(canvas, "SceneManager 应有 CanvasLayer 遮罩")

func test_fade_overlay_initially_transparent():
	var rect: ColorRect = null
	for child in SceneManager.get_children():
		if child is CanvasLayer:
			for sub in child.get_children():
				if sub is ColorRect:
					rect = sub
					break
	assert_not_null(rect, "应有 ColorRect 遮罩")
	if rect:
		assert_eq(rect.color.a, 0.0, "遮罩初始应完全透明")

func test_scene_bgm_mapping_exists():
	for scene_name in SceneManager.SCENES.keys():
		assert_true(SceneManager.SCENE_BGM.has(scene_name),
			"场景 %s 应有 BGM 映射" % scene_name)
