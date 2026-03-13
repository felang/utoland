extends Tower
class_name TowerAura

# 橡树 — 超肉 + 范围内友方塔减伤光环

var aura_reduction: float = 0.15
var _buffed_towers: Array[Tower] = []

@onready var _aura_area: Area2D = $AuraArea

func _ready() -> void:
	tower_type = Enums.TowerId.OAK
	super._ready()
	_aura_area.body_entered.connect(_on_tower_entered)
	_aura_area.body_exited.connect(_on_tower_exited)

func _apply_level_stats() -> void:
	super._apply_level_stats()
	var idx: int = get_current_level() - 1
	if data.aura_reduction_per_level.size() > idx:
		var old_reduction: float = aura_reduction
		aura_reduction = data.aura_reduction_per_level[idx]
		_update_buffed_towers(old_reduction, aura_reduction)

func _on_tower_entered(body: Node2D) -> void:
	if body is Tower and body != self:
		body.health.damage_reduction = clampf(body.health.damage_reduction + aura_reduction, 0.0, 0.75)
		_buffed_towers.append(body)

func _on_tower_exited(body: Node2D) -> void:
	if body is Tower and body in _buffed_towers:
		body.health.damage_reduction = maxf(body.health.damage_reduction - aura_reduction, 0.0)
		_buffed_towers.erase(body)

func _update_buffed_towers(old_val: float, new_val: float) -> void:
	for t in _buffed_towers:
		if is_instance_valid(t):
			t.health.damage_reduction = clampf(t.health.damage_reduction - old_val + new_val, 0.0, 0.75)

func _on_died() -> void:
	for t in _buffed_towers:
		if is_instance_valid(t):
			t.health.damage_reduction = maxf(t.health.damage_reduction - aura_reduction, 0.0)
	super._on_died()
