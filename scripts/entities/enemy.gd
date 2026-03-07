extends CharacterBody2D

enum State { CHASE_PLAYER, ATTACK_TOWER }

# 敌人类型（由生成器设置）
var enemy_type: String = "normal"

@export var tower_attack_rate: float = 1.0
@export var touch_damage: float = 10.0

var speed: float
var max_hp: float
var tower_attack_damage: float
var base_speed: float
var current_hp: float
var current_state = State.CHASE_PLAYER
var target_tower = null
var attack_timer: float = 0.0
var player: Node2D = null
var slow_effects: int = 0  # 记录当前有多少个减速效果
var _knockback_tween: Tween = null
var _sprite: AnimatedSprite2D = null
var _current_anim: String = ""
var _death_color: Color = Color.RED  # 死亡特效颜色

func _ready():
	# 从配置读取敌人属性
	var enemy_data = GameConfig.ENEMIES[enemy_type]
	max_hp = enemy_data["hp"]
	current_hp = max_hp
	speed = enemy_data["speed"]
	base_speed = speed
	tower_attack_damage = enemy_data["damage"]

	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")

	# 替换 ColorRect 为 AnimatedSprite2D
	_setup_sprite()

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
		_update_animation()

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
	_flash_white()
	# 伤害数字
	EffectsManager.spawn_damage_number(global_position + Vector2(0, -20), amount)
	# 击中火花
	EffectsManager.spawn_hit_sparks(global_position)
	if current_hp <= 0:
		die()

func die():
	# 清理活跃的 tween
	if _knockback_tween and _knockback_tween.is_valid():
		_knockback_tween.kill()
	# 死亡爆炸特效
	EffectsManager.spawn_death_effect(global_position, _death_color)
	# 屏幕震动
	var shake_config: Dictionary = GameConfig.EFFECTS["camera_shake"]["enemy_kill"]
	EventBus.camera_shake_requested.emit(shake_config["intensity"], shake_config["duration"])
	EventBus.enemy_killed.emit(enemy_type, global_position)
	drop_coins()
	queue_free()

func drop_coins():
	var parent = get_parent()
	if not parent:
		return

	# 从配置读取金币掉落数量
	var enemy_data = GameConfig.ENEMIES[enemy_type]
	var coin_count = randi_range(enemy_data["coin_drop_min"], enemy_data["coin_drop_max"])
	for i in coin_count:
		var coin = SceneFactory.create_coin()
		coin.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		parent.call_deferred("add_child", coin)

func apply_knockback(dir: Vector2) -> void:
	var config: Dictionary = GameConfig.EFFECTS["knockback"]
	if _knockback_tween and _knockback_tween.is_valid():
		_knockback_tween.kill()
	_knockback_tween = create_tween()
	var target_pos: Vector2 = global_position + dir * config["distance"]
	_knockback_tween.tween_property(self, "global_position", target_pos, config["duration"]).set_ease(Tween.EASE_OUT)

func _flash_white() -> void:
	EffectsManager.flash_white(self)

func apply_slow(slow_percent: float):
	slow_effects += 1
	if slow_effects == 1:
		speed = base_speed * (1.0 - slow_percent)

func remove_slow(_slow_percent: float):
	slow_effects -= 1
	if slow_effects <= 0:
		slow_effects = 0
		speed = base_speed

func _setup_sprite() -> void:
	# 移除旧的 ColorRect Visual
	var old_visual: Node = get_node_or_null("Visual")
	if old_visual:
		# 保存颜色作为死亡特效颜色
		if old_visual is ColorRect:
			_death_color = old_visual.color
		old_visual.queue_free()

	# 创建 AnimatedSprite2D
	var sprite_config: Dictionary = GameConfig.SPRITES["enemies"].get(enemy_type, {})
	if sprite_config.is_empty():
		return

	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Visual"
	_sprite.sprite_frames = SpriteLoader.create_enemy_sprite_frames(sprite_config)
	# 根据敌人类型缩放：tank=45px，其他=30px
	var target_size: float = float(GameConfig.ENTITY_SIZE_TANK if enemy_type == "tank" else GameConfig.ENTITY_SIZE_STANDARD)
	var sprite_size: float = sprite_config["frame_size"].x
	_sprite.scale = Vector2.ONE * (target_size / sprite_size)
	add_child(_sprite)
	move_child(_sprite, 0)
	_sprite.play("walk_down")
	_current_anim = "walk_down"

func _update_animation() -> void:
	if not _sprite:
		return
	var anim: String = SpriteLoader.get_walk_animation(velocity, _current_anim)
	if anim == "idle":
		return
	if anim != _current_anim and _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)
		_current_anim = anim
