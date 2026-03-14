class_name TowerBomb
extends Tower

# 爆竹竹 — 充能后自爆 AOE 伤害，然后消失

var explosion_damage: float = 150.0
var explosion_range: float = 250.0

@onready var _charge_timer: Timer = $ChargeTimer
@onready var _explosion_area: Area2D = $ExplosionArea

func _ready() -> void:
	tower_type = Enums.TowerId.BAMBOO
	super._ready()
	_charge_timer.timeout.connect(_on_charge_timer_timeout)

func _apply_level_stats() -> void:
	super._apply_level_stats()
	var idx: int = current_level - 1
	if data.explosion_damage_per_level.size() > idx:
		explosion_damage = data.explosion_damage_per_level[idx]
	if data.explosion_range_per_level.size() > idx:
		explosion_range = data.explosion_range_per_level[idx]
		var shape_node: CollisionShape2D = $ExplosionArea/CollisionShape2D
		if shape_node:
			shape_node.shape = shape_node.shape.duplicate()
			(shape_node.shape as CircleShape2D).radius = explosion_range
	if data.charge_time > 0.0:
		_charge_timer.wait_time = data.charge_time

func _on_charge_timer_timeout() -> void:
	_explode()

func _explode(is_chain: bool = false) -> void:
	var damage: float = explosion_damage
	# 连环引爆：爆炸伤害 +50%
	if GameData.active_pair_synergies.has("chain_detonation"):
		damage *= 1.5
	for body in _explosion_area.get_overlapping_bodies():
		if body.is_in_group(Enums.Group.ENEMIES):
			if body.has_node("HealthComponent"):
				body.health.take_damage(damage)
	# Blast 3: 殉爆 — 15% 概率二次爆炸（二次不再触发）
	if not is_chain:
		_try_chain_blast(damage)
	health.take_damage(health.max_hp)  # triggers _on_died() naturally


## Blast 3: 殉爆检查
func _try_chain_blast(base_damage: float) -> void:
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
		var chain_damage: float = base_damage * params.damage_mult
		for body in _explosion_area.get_overlapping_bodies():
			if body.is_in_group(Enums.Group.ENEMIES):
				if body.has_node("HealthComponent"):
					body.health.take_damage(chain_damage)
		EffectsManager.spawn_hit_sparks(global_position)
		EventBus.synergy_effect_triggered.emit(Enums.Tag.BLAST, "chain_blast")
