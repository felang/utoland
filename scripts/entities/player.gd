extends CharacterBody2D

var speed: float = 0.0  # 从 GameData 初始化
@export var invincible_duration: float = 0.5
var coins: int = 0
var invincible_timer: float = 0.0
var hp_regen_timer: float = 0.0
var _blink_tween: Tween = null

@onready var health: HealthComponent = $HealthComponent
@onready var _weapon_manager: WeaponManager = $WeaponManager
@onready var _sprite_animator: SpriteAnimator = $SpriteAnimator

func _ready() -> void:
	add_to_group(Enums.Group.PLAYER)

	# 重置生命回复计时器（修复已知问题 #2）
	hp_regen_timer = 0.0

	# 应用被动属性
	var max_hp: float = GameData.player_stats[Enums.Stat.MAX_HP] * GameData.player_stats[Enums.Stat.HP_MULT]
	health.initialize(max_hp)
	speed = GameData.character_speed * GameData.player_stats[Enums.Stat.MOVE_SPEED_MULT]

	# 应用待处理的治疗
	if GameData.pending_heal > 0:
		health.heal(GameData.pending_heal)
		GameData.pending_heal = 0

	# 初始化武器系统
	_weapon_manager.initialize([GameData.selected_weapon])

	# 同步金币
	coins = GameData.coins

	# 连接组件信号
	health.died.connect(_on_died)
	$Hurtbox.hit_taken.connect(_on_hurtbox_hit)

	# 设置精灵
	var character: String = GameData.current_character
	var sprite_config: Dictionary = GameConfig.SPRITES["player"].get(character, {})
	var target_size: float = GameConfig.ENTITY_SIZE_STANDARD
	_sprite_animator.setup_player_sprite(sprite_config, target_size)

func _process(delta: float) -> void:
	if invincible_timer > 0:
		invincible_timer -= delta

	# 武器系统更新
	_weapon_manager.tick(delta)

	# 生命回复机制
	hp_regen_timer += delta
	if hp_regen_timer >= GameConfig.PLAYER["hp_regen_interval"]:
		hp_regen_timer = 0.0
		var regen_amount: float = GameData.character_hp_regen + GameData.player_stats[Enums.Stat.HP_REGEN]
		if regen_amount > 0:
			health.heal(regen_amount)

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

func _on_hurtbox_hit(damage: float, _knockback: Vector2) -> void:
	if invincible_timer > 0:
		return
	# 闪避判定
	if GameData.dodge_chance > 0.0 and randf() < GameData.dodge_chance:
		return
	# 护盾判定
	if GameData.current_shield > 0:
		GameData.current_shield -= 1
		return
	# 减伤
	var final_damage: float = damage * (1.0 - GameData.damage_reduction)
	health.take_damage_no_sparks(final_damage)
	_flash_white()
	invincible_timer = invincible_duration
	var fx: EffectConfigData = GameConfig.effects
	EventBus.camera_shake_requested.emit(fx.camera_shake_player_hit_intensity, fx.camera_shake_player_hit_duration)

# 保留供塔攻击等外部系统调用；投射物伤害通过 Hurtbox 信号处理
func take_damage(amount: float) -> void:
	if invincible_timer > 0:
		return
	if GameData.dodge_chance > 0.0 and randf() < GameData.dodge_chance:
		return
	if GameData.current_shield > 0:
		GameData.current_shield -= 1
		return
	var final_damage: float = amount * (1.0 - GameData.damage_reduction)
	health.take_damage_no_sparks(final_damage)
	_flash_white()
	invincible_timer = invincible_duration
	var fx: EffectConfigData = GameConfig.effects
	EventBus.camera_shake_requested.emit(fx.camera_shake_player_hit_intensity, fx.camera_shake_player_hit_duration)

func _on_died() -> void:
	print("Player died!")
	EventBus.player_died.emit()
	await get_tree().create_timer(1.0).timeout
	SceneManager.go_to(Enums.Scene.RESULT)

func add_coins(amount: int) -> void:
	coins += amount
	GameData.coins = coins  # 同步到 GameData

## 吸血回复：供投射物命中敌人后调用
func heal_hp(amount: float) -> void:
	if amount > 0.0:
		health.heal(amount)

func _flash_white() -> void:
	var tween: Tween = EffectsManager.flash_white(self)
	tween.tween_callback(_start_invincible_blink)

func _start_invincible_blink() -> void:
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	var fx: EffectConfigData = GameConfig.effects
	var blink_count: int = int(invincible_duration / (fx.invincible_blink_interval * 2))
	_blink_tween = create_tween()
	for i in blink_count:
		_blink_tween.tween_property(self, "modulate:a", fx.invincible_blink_alpha_low, fx.invincible_blink_interval)
		_blink_tween.tween_property(self, "modulate:a", fx.invincible_blink_alpha_high, fx.invincible_blink_interval)
	_blink_tween.tween_property(self, "modulate:a", 1.0, 0.01)
