extends CharacterBody2D

var speed: float = 0.0  # 从 GameData 初始化
var max_hp: float = 0.0  # 从 GameData 初始化
@export var weapon_range: float = 300.0
@export var fire_rate: float = 0.1
@export var invincible_duration: float = 0.5
var current_hp: float = 0.0
var coins: int = 0
var shoot_timer: float = 0.0
var invincible_timer: float = 0.0
var weapon_damage: float = 10.0
var hp_regen_timer: float = 0.0
var _blink_tween: Tween = null
var _sprite: AnimatedSprite2D = null
var _current_anim: String = ""

func _ready() -> void:
	add_to_group("player")

	# 重置生命回复计时器（修复已知问题 #2）
	hp_regen_timer = 0.0

	# 应用被动属性
	max_hp = GameData.player_stats["max_hp"] * GameData.player_stats["hp_mult"]
	current_hp = max_hp
	speed = GameData.character_speed * GameData.player_stats["move_speed_mult"]

	# 应用待处理的治疗
	if GameData.pending_heal > 0:
		current_hp = min(current_hp + GameData.pending_heal, max_hp)
		GameData.pending_heal = 0

	# 从 GameConfig 读取武器配置
	var weapon_data: Dictionary = GameConfig.WEAPONS[GameData.selected_weapon]
	fire_rate = weapon_data["fire_rate"] / GameData.player_stats["attack_speed_mult"]
	weapon_damage = weapon_data["damage"] * GameData.player_stats["damage_mult"]
	weapon_range = weapon_data["range"]

	# 同步金币
	coins = GameData.coins

	# 替换 ColorRect 为 AnimatedSprite2D
	_setup_sprite()

func _process(delta: float) -> void:
	if invincible_timer > 0:
		invincible_timer -= delta
	shoot_timer -= delta
	if shoot_timer <= 0:
		auto_shoot()

	# 生命回复机制
	hp_regen_timer += delta
	if hp_regen_timer >= GameConfig.PLAYER["hp_regen_interval"]:
		hp_regen_timer = 0.0
		var regen_amount: float = GameData.character_hp_regen + GameData.player_stats["hp_regen"]
		if regen_amount > 0:
			current_hp = min(current_hp + regen_amount, max_hp)

func _physics_process(_delta: float) -> void:
	var input_vector: Vector2 = Vector2.ZERO
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")

	if input_vector.length() > 0:
		input_vector = input_vector.normalized()

	velocity = input_vector * speed
	move_and_slide()

	# 更新精灵动画
	_update_animation()

	# 摄像机前瞻
	var camera: Camera2D = $Camera
	if camera and camera.has_method("update_look_ahead"):
		camera.update_look_ahead(velocity)

	check_enemy_collision()

func check_enemy_collision() -> void:
	for i in get_slide_collision_count():
		var collision: KinematicCollision2D = get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider and collider.is_in_group("enemies"):
			if invincible_timer <= 0:
				var enemy: Node = collider
				if "touch_damage" in enemy:
					take_damage(enemy.touch_damage)
				else:
					# 如果敌人没有 touch_damage 属性，使用配置的默认值
					take_damage(GameConfig.PLAYER["default_enemy_touch_damage"])
				invincible_timer = invincible_duration

func take_damage(amount: float) -> void:
	current_hp -= amount
	# 受击闪白
	_flash_white()
	# 屏幕震动
	var shake_config: Dictionary = GameConfig.EFFECTS["camera_shake"]["player_hit"]
	EventBus.camera_shake_requested.emit(shake_config["intensity"], shake_config["duration"])
	print("Player HP: ", current_hp)
	if current_hp <= 0:
		die()

func die() -> void:
	print("Player died!")
	EventBus.player_died.emit()
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/result.tscn")

