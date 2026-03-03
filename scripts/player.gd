extends CharacterBody2D

@export var speed: float = 200.0
@export var max_hp: float = 100.0
@export var weapon_range: float = 300.0
@export var fire_rate: float = 0.1
@export var invincible_duration: float = 0.5
var current_hp: float
var coins: int = 0
var shoot_timer: float = 0.0
var invincible_timer: float = 0.0
var weapon_damage: float = 10.0
var bullet_scene = preload("res://scenes/bullet.tscn")
var hp_regen_timer: float = 0.0

func _ready():
	add_to_group("player")

	# 应用被动属性
	max_hp = GameData.player_stats["max_hp"]
	current_hp = max_hp
	speed = 200.0 * GameData.player_stats["move_speed_mult"]

	# 应用待处理的治疗
	if GameData.pending_heal > 0:
		current_hp = min(current_hp + GameData.pending_heal, max_hp)
		GameData.pending_heal = 0

	# 应用武器配置
	if GameData.selected_weapon == "rifle":
		fire_rate = 0.1 / GameData.player_stats["attack_speed_mult"]
		weapon_damage = 10.0 * GameData.player_stats["damage_mult"]
	elif GameData.selected_weapon == "shotgun":
		fire_rate = 0.5 / GameData.player_stats["attack_speed_mult"]
		weapon_damage = 8.0 * GameData.player_stats["damage_mult"]
	elif GameData.selected_weapon == "sniper":
		fire_rate = 1.0 / GameData.player_stats["attack_speed_mult"]
		weapon_damage = 30.0 * GameData.player_stats["damage_mult"]

	# 同步金币
	coins = GameData.coins

func _process(delta):
	if invincible_timer > 0:
		invincible_timer -= delta
	shoot_timer -= delta
	if shoot_timer <= 0:
		auto_shoot()

	# 生命回复机制
	hp_regen_timer += delta
	if hp_regen_timer >= 5.0:
		hp_regen_timer = 0.0
		var regen_amount = GameData.player_stats["hp_regen"]
		if regen_amount > 0:
			current_hp = min(current_hp + regen_amount, max_hp)

func _physics_process(_delta):
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")

	if input_vector.length() > 0:
		input_vector = input_vector.normalized()

	velocity = input_vector * speed
	move_and_slide()

	check_enemy_collision()

func check_enemy_collision():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("enemies"):
			if invincible_timer <= 0:
				var enemy = collider
				if "touch_damage" in enemy:
					take_damage(enemy.touch_damage)
				else:
					take_damage(10.0)  # 默认伤害值
				invincible_timer = invincible_duration

func take_damage(amount: float):
	current_hp -= amount
	print("Player HP: ", current_hp)
	if current_hp <= 0:
		die()

func die():
	print("Player died!")
	var wave_manager = get_tree().get_first_node_in_group("wave_manager")
	if wave_manager:
		GameData.current_wave = wave_manager.current_wave
		wave_manager.game_lost.emit()
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/result.tscn")

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
	# 霰弹枪发射5发子弹，扇形散开15度
	if GameData.selected_weapon == "shotgun":
		var base_direction = global_position.direction_to(target_pos)
		var base_angle = base_direction.angle()
		var spread_angles = [-7.5, -3.75, 0, 3.75, 7.5]  # 5发子弹，扇形散开15度

		for angle_offset in spread_angles:
			var bullet = bullet_scene.instantiate()
			bullet.global_position = global_position
			var angle_rad = deg_to_rad(angle_offset)
			bullet.direction = Vector2(cos(base_angle + angle_rad), sin(base_angle + angle_rad))
			bullet.damage = weapon_damage
			var parent = get_parent()
			if parent:
				parent.add_child(bullet)
			else:
				push_error("Player has no parent to add bullet to")
				bullet.queue_free()
	else:
		# 步枪和狙击枪发射单发子弹
		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position
		bullet.direction = global_position.direction_to(target_pos)
		bullet.damage = weapon_damage
		var parent = get_parent()
		if parent:
			parent.add_child(bullet)
		else:
			push_error("Player has no parent to add bullet to")
			bullet.queue_free()

func add_coins(amount: int):
	coins += amount
	GameData.coins = coins  # 同步到 GameData
