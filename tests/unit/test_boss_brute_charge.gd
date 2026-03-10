extends GutTest

## Boss 蛮兽冲锋行为测试

var boss: CharacterBody2D

func before_each():
	var fake_player := CharacterBody2D.new()
	fake_player.add_to_group(Enums.Group.PLAYER)
	fake_player.global_position = Vector2(300, 0)
	add_child(fake_player)
	boss = SceneFactory.create_enemy("boss_brute")
	add_child(boss)
	boss.global_position = Vector2(0, 0)
	# 明确设置 player 引用，避免 queue_free 延迟导致引用到旧节点
	boss.player = fake_player

func after_each():
	for child in get_children():
		child.queue_free()

func test_boss_starts_in_chase():
	assert_eq(boss._charge_state, boss.ChargeState.CHASE, "Boss 初始应为追击状态")

func test_windup_starts_after_cooldown():
	boss._charge_timer = 0.0
	boss._process_chase(0.1)
	assert_eq(boss._charge_state, boss.ChargeState.WINDUP, "冷却结束后应进入预备状态")

func test_windup_changes_modulate():
	boss._start_windup()
	assert_ne(boss.modulate, Color.WHITE, "预备阶段应改变颜色")

func test_charge_increases_damage():
	var normal_damage: float = boss._hitbox.damage
	boss._start_charge()
	assert_gt(boss._hitbox.damage, normal_damage, "冲锋时伤害应增加")

func test_stun_restores_damage():
	boss._start_charge()
	boss._start_stun()
	assert_eq(boss._hitbox.damage, boss._original_damage, "眩晕后伤害应恢复")

func test_stun_ends_returns_to_chase():
	boss._start_stun()
	boss._process_stunned(1.0)
	assert_eq(boss._charge_state, boss.ChargeState.CHASE, "眩晕结束后应回到追击")
	assert_eq(boss.modulate, Color.WHITE, "恢复后颜色应回到白色")

func test_no_charge_when_too_close():
	boss.player.global_position = Vector2(10, 0)
	boss._charge_timer = 0.0
	boss._process_chase(0.1)
	assert_eq(boss._charge_state, boss.ChargeState.CHASE, "距离太近不应触发冲锋")

func test_full_charge_cycle():
	boss._charge_timer = 0.0
	boss._process_chase(0.1)
	assert_eq(boss._charge_state, boss.ChargeState.WINDUP)
	boss._process_windup(1.0)
	assert_eq(boss._charge_state, boss.ChargeState.CHARGING)
	boss._process_charging(1.0)
	assert_eq(boss._charge_state, boss.ChargeState.STUNNED)
	boss._process_stunned(1.0)
	assert_eq(boss._charge_state, boss.ChargeState.CHASE)
