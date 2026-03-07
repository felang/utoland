extends GutTest

# SpriteAnimator 单元测试

func test_sprite_animator_exists_on_enemy():
	var enemy = SceneFactory.create_enemy("normal")
	add_child_autoqfree(enemy)
	var animator = enemy.get_node_or_null("SpriteAnimator")
	assert_not_null(animator, "Enemy 应有 SpriteAnimator 子节点")
	assert_true(animator is SpriteAnimator, "应为 SpriteAnimator 类型")

func test_sprite_animator_exists_on_player():
	var player_scene = preload("res://scenes/entities/player.tscn")
	var player = player_scene.instantiate()
	add_child_autoqfree(player)
	var animator = player.get_node_or_null("SpriteAnimator")
	assert_not_null(animator, "Player 应有 SpriteAnimator 子节点")
	assert_true(animator is SpriteAnimator, "应为 SpriteAnimator 类型")

func test_has_update_animation_method():
	var animator = SpriteAnimator.new()
	add_child_autoqfree(animator)
	assert_true(animator.has_method("update_animation"), "应有 update_animation 方法")
	assert_true(animator.has_method("update_animation_no_idle"), "应有 update_animation_no_idle 方法")

func test_has_setup_methods():
	var animator = SpriteAnimator.new()
	add_child_autoqfree(animator)
	assert_true(animator.has_method("setup_player_sprite"), "应有 setup_player_sprite 方法")
	assert_true(animator.has_method("setup_enemy_sprite"), "应有 setup_enemy_sprite 方法")

func test_enemy_sprite_setup_creates_visual():
	var enemy = SceneFactory.create_enemy("normal")
	add_child_autoqfree(enemy)
	await get_tree().process_frame
	# _ready 中 SpriteAnimator 应创建 AnimatedSprite2D
	var visual = enemy.get_node_or_null("Visual")
	# Visual 应存在（可能是新的 AnimatedSprite2D 或旧的 ColorRect 已被替换）
	assert_not_null(visual, "敌人应有 Visual 节点")
