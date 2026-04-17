class_name AutoAttackComponent
extends Node

signal projectile_spawned(proj: Node2D)

@export var data: AutoAttackData = null

var _host: Node2D = null
var _target_finder: TargetFinderComponent = null
var _cooldown_timer: float = 0.0
var _current_damage: float = 0.0
var _current_cooldown: float = 0.5
var _current_range: float = 240.0
var _debug_target: Node2D = null

func _ready() -> void:
	_host = _resolve_host()
	if _host == null or data == null:
		push_error("AutoAttackComponent: _host 或 data 缺失")
		set_physics_process(false)
		return
	_setup_target_finder()
	_recalculate_params()
	EventBus.perk_applied.connect(_on_perk_applied)

func _resolve_host() -> Node2D:
	var p: Node = get_parent()
	while p:
		if p is Node2D and p.is_in_group(Enums.Group.PLAYER):
			return p
		p = p.get_parent()
	return null

func _setup_target_finder() -> void:
	_target_finder = TargetFinderComponent.new()
	_target_finder.name = "_AutoAttackFinder"
	_target_finder.detect_range = _current_range
	add_child(_target_finder)

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	_cooldown_timer -= delta
	if _cooldown_timer > 0.0:
		return
	var tgt: Node2D = _get_target()
	if tgt == null:
		return
	_spawn_projectile(tgt)
	_cooldown_timer = _current_cooldown

func _get_target() -> Node2D:
	if _debug_target and is_instance_valid(_debug_target):
		return _debug_target
	if _target_finder:
		return _target_finder.get_target()
	return null

func set_debug_target(t: Node2D) -> void:
	_debug_target = t

func _spawn_projectile(target: Node2D) -> void:
	if data.projectile_scene == null:
		projectile_spawned.emit(null)
		return
	var proj: Node2D = data.projectile_scene.instantiate()
	proj.global_position = _host.global_position
	var dir: Vector2 = (target.global_position - _host.global_position).normalized()
	if proj.has_method("setup"):
		proj.setup(null, _current_damage, _host, dir)
	var container: Node = SceneFactory.get_projectile_layer()
	if container == null:
		container = _host.get_parent()
	container.add_child(proj)
	projectile_spawned.emit(proj)

func _recalculate_params() -> void:
	if data == null:
		return
	var dmg_bonus: float = PlayerState.player_stats.get(Enums.Stat.DAMAGE_BONUS_PERCENT, 0.0)
	var spd_bonus: float = PlayerState.player_stats.get(Enums.Stat.ATTACK_SPEED_BONUS_PERCENT, 0.0)
	_current_damage = data.damage * (1.0 + dmg_bonus)
	_current_cooldown = data.cooldown / maxf(1.0 + spd_bonus, 0.01)
	_current_range = data.attack_range
	if _target_finder:
		_target_finder.set_range(_current_range)

func _on_perk_applied(_perk_id: String) -> void:
	_recalculate_params()
