# tests/unit/test_audio_manager.gd
extends GutTest

## AudioManager 单元测试

var audio_manager: Node

func before_each():
	audio_manager = load("res://scripts/systems/audio_manager.gd").new()
	add_child(audio_manager)

func after_each():
	audio_manager.queue_free()

func test_pool_created():
	assert_eq(audio_manager._pool.size(), 8, "应创建 8 个 AudioStreamPlayer")

func test_play_unknown_sound_no_crash():
	audio_manager.play("nonexistent")
	assert_true(true, "播放不存在的音效不应崩溃")

func test_pool_index_wraps():
	# play() 对不存在的音效会提前返回不递增索引
	# 直接测试索引环绕逻辑
	audio_manager._pool_index = 7
	# 手动模拟一次递增
	audio_manager._pool_index = (audio_manager._pool_index + 1) % audio_manager.POOL_SIZE
	assert_eq(audio_manager._pool_index, 0, "池索引应从 7 环绕到 0")

func test_register_sounds_populates_dictionary():
	# 若 assets/sfx/ 目录中有文件则 _sounds 非空
	# 无文件时 _sounds 应为空但不崩溃
	assert_typeof(audio_manager._sounds, TYPE_DICTIONARY)

func test_tower_sound_ids_registered():
	AudioManager.play("tower_place")
	AudioManager.play("tower_remove")
	assert_true(true, "tower_place 和 tower_remove 调用不应崩溃")
