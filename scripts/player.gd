extends CharacterBody2D

@export var speed: float = 200.0
@export var max_hp: float = 100.0
@export var weapon_range: float = 300.0
@export var fire_rate: float = 0.1
var current_hp: float
var shoot_timer: float = 0.0
var bullet_scene = preload("res://scenes/bullet.tscn")

func _ready():
	current_hp = max_hp

func _process(delta):
	shoot_timer -= delta
	if shoot_timer <= 0:
		auto_shoot()

func _physics_process(_delta):
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_axis("ui_left", "ui_right")
	input_vector.y = Input.get_axis("ui_up", "ui_down")
	
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
	
	velocity = input_vector * speed
	move_and_slide()

func take_damage(amount: float):
	current_hp -= amount
	if current_hp <= 0:
		die()

func die():
	print("Player died!")
	get_tree().reload_current_scene()

func auto_shoot():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_enemy = null
	var min_distance = weapon_range

	for enemy in enemies:
		if enemy is Node2D:
			var distance = global_position.distance_to(enemy.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_enemy = enemy

	if closest_enemy:
		shoot_bullet(closest_enemy.global_position)

	shoot_timer = fire_rate

func shoot_bullet(target_pos: Vector2):
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = global_position.direction_to(target_pos)
	var parent = get_parent()
	if parent:
		parent.add_child(bullet)
	else:
		push_error("Player has no parent to add bullet to")
		bullet.queue_free()
