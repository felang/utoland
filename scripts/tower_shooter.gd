extends Tower

@export var attack_range: float = 300.0
@export var attack_damage: float = 10.0
@export var attack_rate: float = 1.0

@onready var detect_area: Area2D = $DetectArea
@onready var shoot_timer: Timer = $ShootTimer

const BULLET_SCENE = preload("res://scenes/bullet.tscn")

func _ready():
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
		var bullet = BULLET_SCENE.instantiate()
		bullet.global_position = global_position
		bullet.direction = global_position.direction_to(closest.global_position)
		bullet.damage = attack_damage
		get_parent().add_child(bullet)
