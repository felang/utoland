extends GutTest
## SynergyEffectProcessor 单元测试
## 覆盖：狂热、脆弱标记、殉爆参数、连锁控制查询、自增益/全域查询、溢杀

var processor: SynergyEffectProcessor
var _signal_tag: String = ""
var _signal_effect: String = ""


func _on_synergy_effect(tag: String, effect_id: String) -> void:
	_signal_tag = tag
	_signal_effect = effect_id


func before_each() -> void:
	_signal_tag = ""
	_signal_effect = ""
	GameData.current_character = Enums.Character.DORA
	GameData.reset()
	processor = SynergyEffectProcessor.new()
	processor.name = "SynergyEffectProcessor"
	add_child(processor)


func after_each() -> void:
	if is_instance_valid(processor):
		processor.queue_free()
	GameData.synergy_active_tiers = {}
	GameData.synergy_tag_counts = {}
	GameData.deployed_weapons = []
	GameData.deployed_towers = []


# ===== 初始状态 =====

func test_initial_frenzy_inactive() -> void:
	assert_false(processor.is_frenzy_active())


func test_initial_self_boost_inactive() -> void:
	# 无 boost 标签 → 自增益不激活
	assert_false(processor.is_self_boost_active())


func test_initial_global_boost_inactive() -> void:
	assert_false(processor.is_global_boost_active())


func test_initial_chain_freeze_inactive() -> void:
	assert_false(processor.should_chain_freeze())


# ===== Assault 3: 狂热 =====

func test_frenzy_activates_on_kill_with_assault_3() -> void:
	GameData.synergy_active_tiers = {Enums.Tag.ASSAULT: 3}
	EventBus.enemy_killed.emit("normal", Vector2.ZERO, false)
	assert_true(processor.is_frenzy_active())


func test_frenzy_inactive_without_assault_3() -> void:
	GameData.synergy_active_tiers = {Enums.Tag.ASSAULT: 2}
	EventBus.enemy_killed.emit("normal", Vector2.ZERO, false)
	assert_false(processor.is_frenzy_active())


func test_frenzy_deactivates_when_synergy_drops() -> void:
	GameData.synergy_active_tiers = {Enums.Tag.ASSAULT: 3}
	EventBus.enemy_killed.emit("normal", Vector2.ZERO, false)
	assert_true(processor.is_frenzy_active())
	# 羁绊降档
	EventBus.synergy_changed.emit(Enums.Tag.ASSAULT, 3, 2)
	assert_false(processor.is_frenzy_active())


# ===== Control 3: 脆弱标记 =====

func test_vulnerable_mult_inactive() -> void:
	# 无 control 3 → 倍率为 1.0
	GameData.synergy_active_tiers = {}
	# 用 null 测试安全性
	var mult: float = processor.get_vulnerable_mult(null)
	assert_almost_eq(mult, 1.0, 0.001)


func test_vulnerable_mult_active_no_cc() -> void:
	# control 3 激活但敌人未被控制 → 倍率 1.0
	GameData.synergy_active_tiers = {Enums.Tag.CONTROL: 3}
	# 创建模拟敌人节点
	var mock_enemy: Node2D = Node2D.new()
	add_child(mock_enemy)
	var mult: float = processor.get_vulnerable_mult(mock_enemy)
	assert_almost_eq(mult, 1.0, 0.001)
	mock_enemy.queue_free()


# ===== Blast 3: 殉爆参数 =====

func test_chain_blast_params_inactive() -> void:
	GameData.synergy_active_tiers = {}
	var params: Dictionary = processor.get_chain_blast_params()
	assert_true(params.is_empty())


func test_chain_blast_params_active() -> void:
	GameData.synergy_active_tiers = {Enums.Tag.BLAST: 3}
	var params: Dictionary = processor.get_chain_blast_params()
	assert_false(params.is_empty())
	assert_almost_eq(params.chance, 0.15, 0.001)
	assert_almost_eq(params.damage_mult, 0.5, 0.001)


# ===== Fortify 3: 应急护盾 =====

func test_emergency_shield_query_inactive() -> void:
	# 无 fortify 3 → 不检查护盾
	GameData.synergy_active_tiers = {}
	# 只验证不会崩溃
	processor._check_emergency_shields()
	assert_true(true)


# ===== Control 5: 连锁控制 =====

func test_chain_freeze_active_with_control_5() -> void:
	GameData.synergy_active_tiers = {Enums.Tag.CONTROL: 5}
	assert_true(processor.should_chain_freeze())


