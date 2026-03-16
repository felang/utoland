# TowerShooter — 射手塔（组合 AttackerComponent）
extends Tower

var attacker: AttackerComponent = null

@onready var detect_area: Area2D = $DetectArea

func _ready() -> void:
	super._ready()
	attacker = AttackerComponent.new()
	add_child(attacker)
	attacker.attack_fired.connect(_on_attack_fired)
	attacker.target_finder = _find_nearest_enemy
	_apply_attacker_stats()

func _process(delta: float) -> void:
	attacker.tick(delta)

func _apply_level_stats() -> void:
	super._apply_level_stats()
	if attacker:
		_apply_attacker_stats()

func _apply_attacker_stats() -> void:
	var idx: int = current_level - 1
	var damage: float = data.damage_per_level[idx] * GameData.player_stats.get(Enums.Stat.TOWER_MULT, 1.0)
	var cooldown: float = data.fire_rate_per_level[idx]
	var attack_range: float = data.attack_range_per_level[idx]
	attacker.update_stats(damage, attack_range, cooldown)
	attacker.attack_mode = AttackerComponent.AttackMode.RANGED
	# per_level slow 覆写
	if data.projectile_data and data.slow_ratio_per_level.size() > 0:
		var proj_data: ProjectileData = data.projectile_data.duplicate()
		proj_data.slow_ratio = data.slow_ratio_per_level[idx]
		proj_data.slow_duration = data.slow_duration_per_level[idx]
		attacker.projectile_data = proj_data
	else:
		attacker.projectile_data = data.projectile_data
	# 更新 DetectArea 范围
	var detect_shape: CollisionShape2D = detect_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if detect_shape and detect_shape.shape is CircleShape2D:
		(detect_shape.shape as CircleShape2D).radius = attack_range

func apply_buff(dmg_mult: float, spd_mult: float, source_id: String) -> void:
	super.apply_buff(dmg_mult, spd_mult, source_id)
	if attacker:
		attacker.damage_multiplier = damage_mult
		attacker.speed_multiplier = speed_mult

func remove_buff(source_id: String) -> void:
	super.remove_buff(source_id)
	if attacker:
		attacker.damage_multiplier = damage_mult
		attacker.speed_multiplier = speed_mult

func _on_attack_fired(_target: Node2D, proj_data: ProjectileData) -> void:
	if not proj_data:
		return
	var direction: Vector2 = global_position.direction_to(_target.global_position)
	var proj: ProjectileBase = SceneFactory.create_projectile(
		proj_data, attacker.get_final_damage(), global_position, direction
	)
	get_parent().add_child(proj)
	play_attack_animation()

func _find_nearest_enemy(range_limit: float) -> Node2D:
	var enemies: Array[Node2D] = detect_area.get_overlapping_bodies()
	var closest: Node2D = null
	var min_dist: float = range_limit
	for enemy: Node2D in enemies:
		if enemy.is_in_group(Enums.Group.ENEMIES):
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy
	return closest
