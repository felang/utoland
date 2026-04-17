class_name HuntMarkSkillComponent
extends Node
## 猎杀标记技能组件 — 通过击杀积累充能，锁定最高 HP 敌人施加双倍伤害标记
##
## 挂载到游侠的 Abilities 节点下，自动寻找宿主（Player）。
## 状态机：IDLE（充能中） → MARKED（目标已锁定）
## 充能：监听 EventBus.enemy_killed；普通击杀 +charge_per_kill，精英 +charge_per_elite
## 激活：charge >= charge_required → 找最高 HP 敌人 → 锁定，设置 hunt_marked meta
## 持续：_mark_timer 倒计时，到期或目标消失/死亡 → 清除标记
## 击杀退款：标记目标死亡 → _charge = charge_required * kill_refund_ratio

@export var data: HuntMarkData = null

enum State { IDLE, MARKED }

var _host: Node2D = null
var _charge: float = 0.0
var _state: int = State.IDLE
var _marked_target: Node2D = null
var _mark_timer: float = 0.0
var _has_chain: bool = false
var _has_self_damage: bool = false

func _ready() -> void:
	_host = _resolve_host()
	if _host == null or data == null:
		push_warning("HuntMarkSkillComponent: _host 或 data 缺失，组件禁用")
		set_physics_process(false)
		return
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.perk_applied.connect(_on_perk_applied)
	_recalculate_params()

func _exit_tree() -> void:
	if EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)
	if EventBus.perk_applied.is_connected(_on_perk_applied):
		EventBus.perk_applied.disconnect(_on_perk_applied)

func _physics_process(delta: float) -> void:
	if _state != State.MARKED:
		return
	if not is_instance_valid(_marked_target):
		_on_marked_target_died()
		return
	_mark_timer -= delta
	if _mark_timer <= 0.0:
		_clear_mark()

func _resolve_host() -> Node2D:
	var p: Node = get_parent()
	while p:
		if p is Node2D and p.is_in_group(Enums.Group.PLAYER):
			return p
		p = p.get_parent()
	return null

# ===== EventBus 回调 =====

func _on_enemy_killed(enemy_type: String, _pos: Vector2, is_elite: bool) -> void:
	if _state == State.MARKED:
		# 标记期间不积累充能（检查目标是否已失效由 _physics_process 处理）
		return
	var gain: float = data.charge_per_elite if is_elite else data.charge_per_kill
	# 应用 perk 加速加成
	var lvl: int = PerkManager.get_perk_level("mark_charge_speed")
	gain *= (1.0 + 0.25 * lvl)
	_charge += gain
	if _charge >= data.charge_required:
		_activate_mark()

func _on_perk_applied(_perk_id: String) -> void:
	_recalculate_params()

# ===== 标记激活 / 清除 =====

func _activate_mark() -> void:
	_charge = data.charge_required  # 钳位到上限
	var tgt: Node2D = _find_highest_hp_enemy()
	if tgt == null:
		# 无敌人可标记，保持 IDLE（充能满状态等待）
		return
	_marked_target = tgt
	_state = State.MARKED
	_mark_timer = _current_duration()
	_marked_target.set_meta("hunt_marked", true)
	EventBus.hunt_mark_applied.emit(_marked_target)
	# 监听目标离树（tree_exiting 在节点仍有效时触发）
	if not _marked_target.tree_exiting.is_connected(_on_marked_target_tree_exiting):
		_marked_target.tree_exiting.connect(_on_marked_target_tree_exiting, CONNECT_ONE_SHOT)

func _on_marked_target_tree_exiting() -> void:
	_on_marked_target_died()

## 标记目标死亡处理（外部可直接调用，供测试辅助使用）
func _on_marked_target_died() -> void:
	if _state != State.MARKED:
		return
	var refund: float = data.charge_required * data.kill_refund_ratio
	_clear_mark_internals()
	_charge = refund
	if _has_chain:
		# 链式：立即尝试锁定下一个最高 HP 敌人
		_activate_mark()
	else:
		_state = State.IDLE

func _clear_mark() -> void:
	_clear_mark_internals()
	_charge = 0.0
	_state = State.IDLE

func _clear_mark_internals() -> void:
	if is_instance_valid(_marked_target):
		if _marked_target.has_meta("hunt_marked"):
			_marked_target.remove_meta("hunt_marked")
		if _marked_target.tree_exiting.is_connected(_on_marked_target_tree_exiting):
			_marked_target.tree_exiting.disconnect(_on_marked_target_tree_exiting)
		EventBus.hunt_mark_cleared.emit(_marked_target)
	_marked_target = null

# ===== 辅助查询 =====

func _find_highest_hp_enemy() -> Node2D:
	var enemies: Array = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	var best: Node2D = null
	var best_hp: float = -1.0
	for e in enemies:
		if not (e is Node2D) or not is_instance_valid(e):
			continue
		var hc: HealthComponent = e.get_node_or_null("HealthComponent")
		if hc == null:
			continue
		if hc.current_hp > best_hp:
			best_hp = hc.current_hp
			best = e
	return best

func _current_duration() -> float:
	var bonus: int = PerkManager.get_perk_level("mark_duration")
	return data.mark_duration + 2.0 * bonus

func _recalculate_params() -> void:
	_has_chain = PerkManager.get_perk_level("mark_chain") > 0
	_has_self_damage = PerkManager.get_perk_level("mark_self_damage") > 0

# ===== 公共 API（供 BattleHUD Task16 使用） =====

func get_charge() -> float:
	return _charge

func get_charge_required() -> float:
	return data.charge_required if data else 0.0

func get_marked_target() -> Node2D:
	return _marked_target

func get_mark_remaining() -> float:
	return _mark_timer

func has_self_damage_perk() -> bool:
	return _has_self_damage

# ===== 测试辅助方法 =====

## 推进标记计时器（模拟时间流逝），用于测试超时清除行为
func _test_advance_timer(amount: float) -> void:
	if _state != State.MARKED:
		return
	_mark_timer -= amount
	if _mark_timer <= 0.0:
		_clear_mark()
