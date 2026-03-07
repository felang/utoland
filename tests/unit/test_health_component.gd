extends GutTest

# HealthComponent 单元测试

var _node: Node2D
var _health: HealthComponent

func before_each():
	_node = Node2D.new()
	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	_node.add_child(_health)
	add_child_autofree(_node)

func test_initialize_sets_hp():
	_health.initialize(50.0)
	assert_eq(_health.max_hp, 50.0, "max_hp 应设为初始化值")
	assert_eq(_health.current_hp, 50.0, "current_hp 应等于 max_hp")

func test_take_damage_reduces_hp():
	_health.initialize(100.0)
	_health.take_damage(30.0)
	assert_eq(_health.current_hp, 70.0, "受伤后 HP 应减少")

func test_take_damage_emits_damaged_signal():
	_health.initialize(100.0)
	watch_signals(_health)
	_health.take_damage(25.0)
	assert_signal_emitted(_health, "damaged", "受伤应触发 damaged 信号")

func test_take_damage_dies_at_zero():
	_health.initialize(50.0)
	watch_signals(_health)
	_health.take_damage(50.0)
	assert_signal_emitted(_health, "died", "HP 归零应触发 died 信号")

func test_take_damage_no_sparks():
	_health.initialize(100.0)
	watch_signals(_health)
	_health.take_damage_no_sparks(20.0)
	assert_eq(_health.current_hp, 80.0, "take_damage_no_sparks 应扣血")
	assert_signal_emitted(_health, "damaged", "应触发 damaged 信号")

func test_heal():
	_health.initialize(100.0)
	_health.current_hp = 50.0
	_health.heal(30.0)
	assert_eq(_health.current_hp, 80.0, "回血后 HP 应增加")

func test_heal_not_exceed_max():
	_health.initialize(100.0)
	_health.current_hp = 90.0
	_health.heal(50.0)
	assert_eq(_health.current_hp, 100.0, "回血不应超过最大值")

func test_is_dead():
	_health.initialize(50.0)
	assert_false(_health.is_dead(), "初始状态不应是死亡")
	_health.current_hp = 0.0
	assert_true(_health.is_dead(), "HP 为 0 应判定死亡")

func test_default_ready_initializes_hp():
	var node2 = Node2D.new()
	var health2 = HealthComponent.new()
	health2.name = "HealthComponent"
	health2.max_hp = 75.0
	node2.add_child(health2)
	add_child_autofree(node2)
	# _ready 会把 current_hp 设为 max_hp（如果 current_hp 为 0）
	assert_eq(health2.current_hp, 75.0, "_ready 应自动初始化 current_hp")
