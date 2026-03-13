extends Tower
class_name TowerTrap

# 藤蔓 — 触碰时定身敌人，有冷却

var trap_duration: float = 2.5
var trap_range: float = 120.0
var trap_cooldown: float = 8.0
var _cooldown_timer: float = 0.0
var _on_cooldown: bool = false

@onready var _trap_area: Area2D = $TrapArea

func _ready() -> void:
	tower_type = Enums.TowerId.VINE
	super._ready()
	_trap_area.body_entered.connect(_on_enemy_entered)

func _apply_level_stats() -> void:
	super._apply_level_stats()
	if not data:
		return
	var idx: int = get_current_level() - 1
	if data.trap_duration_per_level.size() > idx:
		trap_duration = data.trap_duration_per_level[idx]
	trap_range = data.attack_range_per_level[idx]
	trap_cooldown = data.trap_cooldown
	if _trap_area and _trap_area.get_node_or_null("CollisionShape2D"):
		_trap_area.get_node("CollisionShape2D").shape.radius = trap_range

func _physics_process(delta: float) -> void:
	if _on_cooldown:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0:
			_on_cooldown = false

func _on_enemy_entered(body: Node2D) -> void:
	if _on_cooldown:
		return
	if body.is_in_group(Enums.Group.ENEMIES) and body.has_method("apply_root"):
		body.apply_root(trap_duration)
		_on_cooldown = true
		_cooldown_timer = trap_cooldown
