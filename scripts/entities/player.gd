extends CharacterBody2D

const DEATH_TRANSITION_DELAY: float = 1.0     # 死亡后跳转延迟（秒）
const BLINK_RESET_DURATION: float = 0.01      # 闪烁结束后恢复透明度时间

var speed: float = 0.0  # 从 GameData 初始化
@export var invincible_duration: float = 0.5
var coins: int = 0
var _input_enabled: bool = true
var invincible_timer: float = 0.0
var _blink_tween: Tween = null

@onready var health: HealthComponent = $HealthComponent
@onready var _weapon_manager: WeaponManager = $WeaponManager
@onready var _sprite_animator: SpriteAnimator = $SpriteAnimator

func _ready() -> void:
	add_to_group(Enums.Group.PLAYER)

	# 应用被动属性
	var max_hp: float = GameData.player_stats[Enums.Stat.MAX_HP] * GameData.player_stats[Enums.Stat.HP_MULT]
	health.initialize(max_hp)
	speed = GameData.character_speed

	# 应用待处理的治疗
	if GameData.pending_heal > 0:
		health.heal(GameData.pending_heal)
		GameData.pending_heal = 0

	# 初始化武器系统（从 deployed_weapons 注入等级）
	_weapon_manager.initialize(GameData.deployed_weapons)

	# 同步金币
	coins = GameData.coins

	# 连接组件信号
	health.died.connect(_on_died)
	$Hurtbox.hit_taken.connect(_on_hurtbox_hit)

	# 设置精灵（从 CharacterData 加载 SpriteFrames）
	var char_data: CharacterData = GameConfig.characters[GameData.current_character]
	var sprite_frames: SpriteFrames = load(char_data.sprite_frames_path)
	_sprite_animator.setup_from_sprite_frames(sprite_frames, char_data.sprite_pixel_size, GameConfig.ENTITY_SIZE_STANDARD)

	# 新被动技能初始化
	_init_passives()

func _process(delta: float) -> void:
	if invincible_timer > 0:
		invincible_timer -= delta

	# 武器系统更新
	_weapon_manager.tick(delta)

	# 被动技能更新
	_process_passives(delta)

func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled

func _physics_process(_delta: float) -> void:
	if not _input_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return
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
	GameData.reset_kill_streak()
	EventBus.player_died.emit()
	await get_tree().create_timer(DEATH_TRANSITION_DELAY).timeout
	SceneManager.go_to(Enums.Scene.RESULT)

func add_coins(amount: int) -> void:
	coins += amount
	GameData.coins = coins  # 同步到 GameData

func add_exp(amount: int) -> void:
	GameData.add_exp(amount)
	EventBus.exp_collected.emit(amount, global_position)

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

# ===== 新被动系统 =====

## 疾风连击（Kaze）— 连续攻击同一目标叠加伤害
var _combo_target: Node2D = null
var _combo_stacks: int = 0
const _COMBO_MAX_STACKS: int = 6  # max_mult = value_2 / value = 0.3/0.05 = 6

## 坚壁回馈（Dora）— 每 5 秒回复 2% 最大 HP
var _fortify_regen_timer: float = 0.0
const _FORTIFY_REGEN_INTERVAL: float = 5.0

func _init_passives() -> void:
	match GameData.new_passive_id:
		"swift_combo":
			_combo_target = null
			_combo_stacks = 0
		"fortify_regen":
			_fortify_regen_timer = 0.0

func _process_passives(delta: float) -> void:
	if GameData.new_passive_id == "fortify_regen":
		_fortify_regen_timer += delta
		if _fortify_regen_timer >= _FORTIFY_REGEN_INTERVAL:
			_fortify_regen_timer -= _FORTIFY_REGEN_INTERVAL
			var heal_pct: float = GameData.new_passive_value  # 0.02
			# 坚壁回馈：≥3 个 fortify 标签单位存活时治疗翻倍
			var fortify_count: int = _count_fortify_units()
			if fortify_count >= int(GameData.new_passive_value_2):
				heal_pct *= 2.0
			health.heal(health.max_hp * heal_pct)

## 获取连击伤害倍率（供武器查询）
func get_combo_damage_mult() -> float:
	if GameData.new_passive_id != "swift_combo":
		return 1.0
	return 1.0 + (_combo_stacks * GameData.new_passive_value)

## 更新连击目标（武器命中时调用）
func update_combo_target(target: Node2D) -> void:
	if GameData.new_passive_id != "swift_combo":
		return
	if target == _combo_target:
		_combo_stacks = mini(_combo_stacks + 1, _COMBO_MAX_STACKS)
	else:
		_combo_target = target
		_combo_stacks = 0

## 统计上场塔数量
func _count_fortify_units() -> int:
	return get_tree().get_nodes_in_group(Enums.Group.TOWERS).size()

## 获取血怒伤害倍率（Gorg）— 供武器/塔查询 AOE 伤害加成
func get_blood_rage_mult() -> float:
	if GameData.new_passive_id != "blood_rage":
		return 1.0
	var hp_pct: float = health.current_hp / health.max_hp
	var lost_pct: float = 1.0 - hp_pct
	return 1.0 + minf(lost_pct / 0.1 * GameData.new_passive_value, GameData.new_passive_value_2)
