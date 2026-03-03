extends CharacterBody2D

enum State { CHASE_PLAYER, ATTACK_TOWER }

@export var speed: float = 150.0
@export var max_hp: float = 30.0
@export var tower_attack_damage: float = 5.0
@export var tower_attack_rate: float = 1.0
@export var touch_damage: float = 10.0

var base_speed: float
var current_hp: float
var current_state = State.CHASE_PLAYER
var target_tower = null
var attack_timer: float = 0.0
var player: Node2D = null
var slow_effects: int = 0  # 记录当前有多少个减速效果

func _ready():
	base_speed = speed
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

func attack_tower(_delta):
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
	drop_coins()
	queue_free()

func drop_coins():
	var parent = get_parent()
	if not parent:
		return

	var coin_scene = preload("res://scenes/coin.tscn")
	var coin_count = randi_range(1, 3)
	for i in coin_count:
		var coin = coin_scene.instantiate()
		coin.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		parent.call_deferred("add_child", coin)

func apply_slow(slow_percent: float):
	slow_effects += 1
	if slow_effects == 1:
		speed = base_speed * (1.0 - slow_percent)

func remove_slow(slow_percent: float):
	slow_effects -= 1
	if slow_effects <= 0:
		slow_effects = 0
		speed = base_speed
