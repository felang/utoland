extends Tower
class_name TowerThorn

# 荆棘 — 敌人攻击自身时反弹伤害

var reflect_ratio: float = 0.25

func _ready() -> void:
	tower_type = Enums.TowerId.THORN
	super._ready()
	health.damaged.connect(_on_damaged)

func _apply_level_stats() -> void:
	super._apply_level_stats()
	var idx: int = get_current_level() - 1
	if data.reflect_ratio_per_level.size() > idx:
		reflect_ratio = data.reflect_ratio_per_level[idx]

func _on_damaged(amount: float, _current_hp: float, attacker: Node2D) -> void:
	if attacker and is_instance_valid(attacker) and attacker.has_node("HealthComponent"):
		var reflect_damage: float = amount * reflect_ratio
		attacker.health.take_damage(reflect_damage)
