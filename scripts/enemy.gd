extends CharacterBody2D

enum State { CHASE_PLAYER, ATTACK_TOWER }

@export var speed: float = 150.0
@export var max_hp: float = 30.0
@export var tower_attack_damage: float = 5.0
@export var tower_attack_rate: float = 1.0

var current_hp: float
var current_state = State.CHASE_PLAYER
var target_tower = null
var attack_timer: float = 0.0
var player: Node2D = null

func _ready():
	current_hp = max_hp
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	attack_timer -= delta

	match current_state:
		State.CHASE_PLAYER:
			chase_player()
		State.ATTACK_TOWER:
			attack_tower(delta)

func chase_player():
	if player and is_instance_valid(player):
		velocity = position.direction_to(player.global_position) * speed
		move_and_slide()

		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			if collision.get_collider().is_in_group("towers"):
				current_state = State.ATTACK_TOWER
				target_tower = collision.get_collider()
				velocity = Vector2.ZERO

func attack_tower(delta):
	if not is_instance_valid(target_tower):
		current_state = State.CHASE_PLAYER
		return

	if attack_timer <= 0:
		target_tower.take_damage(tower_attack_damage)
		attack_timer = tower_attack_rate

func take_damage(amount: float):
	current_hp -= amount
	if current_hp <= 0:
		die()

func die():
	queue_free()
