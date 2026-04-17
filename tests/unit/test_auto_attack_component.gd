extends GutTest

var _component: Node = null
var _host: Node2D = null
var _data: AutoAttackData = null

func before_each() -> void:
	_data = AutoAttackData.new()
	_data.attack_range = 200.0
	_data.cooldown = 0.5
	_data.damage = 10.0

	_host = Node2D.new()
	_host.add_to_group(Enums.Group.PLAYER)
	add_child_autofree(_host)

	var holder := Node.new()
	holder.name = "Abilities"
	_host.add_child(holder)
	_component = AutoAttackComponent.new()
	_component.data = _data
	holder.add_child(_component)

func test_no_target_no_spawn():
	var spawned := [0]
	_component.projectile_spawned.connect(func(_p): spawned[0] += 1)
	_component.tick(_data.cooldown + 0.01)
	assert_eq(spawned[0], 0, "无目标不 spawn")

func test_cooldown_gates_spawn():
	_component.set_debug_target(_host)
	var spawned := [0]
	_component.projectile_spawned.connect(func(_p): spawned[0] += 1)
	_component.tick(_data.cooldown + 0.01)
	assert_eq(spawned[0], 1, "cooldown 到期应 spawn 1 次")
	_component.tick(0.1)
	assert_eq(spawned[0], 1, "未到 cooldown 不 spawn")

func test_attack_speed_bonus_shortens_cooldown():
	PlayerState.player_stats[Enums.Stat.ATTACK_SPEED_BONUS_PERCENT] = 1.0
	_component.set_debug_target(_host)
	_component._recalculate_params()
	var spawned := [0]
	_component.projectile_spawned.connect(func(_p): spawned[0] += 1)
	_component.tick(_data.cooldown * 0.5 + 0.01)
	assert_eq(spawned[0], 1, "ATTACK_SPEED +100% 时 cooldown 减半应触发")
	PlayerState.player_stats[Enums.Stat.ATTACK_SPEED_BONUS_PERCENT] = 0.0
