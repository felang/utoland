extends StaticBody2D
class_name Tower

# 由 SceneFactory 注入的 Resource 数据
var data: TowerData = null
var tower_type: String = Enums.TowerId.STUMP
# 由 SceneFactory 在实例化后注入的等级
var current_level: int = 1

# Buff 系统
var damage_mult: float = 1.0
var speed_mult: float = 1.0
var _buff_sources: Dictionary = {}  # {source_id: {dmg: float, spd: float}}

@onready var health: HealthComponent = $HealthComponent

func _ready() -> void:
	_apply_level_stats()
	_apply_synergy_bonus()
	health.death_color = Color.GREEN
	health.died.connect(_on_died)
	add_to_group(Enums.Group.TOWERS)

func _apply_level_stats() -> void:
	var idx: int = current_level - 1
	health.initialize(data.hp_per_level[idx])

## 应用羁绊 2 档加成（assault/fortify/boost 回退的伤害/血量加成）
func _apply_synergy_bonus() -> void:
	if not GameData._synergy_manager:
		return
	var tag: String = GameData._synergy_manager.get_tag(tower_type)
	var tier: int = GameData.synergy_active_tiers.get(tag, 0)
	if tier < 2:
		return
	var synergy: SynergyData = GameConfig.synergies.get(tag)
	if not synergy:
		return
	# assault / boost 回退 → 伤害加成（通过 buff 系统）
	var dmg_bonus: float = GameData._synergy_manager.get_damage_mult_bonus(tower_type)
	if dmg_bonus > 0.0:
		apply_buff(1.0 + dmg_bonus, 1.0, "synergy_tier2")
	# fortify → 血量加成
	if synergy.tier2_stat == "max_hp":
		var bonus_hp: float = health.max_hp * synergy.tier2_value
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
	EventBus.tower_destroyed.emit(tower_type, global_position)
	queue_free()
