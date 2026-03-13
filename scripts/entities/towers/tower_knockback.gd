extends Tower
class_name TowerKnockback

# 蒲公英 — 周期性向外击退所有范围内敌人

var knockback_force: float = 100.0
var knockback_range: float = 200.0
var _interval_timer: float = 0.0
var _interval: float = 5.0

@onready var _push_area: Area2D = $PushArea

func _ready() -> void:
	tower_type = Enums.TowerId.DANDELION
	super._ready()

func _apply_level_stats() -> void:
	super._apply_level_stats()
	if not data:
		return
	var idx: int = get_current_level() - 1
	if data.knockback_force_per_level.size() > idx:
		knockback_force = data.knockback_force_per_level[idx] * damage_mult
	knockback_range = data.attack_range_per_level[idx]
	_interval = data.knockback_interval
	if _push_area and _push_area.get_node_or_null("CollisionShape2D"):
		_push_area.get_node("CollisionShape2D").shape.radius = knockback_range

func _physics_process(delta: float) -> void:
	_interval_timer -= delta
	if _interval_timer <= 0:
		_interval_timer = _interval
		_push_enemies()

func _push_enemies() -> void:
	var bodies: Array = _push_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group(Enums.Group.ENEMIES) and body.has_method("apply_knockback"):
			var dir: Vector2 = (body.global_position - global_position).normalized()
			body.apply_knockback(dir * knockback_force)
