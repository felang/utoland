extends CharacterBody2D

enum State { CHASE_PLAYER, ATTACK_TOWER }

# 由 SceneFactory 注入的 Resource 数据
var data: EnemyData = null

# 敌人类型（由 SceneFactory 设置）
var enemy_type: String = "normal"

@export var tower_attack_rate: float = 1.0
@export var touch_damage: float = 10.0

var speed: float
var tower_attack_damage: float
var current_state = State.CHASE_PLAYER
var target_tower = null
var attack_timer: float = 0.0
var player: Node2D = null

@onready var _health: HealthComponent = $HealthComponent
@onready var _knockback: KnockbackHandler = $KnockbackHandler
@onready var _slow: SlowHandler = $SlowHandler
@onready var _sprite_animator: SpriteAnimator = $SpriteAnimator

func _ready():
	# 从注入的 Resource 初始化（SceneFactory 设置 data）
	if data:
		_health.initialize(data.hp)
		speed = data.speed
		tower_attack_damage = data.damage
		_slow.initialize(data.speed)
	else:
		# 向后兼容：如果没有注入 data，从 GameConfig 读取
		var enemy_config: Dictionary = GameConfig.ENEMIES[enemy_type]
		_health.initialize(enemy_config["hp"])
		speed = enemy_config["speed"]
		tower_attack_damage = enemy_config["damage"]
		_slow.initialize(enemy_config["speed"])

	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")

	# 连接组件信号
	_health.died.connect(_on_died)
	_slow.speed_changed.connect(_on_speed_changed)

	# 设置精灵
	var sprite_config: Dictionary = GameConfig.SPRITES["enemies"].get(enemy_type, {})
	var target_size: float = float(GameConfig.ENTITY_SIZE_TANK if enemy_type == "tank" else GameConfig.ENTITY_SIZE_STANDARD)
	_sprite_animator._sprite = null  # 确保重新创建
	# 获取死亡特效颜色（从旧 Visual）
	_health.death_color = _sprite_animator.get_death_color_from_visual()
	_sprite_animator.setup_enemy_sprite(sprite_config, target_size)

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
		_sprite_animator.update_animation_no_idle(velocity)

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
	_health.take_damage(amount)

func die() -> void:
	_on_died()

func _on_died() -> void:
	_knockback.kill_tween()
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

	var coin_min: int
	var coin_max: int
	if data:
		coin_min = data.coin_drop_min
		coin_max = data.coin_drop_max
	else:
		var enemy_config: Dictionary = GameConfig.ENEMIES[enemy_type]
		coin_min = enemy_config["coin_drop_min"]
		coin_max = enemy_config["coin_drop_max"]

	var coin_count: int = randi_range(coin_min, coin_max)
	for i in coin_count:
		var coin = SceneFactory.create_coin()
		coin.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		parent.call_deferred("add_child", coin)

func apply_knockback(dir: Vector2) -> void:
	_knockback.apply_knockback(dir)

func _flash_white() -> void:
	EffectsManager.flash_white(self)

func apply_slow(slow_percent: float):
	_slow.apply_slow(slow_percent)

func remove_slow(slow_percent: float):
	_slow.remove_slow(slow_percent)

func _on_speed_changed(new_speed: float) -> void:
	speed = new_speed

# 向后兼容属性（供外部代码和测试读取）
var current_hp: float:
	get: return _health.current_hp if _health else 0.0
	set(value):
		if _health:
			_health.current_hp = value

var max_hp: float:
	get: return _health.max_hp if _health else 0.0
	set(value):
		if _health:
			_health.max_hp = value

var base_speed: float:
	get: return _slow.base_speed if _slow else 0.0
	set(value):
		if _slow:
			_slow.base_speed = value
