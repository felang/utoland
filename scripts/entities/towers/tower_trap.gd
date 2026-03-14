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
	# 信号连接已在 .tscn 中定义，无需在此重复连接

func _apply_level_stats() -> void:
	super._apply_level_stats()
	if not data:
		return
	var idx: int = current_level - 1
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
		body.apply_root(trap_duration, "vine")
		_on_cooldown = true
		_cooldown_timer = trap_cooldown
		# 极寒囚笼：藤蔓定身结束后，若敌人被冰冻枪减速则追加 2 秒冰冻定身
		if GameData.active_pair_synergies.has("frozen_cage"):
			_schedule_frozen_cage(body, trap_duration)

## 极寒囚笼：定身到期后检查是否被冰冻枪减速，追加 2 秒冰冻
func _schedule_frozen_cage(enemy: Node2D, delay: float) -> void:
	if not is_inside_tree():
		return
	var timer: SceneTreeTimer = get_tree().create_timer(delay)
	timer.timeout.connect(_apply_frozen_cage.bind(enemy))

func _apply_frozen_cage(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	if not enemy.has_node("SlowHandler"):
		return
	var sh: SlowHandler = enemy.get_node("SlowHandler") as SlowHandler
	if sh and not sh._active_slows.is_empty():
		# 敌人有减速效果生效中，施加 2 秒冰冻定身
		enemy.apply_root(2.0, "frozen_cage")
