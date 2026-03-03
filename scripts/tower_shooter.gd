extends Tower

@export var attack_range: float = 250.0
@export var attack_damage: float = 10.0
@export var attack_rate: float = 1.0

var attack_timer: float = 0.0
var bullet_scene = preload("res://scenes/bullet.tscn")

func _process(delta):
	attack_timer -= delta
	if attack_timer <= 0:
		shoot_nearest_enemy()

func shoot_nearest_enemy():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest = null
	var min_dist = attack_range
	
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = enemy
	
	if closest:
		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position
		bullet.direction = global_position.direction_to(closest.global_position)
		bullet.damage = attack_damage
		get_parent().add_child(bullet)
		attack_timer = attack_rate
