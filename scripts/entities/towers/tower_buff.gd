extends Tower
class_name TowerBuff

# 薄荷 — 范围内友方塔攻击/速度增益光环

var buff_damage_mult: float = 1.15
var buff_speed_mult: float = 1.1
var _buffed_towers: Array[Tower] = []

@onready var _buff_area: Area2D = $BuffArea

func _ready() -> void:
	tower_type = Enums.TowerId.MINT
	super._ready()
	_buff_area.body_entered.connect(_on_tower_entered)
	_buff_area.body_exited.connect(_on_tower_exited)

func _apply_level_stats() -> void:
	super._apply_level_stats()
	var idx: int = get_current_level() - 1
	if data.buff_damage_mult_per_level.size() > idx:
		buff_damage_mult = data.buff_damage_mult_per_level[idx]
	if data.buff_speed_mult_per_level.size() > idx:
		buff_speed_mult = data.buff_speed_mult_per_level[idx]

func _on_tower_entered(body: Node2D) -> void:
	if body is Tower and body != self:
		body.apply_buff(buff_damage_mult, buff_speed_mult, str(get_instance_id()))
		_buffed_towers.append(body)

func _on_tower_exited(body: Node2D) -> void:
	if body is Tower and body in _buffed_towers:
		body.remove_buff(str(get_instance_id()))
		_buffed_towers.erase(body)

func _on_died() -> void:
	for t in _buffed_towers:
		if is_instance_valid(t):
			t.remove_buff(str(get_instance_id()))
	super._on_died()
