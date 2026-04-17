extends CharacterBody2D

const EXP_SCATTER_RANGE: float = 40.0  # 经验球掉落散布范围（像素）

# 由 SceneFactory 注入的 Resource 数据
var data: EnemyData = null

# 敌人类型（由 SceneFactory 设置）
var enemy_type: String = "normal"
# 精英怪标识（由 SceneFactory 或生成逻辑设置）
var is_elite: bool = false
var _elite_exp_mult: float = 1.0

var speed: float
var player: Node2D = null

# Root（定身）系统
var is_rooted: bool = false
var _pre_root_speed: float = 0.0
var _root_source: String = ""  # 定身来源标记

# 对象池标识（由 SceneFactory 管理）
var _is_pooled: bool = false

# 寻塔 AI（targets_towers 时使用）
var _tower_target: Node2D = null
var _target_refresh_timer: float = 0.0
const TARGET_REFRESH_INTERVAL: float = 0.5

@onready var health: HealthComponent = $HealthComponent
@onready var _knockback: KnockbackHandler = $KnockbackHandler
@onready var slow_handler: SlowHandler = $SlowHandler
@onready var _sprite_animator: SpriteAnimator = $SpriteAnimator
@onready var _hitbox: Hitbox = $Hitbox

func _ready() -> void:
	# 从注入的 Resource 初始化（SceneFactory 设置 data）
	health.initialize(data.hp)
	_hitbox.damage = data.damage
	speed = data.speed
	slow_handler.initialize(data.speed)

	add_to_group(Enums.Group.ENEMIES)
	player = get_tree().get_first_node_in_group(Enums.Group.PLAYER)

	# 连接组件信号
	health.died.connect(_on_died)
	slow_handler.speed_changed.connect(_on_speed_changed)
	$Hurtbox.hit_taken.connect(_on_hurtbox_hit)

	# 设置精灵
	var sprite_config: Dictionary = GameConfig.SPRITES["enemies"].get(enemy_type, {})
	var target_size: float = float(GameConfig.ENTITY_SIZE_TANK if enemy_type == Enums.Enemy.TANK else GameConfig.ENTITY_SIZE_STANDARD)
	_sprite_animator._sprite = null  # 确保重新创建
	# 获取死亡特效颜色（从旧 Visual）
	health.death_color = _sprite_animator.get_death_color_from_visual()
	_sprite_animator.setup_enemy_sprite(sprite_config, target_size)

func _physics_process(delta: float) -> void:
	if data and data.targets_towers:
		_update_tower_target(delta)
		_chase_target(delta)
	else:
		_chase_player(delta)

func _chase_player(delta: float) -> void:
	# 击退速度（始终处理，即使定身也要滑行）
	var kb_vel: Vector2 = _knockback.tick(delta)
	if is_rooted:
		if kb_vel.length_squared() > 0:
			velocity = kb_vel
			move_and_slide()
		return
	if player and is_instance_valid(player):
		velocity = position.direction_to(player.global_position) * speed + kb_vel
		move_and_slide()
		_sprite_animator.update_animation_no_idle(velocity)

func _update_tower_target(delta: float) -> void:
	_target_refresh_timer -= delta
	if _target_refresh_timer <= 0:
		_target_refresh_timer = TARGET_REFRESH_INTERVAL
		_tower_target = _find_nearest_tower()

