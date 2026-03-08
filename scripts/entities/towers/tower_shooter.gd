extends Tower

@export var attack_range: float = 300.0
@export var attack_damage: float = 10.0
@export var attack_rate: float = 1.0

@onready var detect_area: Area2D = $DetectArea
@onready var shoot_timer: Timer = $ShootTimer

func _ready() -> void:
	# 设置塔类型
	tower_type = Enums.TowerId.SHOOTER

	# 从注入的 Resource 初始化（HP 由 super._ready() 处理）
	attack_damage = data.damage * GameData.player_stats[Enums.Stat.TOWER_MULT]
	attack_rate = data.fire_rate
	attack_range = data.attack_range

	super._ready()
	shoot_timer.wait_time = attack_rate
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	shoot_timer.start()

func _on_shoot_timer_timeout() -> void:
	_shoot_nearest_enemy()

func _shoot_nearest_enemy() -> void:
	var enemies: Array[Node2D] = detect_area.get_overlapping_bodies()
	var closest: Node2D = null
	var min_dist: float = attack_range

	for enemy: Node2D in enemies:
		if enemy.is_in_group(Enums.Group.ENEMIES):
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy

	if closest:
		var bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
		var direction: Vector2 = global_position.direction_to(closest.global_position)
		get_parent().add_child(bullet)
		bullet.setup(attack_damage * _get_symbiosis_bonus(), 0.0, global_position, direction)

func _get_symbiosis_bonus() -> float:
	if GameData.symbiosis_hp_threshold <= 0.0:
		return 1.0
	var players: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.PLAYER)
	if players.is_empty():
		return 1.0
	var player: Node = players[0]
	if player.get("health") == null:
		return 1.0
	var hp_ratio: float = player.health.current_hp / player.health.max_hp
	if hp_ratio < GameData.symbiosis_hp_threshold:
		return 1.0 + GameData.symbiosis_tower_bonus
	return 1.0
