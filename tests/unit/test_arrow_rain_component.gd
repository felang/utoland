extends GutTest

var _c: ArrowRainSkillComponent = null
var _host: Node2D = null
var _data: ArrowRainData = null

func before_each() -> void:
	_data = ArrowRainData.new()
	_data.cooldown = 2.0
	_data.radius = 50.0
	_data.duration = 1.0
	_data.damage_per_tick = 5.0
	_data.tick_interval = 0.3

	_host = Node2D.new()
	_host.add_to_group(Enums.Group.PLAYER)
	add_child_autofree(_host)

	var holder := Node.new()
	holder.name = "Abilities"
	_host.add_child(holder)
	_c = ArrowRainSkillComponent.new()
	_c.data = _data
	holder.add_child(_c)

func test_cooldown_not_reached_no_spawn():
	var count := [0]
	_c.rain_spawned.connect(func(_pos): count[0] += 1)
	_c._test_tick(0.5)
	assert_eq(count[0], 0, "未到 cooldown 不 spawn")

func test_cooldown_without_enemies_holds_ready():
	_c._test_tick(_data.cooldown + 0.1)
	assert_true(_c._test_is_ready(), "无敌人时 CD 保持 ready 态")

func test_cooldown_with_enemies_spawns():
	var e := Node2D.new()
	e.add_to_group(Enums.Group.ENEMIES)
	add_child_autofree(e)
	e.global_position = Vector2(100, 0)
	var count := [0]
	_c.rain_spawned.connect(func(_pos): count[0] += 1)
	_c._test_tick(_data.cooldown + 0.1)
	assert_eq(count[0], 1, "CD 到 + 有敌人时 spawn 1 次")

func test_after_spawn_timer_resets():
	var e := Node2D.new()
	e.add_to_group(Enums.Group.ENEMIES)
	add_child_autofree(e)
	e.global_position = Vector2(100, 0)
	_c._test_tick(_data.cooldown + 0.1)
	# CD 应该重置，刚 spawn 后 ready 态应为 false
	assert_false(_c._test_is_ready(), "spawn 后 CD 重置，不应再处于 ready 态")

func test_spawns_signal_received_with_enemies():
	# 验证有敌人时信号被正确发射（headless 下 global_position 可能不反映 position 设置值，不验证坐标）
	var e := Node2D.new()
	e.add_to_group(Enums.Group.ENEMIES)
	add_child_autofree(e)
	var received := [false]
	_c.rain_spawned.connect(func(_pos: Vector2): received[0] = true)
	_c._test_tick(_data.cooldown + 0.1)
	assert_true(received[0], "有敌人时应收到 rain_spawned 信号")
