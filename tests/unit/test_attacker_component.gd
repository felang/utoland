extends GutTest

var _attacker: AttackerComponent
var _proj_data: ProjectileData
var _fired_count: int = 0
var _last_target: Node2D = null
var _last_proj_data: ProjectileData = null

func before_each():
	_attacker = AttackerComponent.new()
	_proj_data = ProjectileData.new()
	_proj_data.speed = 300.0
	_fired_count = 0
	_last_target = null
	_last_proj_data = null
	add_child(_attacker)

func after_each():
	_attacker.queue_free()

func _on_attack_fired(target: Node2D, proj_data: ProjectileData) -> void:
	_fired_count += 1
	_last_target = target
	_last_proj_data = proj_data

func test_ranged_attack_fires_signal():
	var dummy_target := Node2D.new()
	add_child(dummy_target)
	_attacker.attack_fired.connect(_on_attack_fired)
	_attacker.init_attacker(10.0, 100.0, 0.5, AttackerComponent.AttackMode.RANGED, _proj_data, null)
	_attacker.target_finder = func(_range: float) -> Node2D: return dummy_target
	_attacker.tick(1.0)
	assert_eq(_fired_count, 1, "应发射一次攻击")
	assert_eq(_last_target, dummy_target)
	assert_eq(_last_proj_data, _proj_data)
	dummy_target.queue_free()

func test_cooldown_prevents_rapid_fire():
	var dummy_target := Node2D.new()
	add_child(dummy_target)
	_attacker.attack_fired.connect(_on_attack_fired)
	_attacker.init_attacker(10.0, 100.0, 1.0, AttackerComponent.AttackMode.RANGED, _proj_data, null)
	_attacker.target_finder = func(_range: float) -> Node2D: return dummy_target
	_attacker.tick(1.0)
	_attacker.tick(0.5)
	assert_eq(_fired_count, 1, "冷却中不应再次攻击")
	_attacker.tick(0.6)
	assert_eq(_fired_count, 2, "冷却结束应再次攻击")
	dummy_target.queue_free()

func test_no_target_no_fire():
	_attacker.attack_fired.connect(_on_attack_fired)
	_attacker.init_attacker(10.0, 100.0, 0.5, AttackerComponent.AttackMode.RANGED, _proj_data, null)
	_attacker.target_finder = func(_range: float) -> Node2D: return null
	_attacker.tick(1.0)
	assert_eq(_fired_count, 0, "无目标时不应攻击")

func test_get_final_damage_with_multiplier():
	_attacker.init_attacker(10.0, 100.0, 0.5, AttackerComponent.AttackMode.RANGED, _proj_data, null)
	assert_eq(_attacker.get_final_damage(), 10.0)
	_attacker.damage_multiplier = 1.5
	assert_almost_eq(_attacker.get_final_damage(), 15.0, 0.01)

func test_get_final_cooldown_with_speed_mult():
	_attacker.init_attacker(10.0, 100.0, 1.0, AttackerComponent.AttackMode.RANGED, _proj_data, null)
	assert_eq(_attacker.get_final_cooldown(), 1.0)
	_attacker.speed_multiplier = 2.0
	assert_almost_eq(_attacker.get_final_cooldown(), 0.5, 0.01)

func test_update_stats():
	_attacker.init_attacker(10.0, 100.0, 1.0, AttackerComponent.AttackMode.RANGED, _proj_data, null)
	_attacker.update_stats(20.0, 150.0, 0.5)
	assert_eq(_attacker.get_final_damage(), 20.0)
	assert_eq(_attacker.attack_range, 150.0)
	assert_eq(_attacker.get_final_cooldown(), 0.5)

func test_melee_mode_emits_melee_triggered():
	var dummy_target := Node2D.new()
	add_child(dummy_target)
	var melee_cfg := MeleeConfig.new()
	var _melee_fired := [false]
	_attacker.melee_triggered.connect(func(_t, _c): _melee_fired[0] = true)
	_attacker.init_attacker(10.0, 50.0, 0.5, AttackerComponent.AttackMode.MELEE, null, melee_cfg)
	_attacker.target_finder = func(_range: float) -> Node2D: return dummy_target
	_attacker.tick(1.0)
	assert_true(_melee_fired[0], "MELEE 模式应发射 melee_triggered 信号")
	dummy_target.queue_free()
