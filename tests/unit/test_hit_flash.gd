extends GutTest

# 受击闪白和无敌帧闪烁测试

func test_enemy_has_flash_method():
	var enemy = SceneFactory.create_enemy("normal")
	add_child_autoqfree(enemy)
	assert_true(enemy.has_method("_flash_white"), "敌人应有 _flash_white 方法")

func test_enemy_flash_changes_modulate():
	var enemy = SceneFactory.create_enemy("normal")
	add_child_autoqfree(enemy)
	await get_tree().process_frame
	var original: Color = enemy.modulate
	enemy._flash_white()
	# 闪白瞬间 modulate 应改变（变亮）
	assert_ne(enemy.modulate, original, "闪白瞬间 modulate 应改变")

func test_player_has_blink_method():
	var player_scene = preload("res://scenes/entities/player.tscn")
	var player = player_scene.instantiate()
	add_child_autoqfree(player)
	assert_true(player.has_method("_start_invincible_blink"), "玩家应有 _start_invincible_blink 方法")
