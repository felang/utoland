class_name TowerBuff
extends Tower

# 薄荷 — 范围内友方塔攻击/速度增益光环

var buff_damage_mult: float = 1.15
var buff_speed_mult: float = 1.1
var _buffed_towers: Array[Tower] = []

@onready var _buff_area: Area2D = $BuffArea

func _ready() -> void:
	tower_type = Enums.TowerId.MINT
	super._ready()
	# 增幅领域（Merlin）— boost 标签塔的效果范围 +40%
	if GameData.new_passive_id == "amplify_field" and data.tag == Enums.Tag.BOOST:
		var shape_node: CollisionShape2D = _buff_area.get_node_or_null("CollisionShape2D")
		if shape_node and shape_node.shape is CircleShape2D:
			shape_node.shape.radius *= (1.0 + GameData.new_passive_value)
	_buff_area.body_entered.connect(_on_tower_entered)
	_buff_area.body_exited.connect(_on_tower_exited)
	# Boost 3/5: 延迟一帧确保 SynergyEffectProcessor 已就绪
	call_deferred("_apply_self_boost")
	call_deferred("_apply_global_boost")
	# 魔力共鸣：buff 无距离限制，应用到所有塔
	if GameData.active_pair_synergies.has("magic_resonance"):
		call_deferred("_apply_global_resonance")

func _apply_level_stats() -> void:
	super._apply_level_stats()
	var idx: int = current_level - 1
	if data.buff_damage_mult_per_level.size() > idx:
		buff_damage_mult = data.buff_damage_mult_per_level[idx]
	if data.buff_speed_mult_per_level.size() > idx:
		buff_speed_mult = data.buff_speed_mult_per_level[idx]
	# Re-apply updated buffs to already-buffed towers
	for t in _buffed_towers:
		if is_instance_valid(t):
			t.apply_buff(buff_damage_mult, buff_speed_mult, str(get_instance_id()))

func _on_tower_entered(body: Node2D) -> void:
	if body is Tower and body != self:
		body.apply_buff(buff_damage_mult, buff_speed_mult, str(get_instance_id()))
		_buffed_towers.append(body)

func _on_tower_exited(body: Node2D) -> void:
	if body is Tower and body in _buffed_towers:
		if is_instance_valid(body):
			body.remove_buff(str(get_instance_id()))
		_buffed_towers.erase(body)

## Boost 3: 自增益 — 薄荷也给自己加 buff
func _apply_self_boost() -> void:
	var processor: SynergyEffectProcessor = _get_synergy_processor()
	if processor and processor.is_self_boost_active():
		apply_buff(buff_damage_mult, buff_speed_mult, "synergy_self_boost")
	else:
		remove_buff("synergy_self_boost")

## Boost 5: 全域共享 — buff 也应用到玩家角色
func _apply_global_boost() -> void:
	var processor: SynergyEffectProcessor = _get_synergy_processor()
	if not processor or not processor.is_global_boost_active():
		return
	if not is_inside_tree():
		return
	var player: Node2D = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	if player:
		# 将 buff 效果应用到 GameData 的攻速/伤害倍率
		GameData.player_stats[Enums.Stat.DAMAGE_MULT] = GameData.character_damage_mult * buff_damage_mult
		GameData.player_stats[Enums.Stat.ATTACK_SPEED_MULT] = GameData.character_attack_speed_mult * buff_speed_mult

## 魔力共鸣：buff 应用到场上所有塔（无距离限制）
func _apply_global_resonance() -> void:
	if not is_inside_tree():
		return
	for tower in get_tree().get_nodes_in_group(Enums.Group.TOWERS):
		if tower is Tower and tower != self and tower not in _buffed_towers:
			tower.apply_buff(buff_damage_mult, buff_speed_mult, str(get_instance_id()))
			_buffed_towers.append(tower)

func _get_synergy_processor() -> SynergyEffectProcessor:
	if not is_inside_tree():
		return null
	var processors: Array[Node] = get_tree().get_nodes_in_group("synergy_processor")
	if processors.size() > 0:
		return processors[0] as SynergyEffectProcessor
	return null

func _on_died() -> void:
	for t in _buffed_towers:
		if is_instance_valid(t):
			t.remove_buff(str(get_instance_id()))
	remove_buff("synergy_self_boost")
	super._on_died()
