extends GutTest

# EffectsManager 单元测试

func test_hitstop_changes_time_scale():
	EffectsManager.hitstop(0.05, 0.01)
	assert_lt(Engine.time_scale, 1.0, "time_scale 应小于 1")
	await get_tree().create_timer(0.05, true, false, true).timeout
	assert_eq(Engine.time_scale, 1.0, "time_scale 应恢复为 1.0")

func test_flash_hit_changes_modulate():
	var sprite := Sprite2D.new()
	add_child(sprite)
	var original_mod: Color = sprite.modulate
	EffectsManager.flash_hit(sprite)
	assert_ne(sprite.modulate, original_mod, "modulate 应被改为红色")
	await get_tree().create_timer(0.1).timeout
	assert_eq(sprite.modulate, original_mod, "modulate 应恢复原色")
	sprite.queue_free()

func test_spawn_enhanced_death_creates_nodes():
	# headless 测试中 current_scene 可能为 null，节点会挂在 EffectsManager 上
	var tree: SceneTree = get_tree()
	var target_node: Node = tree.current_scene if tree.current_scene else EffectsManager
	var before_count: int = target_node.get_child_count()
	EffectsManager.spawn_enhanced_death(Vector2(100, 100), Color.RED)
	var after_count: int = target_node.get_child_count()
	assert_gt(after_count, before_count, "应创建死亡特效节点")

