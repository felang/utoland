extends Tower
class_name TowerAoe

# 毒蘑菇 — 持续范围毒气伤害

var tick_damage: float = 5.0
var tick_interval: float = 0.5
var _tick_timer: float = 0.0

@onready var _spore_area: Area2D = $SporeArea

func _ready() -> void:
	tower_type = Enums.TowerId.MUSHROOM
	super._ready()

func _apply_level_stats() -> void:
	super._apply_level_stats()
	if not data:
		return
	var idx: int = current_level - 1
	tick_damage = data.damage_per_level[idx] * GameData.player_stats.get(Enums.Stat.TOWER_MULT, 1.0) * damage_mult
	if _spore_area and _spore_area.get_node_or_null("CollisionShape2D"):
		_spore_area.get_node("CollisionShape2D").shape.radius = data.attack_range_per_level[idx]

func _physics_process(delta: float) -> void:
	_tick_timer -= delta
	if _tick_timer <= 0:
		_tick_timer = tick_interval
		_deal_aoe_damage()

func _deal_aoe_damage() -> void:
	var bodies: Array = _spore_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group(Enums.Group.ENEMIES) and body.has_method("take_damage"):
			body.take_damage(tick_damage)
