extends Tower

@export var attack_range: float = 300.0
@export var attack_damage: float = 10.0
@export var attack_rate: float = 1.0

@onready var detect_area: Area2D = $DetectArea
@onready var shoot_timer: Timer = $ShootTimer

func _ready():
	# 设置塔类型
	tower_type = "shooter"

	# 从注入的 Resource 初始化（HP 由 super._ready() 处理）
	if data:
		_initial_max_hp = data.hp
		attack_damage = data.damage * GameData.player_stats["tower_mult"]
		attack_rate = data.fire_rate
		attack_range = data.attack_range
	else:
		# 向后兼容
		var tower_config: Dictionary = GameConfig.TOWERS[tower_type]
		_initial_max_hp = tower_config["hp"]
		attack_damage = tower_config["damage"] * GameData.player_stats["tower_mult"]
		attack_rate = tower_config["fire_rate"]
		attack_range = tower_config["range"]

	super._ready()
	shoot_timer.wait_time = attack_rate
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	shoot_timer.start()

func _on_shoot_timer_timeout():
	shoot_nearest_enemy()

func shoot_nearest_enemy():
	var enemies = detect_area.get_overlapping_bodies()
	var closest = null
	var min_dist = attack_range

	for enemy in enemies:
		if enemy.is_in_group("enemies"):
			var dist = global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy

	if closest:
		var bullet = SceneFactory.create_bullet()
		bullet.global_position = global_position
		bullet.direction = global_position.direction_to(closest.global_position)
		bullet.damage = attack_damage
		get_parent().add_child(bullet)
