extends CharacterBody2D

const DEATH_TRANSITION_DELAY: float = 1.0     # 死亡后跳转延迟（秒）
const BLINK_RESET_DURATION: float = 0.01      # 闪烁结束后恢复透明度时间

var speed: float = 0.0  # 从 PlayerState 初始化
@export var invincible_duration: float = 0.5
var coins: int = 0
var _input_enabled: bool = true
var invincible_timer: float = 0.0
var _blink_tween: Tween = null

# 通用属性成长（每级复利）
const LEVEL_HP_GROWTH: float = 0.03       # +3% HP/级
const LEVEL_SPEED_GROWTH: float = 0.02    # +2% 移速/级
const LEVEL_PICKUP_GROWTH: float = 0.05   # +5% 拾取范围/级
var pickup_range_mult: float = 1.0
var _base_max_hp: float = 0.0
var _base_speed: float = 0.0

@onready var health: HealthComponent = $HealthComponent
@onready var _sprite_animator: SpriteAnimator = $SpriteAnimator

func _ready() -> void:
	add_to_group(Enums.Group.PLAYER)

	# 初始化基础值（不含 perk，perk 在 _apply_level_growth 中统一应用）
	var base_hp: float = PlayerState.player_stats[Enums.Stat.MAX_HP]
	_base_max_hp = base_hp
	_base_speed = PlayerState.character_speed
	speed = _base_speed
	# 初始 HP 通过 _apply_level_growth 在 _ready 末尾设置，这里先用基础值初始化
	health.initialize(base_hp)

	# 同步金币
	coins = InventoryManager.coins

	# 连接组件信号
	health.died.connect(_on_died)
	$Hurtbox.hit_taken.connect(_on_hurtbox_hit)

	# 设置精灵（从 CharacterData 加载 SpriteFrames）
	var char_data: CharacterData = GameConfig.characters[PlayerState.current_character]
	var sprite_frames: SpriteFrames = load(char_data.sprite_frames_path)
	# 检查帧是否为空（占位 SpriteFrames 无纹理），用彩色方块兜底
	var has_frames: bool = false
	for anim_name in sprite_frames.get_animation_names():
		if sprite_frames.get_frame_count(anim_name) > 0:
			has_frames = true
			break
	if has_frames:
		_sprite_animator.setup_from_sprite_frames(sprite_frames, char_data.sprite_pixel_size, GameConfig.ENTITY_SIZE_STANDARD)
	else:
		_create_placeholder_sprite()

	# 挂载能力组件
	_mount_abilities()

	# 连接升级信号并应用当前等级成长
	EventBus.player_level_changed.connect(_on_level_up)
	_apply_level_growth(PlayerProgression.player_level)
	EventBus.perk_applied.connect(_on_perk_applied)

func _process(delta: float) -> void:
	if invincible_timer > 0:
		invincible_timer -= delta

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
	StatsTracker.record_damage_taken(raw_damage)
	_flash_white()
	invincible_timer = invincible_duration
	var fx: EffectConfigData = GameConfig.effects
	EventBus.camera_shake_requested.emit(fx.camera_shake_player_hit_intensity, fx.camera_shake_player_hit_duration)

func _on_died() -> void:
	StatsTracker.reset_kill_streak()
	EventBus.player_died.emit()
	await get_tree().create_timer(DEATH_TRANSITION_DELAY).timeout
	SceneManager.go_to(Enums.Scene.RESULT)

func add_coins(amount: int) -> void:
	coins += amount
	InventoryManager.coins = coins  # 同步到 InventoryManager

func add_exp(amount: int) -> void:
	PlayerProgression.add_exp(amount)
	EventBus.exp_collected.emit(amount, global_position)

func _on_level_up(new_level: int) -> void:
	_apply_level_growth(new_level)

func _apply_level_growth(level: int) -> void:
	var levels_gained: int = level - 1  # Lv1 = 0 次成长（但仍跑函数以应用 perk）
	var hp_perk: float = PlayerState.player_stats.get(Enums.Stat.HP_BONUS_PERCENT, 0.0)
	var move_perk: float = PlayerState.player_stats.get(Enums.Stat.MOVE_SPEED_BONUS_PERCENT, 0.0)
	var pickup_perk: float = PlayerState.player_stats.get(Enums.Stat.PICKUP_RADIUS_BONUS_PERCENT, 0.0)
	# HP 成长（复利 + perk）
	var hp_mult: float = pow(1.0 + LEVEL_HP_GROWTH, levels_gained)
	var new_max_hp: float = _base_max_hp * hp_mult * (1.0 + hp_perk)
	var hp_diff: float = new_max_hp - health.max_hp
	health.max_hp = new_max_hp
	if hp_diff > 0:
		health.heal(hp_diff)
	# 移速成长（复利 + perk）
	var speed_mult: float = pow(1.0 + LEVEL_SPEED_GROWTH, levels_gained)
	speed = _base_speed * speed_mult * (1.0 + move_perk)
	# 拾取范围成长（复利 + perk）
	pickup_range_mult = pow(1.0 + LEVEL_PICKUP_GROWTH, levels_gained) * (1.0 + pickup_perk)

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

func _create_placeholder_sprite() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "PlaceholderSprite"
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.8, 0.3))
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.scale = Vector2(2, 2)
	add_child(sprite)

func _on_perk_applied(_perk_id: String) -> void:
	# 重新跑 level growth,会读最新 perk bonus
	_apply_level_growth(PlayerProgression.player_level)

## 根据 CharacterData.ability_scenes 动态挂载能力组件
func _mount_abilities() -> void:
	var char_data: CharacterData = GameConfig.characters.get(PlayerState.current_character)
	if char_data == null or char_data.ability_scenes.is_empty():
		push_warning("Player: 无 ability_scenes 配置")
		return
	var container: Node = $Abilities
	# 能力数据路径，与 CharacterData.ability_scenes 顺序对应
	# TODO(#7): 多英雄支持时改为 CharacterData 字段驱动
	var ability_data_paths: Array[String] = [
		"res://resources/hero_abilities/ranger/auto_attack.tres",
		"res://resources/hero_abilities/ranger/gust_arrow.tres",
		"res://resources/hero_abilities/ranger/arrow_rain.tres",
		"res://resources/hero_abilities/ranger/hunt_mark.tres",
	]
	for i in range(char_data.ability_scenes.size()):
		var ps: PackedScene = char_data.ability_scenes[i]
		if ps == null:
			continue
		var inst: Node = ps.instantiate()
		# 注入数据资源
		if i < ability_data_paths.size():
			var data_res: Resource = load(ability_data_paths[i])
			if data_res != null and "data" in inst:
				inst.data = data_res
		container.add_child(inst)
