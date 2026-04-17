extends GutTest
## HuntMarkSkillComponent 单元测试
##
## 覆盖：充能积累、精英加速、标记最高 HP 敌人、超时清除、击杀退款、链式标记

var _c: HuntMarkSkillComponent = null
var _host: Node2D = null
var _data: HuntMarkData = null

func before_each() -> void:
	_data = HuntMarkData.new()
	_data.charge_per_kill = 1.0
	_data.charge_per_elite = 5.0
	_data.charge_required = 5.0
	_data.mark_duration = 10.0
	_data.damage_multiplier = 2.0
	_data.kill_refund_ratio = 0.5

	_host = Node2D.new()
	_host.add_to_group(Enums.Group.PLAYER)
	add_child_autofree(_host)

	var holder := Node.new()
	holder.name = "Abilities"
	_host.add_child(holder)
	_c = HuntMarkSkillComponent.new()
	_c.data = _data
	holder.add_child(_c)


func test_charge_per_normal_kill() -> void:
	_c._on_enemy_killed("normal", Vector2.ZERO, false)
	assert_almost_eq(_c.get_charge(), 1.0, 0.01)


func test_elite_multiplier() -> void:
	_c._on_enemy_killed("normal", Vector2.ZERO, true)
	assert_almost_eq(_c.get_charge(), 5.0, 0.01)


func test_full_charge_picks_highest_hp_enemy() -> void:
	var e1: Node2D = _make_enemy(50.0, Vector2(50, 0))
	var e2: Node2D = _make_enemy(200.0, Vector2(150, 0))
	for i in range(5):
		_c._on_enemy_killed("normal", Vector2.ZERO, false)
	assert_eq(_c.get_marked_target(), e2, "应锁定最高 HP 敌人")


func test_mark_timeout_clears() -> void:
	_make_enemy(100.0, Vector2(100, 0))
	for i in range(5):
		_c._on_enemy_killed("normal", Vector2.ZERO, false)
	assert_not_null(_c.get_marked_target())
	# 模拟超时
	_c._test_advance_timer(_data.mark_duration + 0.1)
	assert_null(_c.get_marked_target())


func test_kill_refunds_charge() -> void:
	var e: Node2D = _make_enemy(100.0, Vector2(100, 0))
	for i in range(5):
		_c._on_enemy_killed("normal", Vector2.ZERO, false)
	assert_not_null(_c.get_marked_target())
	# 模拟标记目标死亡
	_c._on_marked_target_died()
	assert_almost_eq(_c.get_charge(), 2.5, 0.01)  # 5.0 * 0.5
	assert_null(_c.get_marked_target())


func test_charge_caps_at_charge_required() -> void:
	# 超出 charge_required 时 charge 被钳位到 charge_required
	_make_enemy(50.0, Vector2(100, 0))
	for i in range(10):
		_c._on_enemy_killed("normal", Vector2.ZERO, false)
	# 激活后 charge = charge_required (钳位)，或保持 MARKED 状态
	assert_true(_c.get_charge() <= _data.charge_required, "激活后 charge 不应超过 charge_required")


func test_public_api_get_charge_required() -> void:
	assert_almost_eq(_c.get_charge_required(), 5.0, 0.01)


func test_public_api_get_mark_remaining() -> void:
	_make_enemy(100.0, Vector2(100, 0))
	for i in range(5):
		_c._on_enemy_killed("normal", Vector2.ZERO, false)
	assert_almost_eq(_c.get_mark_remaining(), 10.0, 0.1, "标记剩余时间应为 mark_duration")


func test_has_self_damage_perk_default_false() -> void:
	assert_false(_c.has_self_damage_perk())


func test_no_mark_without_enemies() -> void:
	# 无敌人时触发充能不应产生标记
	for i in range(5):
		_c._on_enemy_killed("normal", Vector2.ZERO, false)
	assert_null(_c.get_marked_target(), "无敌人时不应产生标记")


func test_charge_does_not_accumulate_while_marked() -> void:
	_make_enemy(100.0, Vector2(100, 0))
	for i in range(5):
		_c._on_enemy_killed("normal", Vector2.ZERO, false)
	var charge_after_mark: float = _c.get_charge()
	# 标记期间继续触发 enemy_killed 不应改变 charge
	_c._on_enemy_killed("normal", Vector2.ZERO, false)
	assert_almost_eq(_c.get_charge(), charge_after_mark, 0.01, "标记期间 charge 不应变化")


# ===== 辅助方法 =====

func _make_enemy(hp: float, pos: Vector2) -> Node2D:
	var e := Node2D.new()
	e.add_to_group(Enums.Group.ENEMIES)
	e.global_position = pos
	var hc := HealthComponent.new()
	hc.name = "HealthComponent"
	e.add_child(hc)
	add_child_autofree(e)
	hc.initialize(hp)
	return e
