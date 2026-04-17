class_name ArrowRainSkillComponent
extends Node
## 箭雨技能组件 — CD 冷却后朝最近敌人位置召唤箭雨 AoE
##
## 挂载到游侠的 Abilities 节点下，自动寻找宿主（Player）。
## 冷却结束时若有敌人则立即 spawn ArrowRainEffect；
## 若无敌人则保持 ready 态（timer=0），下一帧有敌人时立刻触发。

signal rain_spawned(position: Vector2)

@export var data: ArrowRainData = null

var _host: Node2D = null
var _cooldown_timer: float = 0.0
var _current_cooldown: float = 10.0
var _current_radius: float = 96.0
var _has_knockback: bool = false
var _has_dot_field: bool = false

func _ready() -> void:
	_host = _resolve_host()
	if _host == null or data == null:
		push_error("ArrowRainSkillComponent: _host 或 data 缺失")
		set_physics_process(false)
		return
	_recalculate_params()
	_cooldown_timer = _current_cooldown
	EventBus.perk_applied.connect(_on_perk_applied)

func _resolve_host() -> Node2D:
	var p: Node = get_parent()
	while p:
		if p is Node2D and p.is_in_group(Enums.Group.PLAYER):
			return p
		p = p.get_parent()
	return null

func _physics_process(delta: float) -> void:
	_test_tick(delta)

## 对外暴露的 tick 方法（也供测试直接调用）
func _test_tick(delta: float) -> void:
	_cooldown_timer -= delta
	if _cooldown_timer > 0.0:
		return
	# CD 已到，寻找最近敌人
	var target: Node2D = _find_nearest_enemy()
	if target == null:
		# 无敌人：保持 ready 态（timer 钳位到 0）
		_cooldown_timer = 0.0
		return
	# 有敌人：spawn 并重置 CD
	_spawn_rain(target.global_position)
	_cooldown_timer = _current_cooldown

## 返回是否处于 ready 态（CD 已满）
func _test_is_ready() -> bool:
	return _cooldown_timer <= 0.0

## 公共 API：是否处于 ready 态（BattleHUD Task16 使用）
func is_ready() -> bool:
	return _cooldown_timer <= 0.0

## 公共 API：剩余冷却时间（BattleHUD Task16 使用）
func get_cooldown_remaining() -> float:
	return max(0.0, _cooldown_timer)

## 公共 API：完整冷却时间（BattleHUD Task16 使用）
func get_cooldown_total() -> float:
	return _current_cooldown

func _find_nearest_enemy() -> Node2D:
	if _host == null:
		return null
	var enemies: Array = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	var nearest: Node2D = null
	var min_dist_sq: float = INF
	for e in enemies:
		if not (e is Node2D) or not is_instance_valid(e):
			continue
		var d_sq: float = _host.global_position.distance_squared_to((e as Node2D).global_position)
		if d_sq < min_dist_sq:
			min_dist_sq = d_sq
			nearest = e
	return nearest

func _spawn_rain(pos: Vector2) -> void:
	if data == null or data.effect_scene == null:
		# 测试环境无场景，仅发射信号
		rain_spawned.emit(pos)
		return
	var effect: Node2D = data.effect_scene.instantiate()
	effect.global_position = pos
	if effect.has_method("setup"):
		effect.setup(data, _current_radius, _has_knockback, _has_dot_field)
	var container: Node = SceneFactory.get_entity_layer()
	if container == null:
		container = _host.get_parent() if _host else get_tree().current_scene
	container.add_child(effect)
	rain_spawned.emit(pos)

func _recalculate_params() -> void:
	if data == null:
		return
	_current_cooldown = data.cooldown
	_current_radius = data.radius

	# 读取 perk 等级调整参数
	var radius_lv: int = PerkManager.get_perk_level("rain_radius")
	var cooldown_lv: int = PerkManager.get_perk_level("rain_cooldown")
	_has_knockback = PerkManager.get_perk_level("rain_knockback") > 0
	_has_dot_field = PerkManager.get_perk_level("rain_dot_field") > 0

	# 每级半径 +20%
	_current_radius *= pow(1.2, radius_lv)
	# 每级 CD -15%
	_current_cooldown *= pow(0.85, cooldown_lv)

func _on_perk_applied(_perk_id: String) -> void:
	_recalculate_params()
