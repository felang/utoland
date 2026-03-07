extends CharacterBody2D

var speed: float = 0.0  # 从 GameData 初始化
@export var weapon_range: float = 300.0
@export var invincible_duration: float = 0.5
var coins: int = 0
var invincible_timer: float = 0.0
var hp_regen_timer: float = 0.0
var _blink_tween: Tween = null

@onready var _health: HealthComponent = $HealthComponent
@onready var _weapon: WeaponSystem = $WeaponSystem
@onready var _sprite_animator: SpriteAnimator = $SpriteAnimator

func _ready() -> void:
	add_to_group("player")

	# 重置生命回复计时器（修复已知问题 #2）
	hp_regen_timer = 0.0

	# 应用被动属性
	var max_hp: float = GameData.player_stats["max_hp"] * GameData.player_stats["hp_mult"]
	_health.initialize(max_hp)
	speed = GameData.character_speed * GameData.player_stats["move_speed_mult"]

	# 应用待处理的治疗
	if GameData.pending_heal > 0:
		_health.heal(GameData.pending_heal)
		GameData.pending_heal = 0

	# 初始化武器系统
	var weapon_res: WeaponData = GameConfig.weapons.get(GameData.selected_weapon)
	if weapon_res:
		_weapon.initialize(weapon_res, GameData.player_stats["damage_mult"], GameData.player_stats["attack_speed_mult"])
	else:
		# 向后兼容：从字典读取
		var weapon_dict: Dictionary = GameConfig.WEAPONS[GameData.selected_weapon]
		_weapon.fire_rate = weapon_dict["fire_rate"] / GameData.player_stats["attack_speed_mult"]
		_weapon.weapon_damage = weapon_dict["damage"] * GameData.player_stats["damage_mult"]
		_weapon.weapon_range = weapon_dict["range"]

	# 同步金币
	coins = GameData.coins

	# 连接组件信号
	_health.died.connect(_on_died)

	# 设置精灵
	var character: String = GameData.current_character
	var sprite_config: Dictionary = GameConfig.SPRITES["player"].get(character, {})
	var target_size: float = GameConfig.ENTITY_SIZE_STANDARD
	_sprite_animator.setup_player_sprite(sprite_config, target_size)

func _process(delta: float) -> void:
	if invincible_timer > 0:
		invincible_timer -= delta

	# 武器系统更新
	_weapon.process(delta)

	# 生命回复机制
	hp_regen_timer += delta
	if hp_regen_timer >= GameConfig.PLAYER["hp_regen_interval"]:
		hp_regen_timer = 0.0
		var regen_amount: float = GameData.character_hp_regen + GameData.player_stats["hp_regen"]
		if regen_amount > 0:
			_health.heal(regen_amount)

func _physics_process(_delta: float) -> void:
	var input_vector: Vector2 = Vector2.ZERO
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")

	if input_vector.length() > 0:
		input_vector = input_vector.normalized()

	velocity = input_vector * speed
	move_and_slide()

	# 更新精灵动画
	_sprite_animator.update_animation(velocity)

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
					take_damage(GameConfig.PLAYER["default_enemy_touch_damage"])
				invincible_timer = invincible_duration

func take_damage(amount: float) -> void:
	_health.take_damage_no_sparks(amount)
	# 受击闪白 + 无敌帧
	_flash_white()
	# 屏幕震动
	var shake_config: Dictionary = GameConfig.EFFECTS["camera_shake"]["player_hit"]
	EventBus.camera_shake_requested.emit(shake_config["intensity"], shake_config["duration"])
	print("Player HP: ", _health.current_hp)

func _on_died() -> void:
	print("Player died!")
	EventBus.player_died.emit()
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/result.tscn")

func add_coins(amount: int) -> void:
	coins += amount
	GameData.coins = coins  # 同步到 GameData

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

# 向后兼容属性（供外部代码读取）
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
