extends Tower
class_name TowerBomb

# 爆竹竹 — 充能后自爆 AOE 伤害，然后消失

enum BombState { CHARGING, EXPLODING }

var explosion_damage: float = 150.0
var explosion_range: float = 250.0
var _state: BombState = BombState.CHARGING

@onready var _charge_timer: Timer = $ChargeTimer
@onready var _explosion_area: Area2D = $ExplosionArea

func _ready() -> void:
	tower_type = Enums.TowerId.BAMBOO
	super._ready()
	_charge_timer.timeout.connect(_on_charge_timer_timeout)

func _apply_level_stats() -> void:
	super._apply_level_stats()
	var idx: int = get_current_level() - 1
	if data.explosion_damage_per_level.size() > idx:
		explosion_damage = data.explosion_damage_per_level[idx]
	if data.explosion_range_per_level.size() > idx:
		explosion_range = data.explosion_range_per_level[idx]
		var shape_node: CollisionShape2D = $ExplosionArea/CollisionShape2D
		if shape_node and shape_node.shape is CircleShape2D:
			(shape_node.shape as CircleShape2D).radius = explosion_range
	if data.charge_time > 0.0:
		_charge_timer.wait_time = data.charge_time

func _on_charge_timer_timeout() -> void:
	_state = BombState.EXPLODING
	_explode()

func _explode() -> void:
	for body in _explosion_area.get_overlapping_bodies():
		if body.is_in_group(Enums.Group.ENEMIES):
			if body.has_node("HealthComponent"):
				body.health.take_damage(explosion_damage)
	queue_free()
