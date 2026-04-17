extends GutTest

var spawner: EnemySpawner

func before_each() -> void:
	spawner = EnemySpawner.new()
	spawner.all_spawn_points = {
		"north": Vector2(0.0, -368.0),
		"south": Vector2(0.0, 368.0),
		"east": Vector2(608.0, 0.0),
		"west": Vector2(-608.0, 0.0),
	}
	add_child(spawner)

func after_each() -> void:
	spawner.queue_free()

func test_auto_directions_wave_1_to_5() -> void:
	spawner.update_active_directions(3, WaveData.new())
	assert_eq(spawner.active_directions.size(), 2, "wave 3 should activate 2 directions")

func test_auto_directions_wave_6_to_12() -> void:
	spawner.update_active_directions(8, WaveData.new())
	assert_eq(spawner.active_directions.size(), 3, "wave 8 should activate 3 directions")

func test_auto_directions_wave_13_plus() -> void:
	spawner.update_active_directions(15, WaveData.new())
	assert_eq(spawner.active_directions.size(), 4, "wave 15 should activate all 4")

func test_wave_data_overrides_auto() -> void:
	var wd := WaveData.new()
	wd.active_spawn_directions = ["north", "south"]
	spawner.update_active_directions(15, wd)
	assert_eq(spawner.active_directions.size(), 2, "override should use 2 directions")
	assert_has(spawner.active_directions, "north")
	assert_has(spawner.active_directions, "south")

func test_spawn_position_from_active_direction() -> void:
	spawner.active_directions = ["north"]
	var pos := spawner.get_random_spawn_position()
	assert_almost_eq(pos.x, 0.0, 20.0)
	assert_almost_eq(pos.y, -368.0, 20.0)

func test_spawn_position_fallback_when_no_points() -> void:
	spawner.all_spawn_points = {}
	spawner.active_directions = []
	var pos := spawner.get_random_spawn_position()
	assert_true(pos is Vector2)
