extends GutTest

# 受击闪白和无敌帧闪烁测试

func test_enemy_flash_changes_modulate():
	var enemy = SceneFactory.create_enemy("normal")
	add_child_autoqfree(enemy)
	await get_tree().process_frame
	var original: Color = enemy.modulate
	enemy._flash_white()
	# 闪白瞬间 modulate 应改变（变亮）
	assert_ne(enemy.modulate, original, "闪白瞬间 modulate 应改变")

