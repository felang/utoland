extends StaticBody2D
class_name Tower

# 由 SceneFactory 注入的 Resource 数据
var data: TowerData = null
var tower_type: String = Enums.TowerId.STUMP

# Buff 系统
var damage_mult: float = 1.0
var speed_mult: float = 1.0
var _buff_sources: Dictionary = {}  # {source_id: {dmg: float, spd: float}}

@onready var health: HealthComponent = $HealthComponent

func _ready() -> void:
	_apply_level_stats()
	_apply_character_passive()
	health.death_color = Color.GREEN
	health.died.connect(_on_died)
	add_to_group(Enums.Group.TOWERS)
	EventBus.tower_upgraded.connect(_on_tower_upgraded)

func get_current_level() -> int:
	return GameData.owned_towers.get(data.id, 1)

func _apply_level_stats() -> void:
	var level: int = get_current_level()
	var idx: int = level - 1
	health.initialize(data.hp_per_level[idx])

func _on_tower_upgraded(upgraded_type: String) -> void:
	if upgraded_type == data.id:
		_apply_level_stats()

func _apply_character_passive() -> void:
	var passive: String = GameData.character_passive_type
	var value: float = GameData.character_passive_value
	if passive == Enums.PassiveType.TOWER_ATTACK_SPEED_BONUS:
		apply_buff(1.0, 1.0 + value, "character_passive")
	elif passive == Enums.PassiveType.TOWER_HP_BONUS:
		var bonus_hp: float = health.max_hp * value
		health.max_hp += bonus_hp
		health.current_hp += bonus_hp

func take_damage(amount: float, attacker: Node2D = null) -> void:
	health.take_damage(amount, attacker)

func apply_buff(dmg_mult: float, spd_mult: float, source_id: String) -> void:
	_buff_sources[source_id] = {"dmg": dmg_mult, "spd": spd_mult}
	_recalc_buffs()

func remove_buff(source_id: String) -> void:
	_buff_sources.erase(source_id)
	_recalc_buffs()

func _recalc_buffs() -> void:
	damage_mult = 1.0
	speed_mult = 1.0
	for data_entry in _buff_sources.values():
		damage_mult *= data_entry["dmg"]
		speed_mult *= data_entry["spd"]

func _on_died() -> void:
	EventBus.tower_upgraded.disconnect(_on_tower_upgraded)
	queue_free()
