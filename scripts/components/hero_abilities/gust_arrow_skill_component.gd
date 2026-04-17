class_name GustArrowSkillComponent
extends Node
## 疾风箭技能组件 — 追踪累积移动距离，达到阈值时发射穿透箭
##
## 挂载到游侠的 Abilities 节点下，自动寻找宿主（Player）。
## 每帧累积移动距离，达到触发阈值时朝移动方向发射穿透箭。
## 静止时累积暂停（保留在阈值处），恢复移动立即触发。

signal gust_triggered(dir: Vector2, proj: Node2D)

const FAN_ANGLE_DEG: float = 15.0

@export var data: GustArrowData = null

var _host: Node2D = null
var _accum: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _current_trigger_distance: float = 160.0
var _current_damage: float = 25.0
var _current_pierce: int = 3
var _has_fanshot: bool = false
var _has_bounce: bool = false

# 测试辅助
var _test_mode: bool = false
var _test_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	_host = _resolve_host()
	if _host == null or data == null:
		push_error("GustArrowSkillComponent: _host 或 data 缺失")
		set_physics_process(false)
		return
	_last_pos = _host.global_position
	_recalculate_params()
	EventBus.perk_applied.connect(_on_perk_applied)

func _resolve_host() -> Node2D:
	var p: Node = get_parent()
	while p:
		if p is Node2D and p.is_in_group(Enums.Group.PLAYER):
			return p
		p = p.get_parent()
	return null

func _physics_process(_delta: float) -> void:
	if _test_mode:
		return
	if _host == null:
		return
	var current_pos: Vector2 = _host.global_position
	_accum += current_pos.distance_to(_last_pos)
	_last_pos = current_pos
	var vel: Vector2 = _get_current_velocity()
	_try_trigger(vel)

func _try_trigger(vel: Vector2) -> void:
	while _accum >= _current_trigger_distance:
		if vel == Vector2.ZERO:
			# 静止时保持在阈值，等待移动后立即触发
			_accum = _current_trigger_distance
			return
		_accum -= _current_trigger_distance
		var dir: Vector2 = vel.normalized()
		_spawn_arrow(dir)
		if _has_fanshot:
			_spawn_arrow(dir.rotated(deg_to_rad(FAN_ANGLE_DEG)))
			_spawn_arrow(dir.rotated(deg_to_rad(-FAN_ANGLE_DEG)))

func _spawn_arrow(dir: Vector2) -> void:
	if data == null or data.projectile_scene == null:
		# 测试环境无场景，发射空信号
		gust_triggered.emit(dir, null)
		return

	var proj: Node2D = data.projectile_scene.instantiate()
	proj.global_position = _host.global_position if _host else Vector2.ZERO

	# 设置穿透数
	var pierce: PierceComponent = proj.get_node_or_null("PierceComponent")
	if pierce:
		pierce.max_pierce_count = _current_pierce

	# 弹射 perk：动态添加 BounceOnHitComponent
	if _has_bounce and not proj.has_node("BounceOnHitComponent"):
		var bounce := BounceOnHitComponent.new()
		bounce.name = "BounceOnHitComponent"
		proj.add_child(bounce)

	if proj.has_method("setup"):
		proj.setup(null, _current_damage, _host, dir)

	var container: Node = SceneFactory.get_projectile_layer()
	if container == null:
		container = _host.get_parent() if _host else get_tree().current_scene
	container.add_child(proj)

	gust_triggered.emit(dir, proj)

func _recalculate_params() -> void:
	if data == null:
		return
	_current_damage = data.damage
	_current_pierce = data.pierce_count
	_current_trigger_distance = data.trigger_distance

	# 读取 perk 等级调整参数
	var interval_down_lv: int = PerkManager.get_perk_level("gust_interval_down")
	var pierce_plus_lv: int = PerkManager.get_perk_level("gust_pierce_plus")
	_has_fanshot = PerkManager.get_perk_level("gust_fanshot") > 0
	_has_bounce = PerkManager.get_perk_level("gust_bounce") > 0

	# 每级减少 10% 触发距离
	_current_trigger_distance *= pow(0.9, interval_down_lv)
	# 每级穿透 +1
	_current_pierce += pierce_plus_lv

func _get_current_velocity() -> Vector2:
	if _test_mode:
		return _test_velocity
	if _host and "velocity" in _host:
		return _host.velocity
	return Vector2.ZERO

func _on_perk_applied(_perk_id: String) -> void:
	_recalculate_params()

# ===== 测试辅助方法 =====

func _test_set_velocity(v: Vector2) -> void:
	_test_mode = true
	_test_velocity = v

func _test_accumulate_distance(d: float) -> void:
	_accum += d

func _test_tick() -> void:
	_try_trigger(_get_current_velocity())

func set_fanshot_for_test(on: bool) -> void:
	_has_fanshot = on
