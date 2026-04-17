extends GutTest

var _c: GustArrowSkillComponent = null
var _host: Node2D = null
var _data: GustArrowData = null

func before_each() -> void:
	_data = GustArrowData.new()
	_data.trigger_distance = 100.0
	_data.damage = 20.0
	_data.pierce_count = 2

	_host = Node2D.new()
	_host.add_to_group(Enums.Group.PLAYER)
	add_child_autofree(_host)

	var holder := Node.new()
	holder.name = "Abilities"
	_host.add_child(holder)
	_c = GustArrowSkillComponent.new()
	_c.data = _data
	holder.add_child(_c)

func test_static_no_trigger():
	var count := [0]
	_c.gust_triggered.connect(func(_d, _p): count[0] += 1)
	_c._test_set_velocity(Vector2.ZERO)
	_c._test_accumulate_distance(_data.trigger_distance + 10.0)
	_c._test_tick()
	assert_eq(count[0], 0, "静止时不触发")

func test_moving_triggers_after_distance():
	var count := [0]
	_c.gust_triggered.connect(func(_d, _p): count[0] += 1)
	_c._test_set_velocity(Vector2(100, 0))
	_c._test_accumulate_distance(_data.trigger_distance + 10.0)
	_c._test_tick()
	assert_eq(count[0], 1, "移动 + 累积距离达阈值应触发")

func test_overflow_preserved():
	var count := [0]
	_c.gust_triggered.connect(func(_d, _p): count[0] += 1)
	_c._test_set_velocity(Vector2(100, 0))
	_c._test_accumulate_distance(_data.trigger_distance * 2 + 10.0)
	_c._test_tick()
	assert_eq(count[0], 2, "双倍距离触发 2 次")

func test_fanshot_spawns_three():
	_c._test_set_velocity(Vector2(100, 0))
	_c.set_fanshot_for_test(true)
	var count := [0]
	_c.gust_triggered.connect(func(_d, _p): count[0] += 1)
	_c._test_accumulate_distance(_data.trigger_distance + 1.0)
	_c._test_tick()
	assert_eq(count[0], 3, "扇形开启后每次触发应发 3 发")
