extends CharacterBody2D

const DEATH_TRANSITION_DELAY: float = 1.0     # 死亡后跳转延迟（秒）
const BLINK_RESET_DURATION: float = 0.01      # 闪烁结束后恢复透明度时间

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

	# 初始化武器系统（从 owned_weapons 读取所有已拥有武器）
	var weapon_ids: Array[String] = []
	for id: String in GameData.owned_weapons:
		weapon_ids.append(id)
	_weapon_manager.initialize(weapon_ids)

	# 同步金币
	coins = GameData.coins

	# 连接组件信号
	health.died.connect(_on_died)
	$Hurtbox.hit_taken.connect(_on_hurtbox_hit)

	# 设置精灵（从 CharacterData 加载 SpriteFrames）
	var char_data: CharacterData = GameConfig.characters[GameData.current_character]
	var sprite_frames: SpriteFrames = load(char_data.sprite_frames_path)
	_sprite_animator.setup_from_sprite_frames(sprite_frames, char_data.sprite_pixel_size, GameConfig.ENTITY_SIZE_STANDARD)

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
	AudioManager.play("player_hit")
	_apply_damage(damage)

# 保留供塔攻击等外部系统调用；投射物伤害通过 Hurtbox 信号处理
func take_damage(amount: float) -> void:
	if invincible_timer > 0:
		return
	_apply_damage(amount)

## 处理伤害并应用最终伤害
func _apply_damage(raw_damage: float) -> void:
	health.take_damage_no_sparks(raw_damage)
	GameData.record_damage_taken(raw_damage)
	_flash_white()
	invincible_timer = invincible_duration
	var fx: EffectConfigData = GameConfig.effects
	EventBus.camera_shake_requested.emit(fx.camera_shake_player_hit_intensity, fx.camera_shake_player_hit_duration)

func _on_died() -> void:
	print("Player died!")
	GameData.reset_kill_streak()
	EventBus.player_died.emit()
	await get_tree().create_timer(DEATH_TRANSITION_DELAY).timeout
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
	_blink_tween.tween_property(self, "modulate:a", 1.0, BLINK_RESET_DURATION)
