extends GutTest
## EventBus 信号测试 — 验证所有跨系统信号可正常发射和接收

func test_event_bus_exists():
	assert_not_null(EventBus, "EventBus Autoload 应存在")

func test_wave_started_signal():
	watch_signals(EventBus)
	var wd := WaveData.new()
	wd.duration = 45.0
	EventBus.wave_started.emit(1, wd)
	assert_signal_emitted(EventBus, "wave_started")

func test_wave_completed_signal():
	watch_signals(EventBus)
	EventBus.wave_completed.emit(1)
	assert_signal_emitted(EventBus, "wave_completed")

func test_game_won_signal():
	watch_signals(EventBus)
	EventBus.game_won.emit()
	assert_signal_emitted(EventBus, "game_won")

func test_game_lost_signal():
	watch_signals(EventBus)
	EventBus.game_lost.emit()
	assert_signal_emitted(EventBus, "game_lost")

func test_player_died_signal():
	watch_signals(EventBus)
	EventBus.player_died.emit()
	assert_signal_emitted(EventBus, "player_died")

func test_player_damaged_signal():
	watch_signals(EventBus)
	EventBus.player_damaged.emit(10.0, 90.0)
	assert_signal_emitted(EventBus, "player_damaged")

func test_camera_shake_requested_signal():
	watch_signals(EventBus)
	EventBus.camera_shake_requested.emit(3.0, 0.1)
	assert_signal_emitted(EventBus, "camera_shake_requested")

func test_enemy_killed_signal():
	watch_signals(EventBus)
	EventBus.enemy_killed.emit("normal", Vector2(100, 200))
	assert_signal_emitted(EventBus, "enemy_killed")

func test_coins_changed_signal():
	watch_signals(EventBus)
	EventBus.coins_changed.emit(10, 50)
	assert_signal_emitted(EventBus, "coins_changed")

func test_coin_collected_signal():
	watch_signals(EventBus)
	EventBus.coin_collected.emit(5, Vector2(50, 75))
	assert_signal_emitted(EventBus, "coin_collected")

func test_tower_placed_signal():
	watch_signals(EventBus)
	EventBus.tower_placed.emit("shooter", Vector2(200, 300))
	assert_signal_emitted(EventBus, "tower_placed")

func test_tower_destroyed_signal():
	watch_signals(EventBus)
	EventBus.tower_destroyed.emit("wall", Vector2(150, 250))
	assert_signal_emitted(EventBus, "tower_destroyed")
