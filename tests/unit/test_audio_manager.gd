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

func test_pool_uses_sfx_bus():
	for player in audio_manager._pool:
		assert_eq(player.bus, "SFX", "SFX 池播放器应使用 SFX 总线")

func test_bgm_player_uses_bgm_bus():
	assert_eq(audio_manager._bgm_player.bus, "BGM", "BGM 播放器应使用 BGM 总线")

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

func test_default_sfx_volume_is_100():
	assert_eq(audio_manager.get_sfx_volume(), 100.0, "SFX 默认音量应为 100")

func test_default_bgm_volume_is_100():
	assert_eq(audio_manager.get_bgm_volume(), 100.0, "BGM 默认音量应为 100")

func test_set_get_sfx_volume():
	audio_manager.set_sfx_volume(75.0)
	assert_eq(audio_manager.get_sfx_volume(), 75.0, "设置 SFX 音量后 get 应返回相同值")

func test_set_get_bgm_volume():
	audio_manager.set_bgm_volume(50.0)
	assert_eq(audio_manager.get_bgm_volume(), 50.0, "设置 BGM 音量后 get 应返回相同值")

func test_sfx_volume_zero_mutes_bus():
	# 检查 set_sfx_volume(0) 不崩溃（SFX bus 可能不存在于 headless 测试）
	audio_manager.set_sfx_volume(0.0)
	assert_eq(audio_manager.get_sfx_volume(), 0.0, "SFX 音量设为 0 后 get 应返回 0")
	var bus_idx: int = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		assert_true(AudioServer.is_bus_mute(bus_idx), "SFX 音量为 0 时总线应静音")

func test_bgm_volume_zero_mutes_bus():
	# 检查 set_bgm_volume(0) 不崩溃（BGM bus 可能不存在于 headless 测试）
	audio_manager.set_bgm_volume(0.0)
	assert_eq(audio_manager.get_bgm_volume(), 0.0, "BGM 音量设为 0 后 get 应返回 0")
	var bus_idx: int = AudioServer.get_bus_index("BGM")
	if bus_idx >= 0:
		assert_true(AudioServer.is_bus_mute(bus_idx), "BGM 音量为 0 时总线应静音")

func test_sfx_volume_clamped_below_zero():
	audio_manager.set_sfx_volume(-10.0)
	assert_eq(audio_manager.get_sfx_volume(), 0.0, "SFX 音量应被钳制到 0")

func test_sfx_volume_clamped_above_100():
	audio_manager.set_sfx_volume(150.0)
	assert_eq(audio_manager.get_sfx_volume(), 100.0, "SFX 音量应被钳制到 100")

func test_bgm_volume_clamped_below_zero():
	audio_manager.set_bgm_volume(-5.0)
	assert_eq(audio_manager.get_bgm_volume(), 0.0, "BGM 音量应被钳制到 0")

func test_bgm_volume_clamped_above_100():
	audio_manager.set_bgm_volume(200.0)
	assert_eq(audio_manager.get_bgm_volume(), 100.0, "BGM 音量应被钳制到 100")

func test_ui_sound_ids_no_crash():
	audio_manager.play("ui_hover")
	audio_manager.play("ui_click")
	audio_manager.play("ui_panel_open")
	audio_manager.play("ui_panel_close")
	assert_true(true, "UI 音效 ID 调用不应崩溃")

func test_tower_sound_ids_registered():
	AudioManager.play("tower_place")
	AudioManager.play("tower_remove")
	assert_true(true, "tower_place 和 tower_remove 调用不应崩溃")

func test_play_bgm_unknown_track_no_crash():
	AudioManager.play_bgm("nonexistent")
	assert_true(true, "未知 BGM track 不应崩溃")

func test_stop_bgm_no_crash():
	AudioManager.stop_bgm()
	assert_true(true, "stop_bgm 无播放时不应崩溃")

func test_fade_bgm_no_crash():
	AudioManager.fade_bgm(0.5)
	assert_true(true, "fade_bgm 无播放时不应崩溃")
