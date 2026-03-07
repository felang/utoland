extends GutTest

# SpriteAnimator 单元测试

func test_sprite_animator_exists_on_enemy():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
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

