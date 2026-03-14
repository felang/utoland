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

func _deal_aoe_damage(is_chain: bool = false) -> void:
	var bodies: Array = _spore_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group(Enums.Group.ENEMIES) and body.has_method("take_damage"):
			body.take_damage(tick_damage)
	# Blast 3: 殉爆 — 15% 概率触发二次爆炸（二次爆炸不再触发）
	if not is_chain:
		_try_chain_blast()


## Blast 3: 殉爆检查
func _try_chain_blast() -> void:
	if not is_inside_tree():
		return
	var processors: Array[Node] = get_tree().get_nodes_in_group("synergy_processor")
	if processors.is_empty():
		return
	var processor: SynergyEffectProcessor = processors[0] as SynergyEffectProcessor
	if not processor:
		return
	var params: Dictionary = processor.get_chain_blast_params()
	if params.is_empty():
		return
	if randf() < params.chance:
		# 触发二次爆炸：50% 伤害
		var original_damage: float = tick_damage
		tick_damage *= params.damage_mult
		_deal_aoe_damage(true)
		tick_damage = original_damage
		EffectsManager.spawn_hit_sparks(global_position)
		EventBus.synergy_effect_triggered.emit(Enums.Tag.BLAST, "chain_blast")
