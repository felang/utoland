extends Tower
class_name TowerGrab

# 猪笼草 — 抓取非Boss敌人进行消化伤害

enum GrabState { IDLE, GRABBING, DIGESTING }

var grab_dps: float = 8.0
var digest_duration: float = 3.0
var grab_range: float = 100.0

var _state: int = GrabState.IDLE
var _grabbed_enemy: Node2D = null
var _digest_timer: float = 0.0
var _dps_tick: float = 0.0

@onready var _grab_area: Area2D = $GrabArea

func _ready() -> void:
	tower_type = Enums.TowerId.PITCHER
	super._ready()
	_grab_area.body_entered.connect(_on_enemy_entered)

func _apply_level_stats() -> void:
	super._apply_level_stats()
	if not data:
		return
	var idx: int = get_current_level() - 1
	if data.grab_dps_per_level.size() > idx:
		grab_dps = data.grab_dps_per_level[idx] * GameData.player_stats.get(Enums.Stat.TOWER_MULT, 1.0) * damage_mult
	if data.digest_duration_per_level.size() > idx:
		digest_duration = data.digest_duration_per_level[idx]
	grab_range = data.attack_range_per_level[idx]
	if _grab_area and _grab_area.get_node_or_null("CollisionShape2D"):
		_grab_area.get_node("CollisionShape2D").shape.radius = grab_range

func _physics_process(delta: float) -> void:
	if _state == GrabState.DIGESTING:
		_dps_tick -= delta
		if _dps_tick <= 0:
			_dps_tick = 0.1
			if is_instance_valid(_grabbed_enemy):
				_grabbed_enemy.take_damage(grab_dps * 0.1)
				_grabbed_enemy.velocity = Vector2.ZERO
				_grabbed_enemy.global_position = global_position
		_digest_timer -= delta
		if _digest_timer <= 0:
			_release_enemy()

func _on_enemy_entered(body: Node2D) -> void:
	if _state != GrabState.IDLE:
		return
	if not body.is_in_group(Enums.Group.ENEMIES):
		return
	# Boss 免疫
	if body.has_node("HealthComponent") and body.get("data") != null:
		if body.data.is_boss:
			return
	_grabbed_enemy = body
	_state = GrabState.DIGESTING
	_digest_timer = digest_duration
	_dps_tick = 0.0

func _release_enemy() -> void:
	_state = GrabState.IDLE
	_grabbed_enemy = null