func auto_shoot() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var closest_enemy: Node2D = null
	var min_distance: float = weapon_range

	for enemy in enemies:
		if enemy is Node2D:
			var distance: float = global_position.distance_to(enemy.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_enemy = enemy

	if closest_enemy:
		shoot_weapon(closest_enemy.global_position)

	shoot_timer = fire_rate

func shoot_weapon(target_pos: Vector2) -> void:
	var weapon_data: Dictionary = GameConfig.WEAPONS[GameData.selected_weapon]
	var projectile_type: String = weapon_data["projectile_type"]

	match projectile_type:
		"bullet":
			_shoot_bullet(target_pos)
		"boomerang":
			_shoot_boomerang(target_pos)
		"laser":
			_shoot_laser(target_pos)

func _shoot_bullet(target_pos: Vector2) -> void:
	var bullet: Area2D = SceneFactory.create_bullet()
	bullet.global_position = global_position
	bullet.direction = global_position.direction_to(target_pos)
	bullet.damage = weapon_damage
	var parent: Node = get_parent()
	if parent:
		parent.add_child(bullet)
		_spawn_muzzle_flash(global_position)
	else:
		push_error("Player has no parent to add bullet to")
		bullet.queue_free()

func _shoot_boomerang(target_pos: Vector2) -> void:
	var boomerang: Area2D = SceneFactory.create_boomerang()
	boomerang.global_position = global_position
	boomerang.direction = global_position.direction_to(target_pos)
	boomerang.damage = weapon_damage
	boomerang.player = self
	var parent: Node = get_parent()
	if parent:
		parent.add_child(boomerang)
	else:
		push_error("Player has no parent to add boomerang to")
		boomerang.queue_free()

func _shoot_laser(target_pos: Vector2) -> void:
	var laser_config: Dictionary = GameConfig.WEAPONS[GameData.selected_weapon]
	var beam_range: float = laser_config["beam_range"]
	var direction: Vector2 = global_position.direction_to(target_pos)
	var end_pos: Vector2 = global_position + direction * beam_range

	# 射线查询：检测线上所有敌人（贯穿）
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var laser_mask: int = GameConfig.effects.laser_collision_mask if GameConfig.effects else 2
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		global_position, end_pos, laser_mask  # collision_mask (enemies layer)
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	# 循环射线查询实现贯穿
	var hit_enemies: Array = []
	var from: Vector2 = global_position
	var ray_limit: int = GameConfig.effects.laser_ray_query_limit if GameConfig.effects else 20
	for i in range(ray_limit):  # 安全上限
		query.from = from
		var result: Dictionary = space_state.intersect_ray(query)
		if result.is_empty():
			break
		var collider: Node2D = result["collider"]
		if collider.is_in_group("enemies") and collider not in hit_enemies:
			hit_enemies.append(collider)
			if collider.has_method("take_damage"):
				collider.take_damage(weapon_damage)
			if collider.has_method("apply_knockback"):
				collider.apply_knockback(direction)
		from = result["position"] + direction * 1.0
		query.exclude.append(collider.get_rid())

	# 生成视觉效果
	var beam: Node2D = SceneFactory.create_laser_beam()
	var parent: Node = get_parent()
	if parent:
		parent.add_child(beam)
		beam.fire(global_position, end_pos)
		# 全屏红色频闪
		var flash_config: Dictionary = GameConfig.EFFECTS["laser"]
		var flash: ColorRect = ColorRect.new()
		flash.color = Color(1, 0, 0, flash_config["flash_alpha"])
		var flash_size: Vector2 = GameConfig.effects.laser_flash_size if GameConfig.effects else Vector2(2000, 2000)
		flash.size = flash_size
		flash.position = global_position - flash_size / 2
		flash.z_index = GameConfig.effects.laser_flash_z_index if GameConfig.effects else 90
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(flash)
		var flash_tween: Tween = create_tween()
		flash_tween.tween_property(flash, "modulate:a", 0.0, flash_config["flash_duration"])
		flash_tween.tween_callback(flash.queue_free)
	else:
		push_error("Player has no parent to add laser beam to")
		beam.queue_free()

func _setup_sprite() -> void:
	# 移除旧的 ColorRect Visual
	var old_visual: Node = get_node_or_null("Visual")
	if old_visual:
		old_visual.queue_free()

	# 创建 AnimatedSprite2D
	var character: String = GameData.current_character
	var sprite_config: Dictionary = GameConfig.SPRITES["player"].get(character, {})
	if sprite_config.is_empty():
		return

	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Visual"
	_sprite.sprite_frames = SpriteLoader.create_player_sprite_frames(sprite_config)
	# 16px 精灵缩放到 30px 显示大小
	var target_size: float = GameConfig.ENTITY_SIZE_STANDARD
	var sprite_size: float = sprite_config["frame_size"].x
	_sprite.scale = Vector2.ONE * (target_size / sprite_size)
	add_child(_sprite)
	# 确保在 CollisionShape2D 之上渲染
	move_child(_sprite, 0)
	_sprite.play("idle")
	_current_anim = "idle"

func _update_animation() -> void:
	if not _sprite:
		return
	var anim: String = SpriteLoader.get_walk_animation(velocity, _current_anim)
	if anim != _current_anim:
		if _sprite.sprite_frames.has_animation(anim):
			_sprite.play(anim)
			_current_anim = anim

func add_coins(amount: int) -> void:
	coins += amount
	GameData.coins = coins  # 同步到 GameData

func _spawn_muzzle_flash(pos: Vector2) -> void:
	var mf_size: Vector2 = GameConfig.effects.muzzle_flash_size if GameConfig.effects else Vector2(6, 6)
	var mf_color: Color = GameConfig.effects.muzzle_flash_color if GameConfig.effects else Color(1, 1, 0.8, 0.9)
	var mf_z_index: int = GameConfig.effects.muzzle_flash_z_index if GameConfig.effects else 10
	var mf_duration: float = GameConfig.effects.muzzle_flash_duration if GameConfig.effects else 0.05
	var flash: ColorRect = ColorRect.new()
	flash.size = mf_size
	flash.position = pos - mf_size / 2
	flash.color = mf_color
	flash.z_index = mf_z_index
	var parent_node: Node = get_parent()
	if parent_node:
		parent_node.add_child(flash)
		var tween: Tween = create_tween()
		tween.tween_property(flash, "scale", Vector2(0.1, 0.1), mf_duration).set_ease(Tween.EASE_OUT)
		tween.tween_callback(flash.queue_free)

func _flash_white() -> void:
	var tween: Tween = EffectsManager.flash_white(self)
	tween.tween_callback(_start_invincible_blink)

func _start_invincible_blink() -> void:
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	var config: Dictionary = GameConfig.EFFECTS["invincible_blink"]
	var blink_count: int = int(invincible_duration / (config["interval"] * 2))
	_blink_tween = create_tween()
	for i in blink_count:
		_blink_tween.tween_property(self, "modulate:a", config["alpha_low"], config["interval"])
		_blink_tween.tween_property(self, "modulate:a", config["alpha_high"], config["interval"])
	_blink_tween.tween_property(self, "modulate:a", 1.0, 0.01)
