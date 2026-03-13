extends Tower
class_name TowerBurst

# 玫瑰 — 3 连发攻击

enum BurstState { IDLE, BURST, COOLDOWN }

var attack_damage: float = 10.0
var attack_range: float = 200.0
var burst_count: int = 3
var burst_interval: float = 0.15
var cooldown_time: float = 3.0

var _state: int = BurstState.IDLE
var _burst_remaining: int = 0
var _burst_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _current_target: Node2D = null

@onready var _detect_area: Area2D = $DetectArea

func _ready() -> void:
	tower_type = Enums.TowerId.ROSE
	super._ready()
	# 信号连接已在 .tscn 中定义，无需在此重复连接

func _apply_level_stats() -> void:
	super._apply_level_stats()
	if not data:
		return
	var idx: int = get_current_level() - 1
	attack_damage = data.damage_per_level[idx] * GameData.player_stats.get(Enums.Stat.TOWER_MULT, 1.0) * damage_mult
	attack_range = data.attack_range_per_level[idx]
	burst_count = data.burst_count
	burst_interval = data.burst_interval
	if data.fire_rate_per_level.size() > idx:
		cooldown_time = data.fire_rate_per_level[idx] / maxf(speed_mult, 0.1)

func _physics_process(delta: float) -> void:
	match _state:
		BurstState.IDLE:
			pass
		BurstState.BURST:
			_burst_timer -= delta
			if _burst_timer <= 0:
				_fire_one()
		BurstState.COOLDOWN:
			_cooldown_timer -= delta
			if _cooldown_timer <= 0:
				_state = BurstState.IDLE
				_try_start_burst()

func _try_start_burst() -> void:
	if _state != BurstState.IDLE:
		return
	var targets: Array = _detect_area.get_overlapping_bodies()
	for body in targets:
		if body.is_in_group(Enums.Group.ENEMIES):
			_current_target = body
			_state = BurstState.BURST
			_burst_remaining = burst_count
			_burst_timer = 0.0
			return

func _fire_one() -> void:
	if not is_instance_valid(_current_target) or not _current_target.is_in_group(Enums.Group.ENEMIES):
		_state = BurstState.COOLDOWN
		_cooldown_timer = cooldown_time
		return
	var dir: Vector2 = global_position.direction_to(_current_target.global_position)
	var bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
	get_parent().add_child(bullet)
	bullet.setup(attack_damage, 20.0, global_position, dir)
	_burst_remaining -= 1
	if _burst_remaining <= 0:
		_state = BurstState.COOLDOWN
		_cooldown_timer = cooldown_time
	else:
		_burst_timer = burst_interval

func _on_body_entered(_body: Node2D) -> void:
	_try_start_burst()

func _on_body_exited(_body: Node2D) -> void:
	pass
