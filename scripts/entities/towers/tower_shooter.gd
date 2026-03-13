extends Tower

@export var attack_range: float = 300.0
@export var attack_damage: float = 10.0
@export var attack_rate: float = 1.0

@onready var detect_area: Area2D = $DetectArea
@onready var shoot_timer: Timer = $ShootTimer

func _ready() -> void:
	# 设置塔类型
	tower_type = Enums.TowerId.SHOOTER

	super._ready()
	shoot_timer.wait_time = attack_rate
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	shoot_timer.start()

func _apply_level_stats() -> void:
	super._apply_level_stats()
	var idx: int = get_current_level() - 1
	attack_damage = data.damage_per_level[idx] * GameData.player_stats[Enums.Stat.TOWER_MULT]
	attack_rate = data.fire_rate_per_level[idx]
	attack_range = data.attack_range_per_level[idx]
	# 更新射击间隔
	if is_instance_valid(shoot_timer):
		shoot_timer.wait_time = attack_rate

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
		bullet.setup(attack_damage, 0.0, global_position, direction)