func test_chain_freeze_inactive_with_control_3() -> void:
	GameData.synergy_active_tiers = {Enums.Tag.CONTROL: 3}
	assert_false(processor.should_chain_freeze())


# ===== Boost 3: 自增益 =====

func test_self_boost_active_with_boost_3() -> void:
	GameData.synergy_active_tiers = {Enums.Tag.BOOST: 3}
	assert_true(processor.is_self_boost_active())


func test_self_boost_inactive_with_boost_2() -> void:
	GameData.synergy_active_tiers = {Enums.Tag.BOOST: 2}
	assert_false(processor.is_self_boost_active())


# ===== Boost 5: 全域共享 =====

func test_global_boost_active_with_boost_5() -> void:
	GameData.synergy_active_tiers = {Enums.Tag.BOOST: 5}
	assert_true(processor.is_global_boost_active())


func test_global_boost_inactive_with_boost_3() -> void:
	GameData.synergy_active_tiers = {Enums.Tag.BOOST: 3}
	assert_false(processor.is_global_boost_active())


# ===== Assault 5: 溢杀 =====

func test_overkill_no_effect_without_assault_5() -> void:
	GameData.synergy_active_tiers = {Enums.Tag.ASSAULT: 3}
	# 不崩溃即可
	processor.handle_overkill(50.0, Vector2(100, 100))
	assert_true(true)


func test_overkill_triggers_with_assault_5() -> void:
	GameData.synergy_active_tiers = {Enums.Tag.ASSAULT: 5}
	EventBus.synergy_effect_triggered.connect(_on_synergy_effect)
	processor.handle_overkill(50.0, Vector2(100, 100))
	assert_eq(_signal_tag, Enums.Tag.ASSAULT)
	assert_eq(_signal_effect, "overkill")
	EventBus.synergy_effect_triggered.disconnect(_on_synergy_effect)


func test_overkill_ignored_for_zero_damage() -> void:
	GameData.synergy_active_tiers = {Enums.Tag.ASSAULT: 5}
	EventBus.synergy_effect_triggered.connect(_on_synergy_effect)
	processor.handle_overkill(0.0, Vector2.ZERO)
	assert_eq(_signal_tag, "")
	EventBus.synergy_effect_triggered.disconnect(_on_synergy_effect)


# ===== Blast 5: 战术轰炸 =====

func test_tactical_bomb_timer_resets_on_synergy_change() -> void:
	# 验证 blast 5 激活时重置计时器
	processor._tactical_bomb_timer = 5.0
	EventBus.synergy_changed.emit(Enums.Tag.BLAST, 0, 5)
	assert_almost_eq(processor._tactical_bomb_timer, 15.0, 0.001)


# ===== Fortify 5: 不屈 =====

func test_undying_signal_emitted_on_tower_destroy() -> void:
	GameData.synergy_active_tiers = {Enums.Tag.FORTIFY: 5}
	# 需要单位有 fortify 标签
	GameData.deployed_towers = [{id = "stump", level = 1, grid_pos = Vector2i(1, 1)}]
	EventBus.synergy_effect_triggered.connect(_on_synergy_effect)
	EventBus.tower_destroyed.emit("stump", Vector2(16, 16))
	assert_eq(_signal_tag, Enums.Tag.FORTIFY)
	assert_eq(_signal_effect, "undying")
	assert_eq(processor._revive_queue.size(), 1)
	EventBus.synergy_effect_triggered.disconnect(_on_synergy_effect)


func test_undying_only_once_per_tower() -> void:
	GameData.synergy_active_tiers = {Enums.Tag.FORTIFY: 5}
	GameData.deployed_towers = [{id = "stump", level = 1, grid_pos = Vector2i(1, 1)}]
	EventBus.tower_destroyed.emit("stump", Vector2(16, 16))
	assert_eq(processor._revive_queue.size(), 1)
	# 同一位置再次摧毁不再触发
	EventBus.tower_destroyed.emit("stump", Vector2(16, 16))
	assert_eq(processor._revive_queue.size(), 1)


# ===== _is_tier_active 辅助 =====

func test_is_tier_active_exact() -> void:
	GameData.synergy_active_tiers = {Enums.Tag.ASSAULT: 3}
	assert_true(processor._is_tier_active(Enums.Tag.ASSAULT, 3))
	assert_true(processor._is_tier_active(Enums.Tag.ASSAULT, 2))
	assert_false(processor._is_tier_active(Enums.Tag.ASSAULT, 5))


func test_is_tier_active_missing_tag() -> void:
	GameData.synergy_active_tiers = {}
	assert_false(processor._is_tier_active(Enums.Tag.ASSAULT, 2))