func _find_nearest_tower() -> Node2D:
	var towers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.TOWERS)
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for tower in towers:
		if not is_instance_valid(tower):
			continue
		var dist: float = global_position.distance_squared_to(tower.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = tower
	return nearest

func _chase_target(delta: float) -> void:
	var kb_vel: Vector2 = _knockback.tick(delta)
	if is_rooted:
		if kb_vel.length_squared() > 0:
			velocity = kb_vel
			move_and_slide()
		return
	if _tower_target and not is_instance_valid(_tower_target):
		_tower_target = null
		_target_refresh_timer = 0.0
	var target: Node2D = _tower_target if _tower_target else player
	if target and is_instance_valid(target):
		velocity = position.direction_to(target.global_position) * speed + kb_vel
		move_and_slide()
		_sprite_animator.update_animation_no_idle(velocity)

func take_damage(amount: float) -> void:
	health.take_damage(amount)

func die() -> void:
	_on_died()

func _on_died() -> void:
	_knockback.reset()
	# 屏幕震动
	var fx: EffectConfigData = GameConfig.effects
	EventBus.camera_shake_requested.emit(fx.camera_shake_enemy_kill_intensity, fx.camera_shake_enemy_kill_duration)
	StatsTracker.record_kill()
	EventBus.enemy_killed.emit(enemy_type, global_position, is_elite)
	AudioManager.play("enemy_die")
	_drop_exp_orbs()
	# TODO(#5): 敌人掉金币机制接入,届时应用 PlayerState.player_stats.get(Enums.Stat.COIN_DROP_BONUS_PERCENT, 0.0) 加成
	EffectsManager.spawn_enhanced_death(global_position, health.death_color)
	SceneFactory.release_enemy(self)

func _drop_exp_orbs() -> void:
	var pickup_layer: Node = SceneFactory.get_pickup_layer()
	if not pickup_layer:
		return

	var orb_count: int = randi_range(data.exp_drop_min, data.exp_drop_max)
	orb_count = int(orb_count * _elite_exp_mult)
	for i in orb_count:
		var orb = SceneFactory.create_exp_orb()
		orb.global_position = global_position + Vector2(randf_range(-EXP_SCATTER_RANGE, EXP_SCATTER_RANGE), randf_range(-EXP_SCATTER_RANGE, EXP_SCATTER_RANGE))
		pickup_layer.call_deferred("add_child", orb)

func apply_elite(hp_mult: float, damage_mult: float, scale_mult: float, exp_mult: float = 1.0) -> void:
	is_elite = true
	_elite_exp_mult = exp_mult
	health.max_hp *= hp_mult
	health.current_hp = health.max_hp
	_hitbox.damage *= damage_mult
	scale *= scale_mult
	add_to_group("elites")

func apply_knockback(dir: Vector2) -> void:
	_knockback.apply_knockback(dir)

func _flash_white() -> void:
	EffectsManager.flash_white(self)

func apply_slow(slow_percent: float, source_id: String = "") -> void:
	slow_handler.apply_slow(slow_percent, source_id)

func remove_slow(source_id: String = "") -> void:
	slow_handler.remove_slow(source_id)

func _on_hurtbox_hit(damage: float, knockback_dir: Vector2) -> void:
	AudioManager.play("hit", -6.0)
	# 猎杀标记：被标记的敌人受到双倍伤害
	if has_meta("hunt_marked") and get_meta("hunt_marked"):
		damage *= 2.0
	health.take_damage(damage)
	EffectsManager.sprite_shake(self, 4.0)
	if knockback_dir.length() > 0:
		_knockback.apply_knockback(knockback_dir.normalized())

func apply_root(duration: float, source: String = "") -> void:
	is_rooted = true
	_root_source = source
	_pre_root_speed = speed
	speed = 0.0
	velocity = Vector2.ZERO
	var timer: SceneTreeTimer = get_tree().create_timer(duration)
	timer.timeout.connect(remove_root)

func remove_root() -> void:
	if not is_rooted:
		return
	is_rooted = false
	_root_source = ""
	speed = _pre_root_speed
func _on_speed_changed(new_speed: float) -> void:
	if is_rooted:
		_pre_root_speed = new_speed  # 保存速度但不覆盖实际速度
		return
	speed = new_speed

func reset_for_pool() -> void:
	health.reset()
	_knockback.reset()
	slow_handler.clear_all()
	if is_rooted:
		remove_root()
	if is_in_group("elites"):
		remove_from_group("elites")
	is_elite = false
	_elite_exp_mult = 1.0
	scale = Vector2.ONE
	velocity = Vector2.ZERO
	if _sprite_animator._sprite:
		_sprite_animator._sprite.offset = Vector2.ZERO
		_sprite_animator._sprite.play("walk_down")
		_sprite_animator._current_anim = "walk_down"
	visible = true
	modulate = Color.WHITE
	_tower_target = null
	_target_refresh_timer = 0.0
