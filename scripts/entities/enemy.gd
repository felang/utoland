extends CharacterBody2D

enum State { CHASE_PLAYER, ATTACK_TOWER }

const COIN_SCATTER_RANGE: float = 20.0  # 金币掉落散布范围（像素）

# 由 SceneFactory 注入的 Resource 数据
var data: EnemyData = null

# 敌人类型（由 SceneFactory 设置）
var enemy_type: String = "normal"
# 精英怪标识（由 SceneFactory 或生成逻辑设置）
var is_elite: bool = false
var _elite_coin_mult: float = 1.0

@export var tower_attack_rate: float = 1.0

var speed: float
var tower_attack_damage: float
var current_state: int = State.CHASE_PLAYER
var target_tower: Node2D = null
var attack_timer: float = 0.0
var player: Node2D = null

# Root（定身）系统
var is_rooted: bool = false
var _pre_root_speed: float = 0.0
var _root_source: String = ""  # 定身来源标记

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
	tower_attack_damage = data.damage
	slow_handler.initialize(data.speed)

	add_to_group(Enums.Group.ENEMIES)
	player = get_tree().get_first_node_in_group(Enums.Group.PLAYER)

	# 连接组件信号
	health.died.connect(_on_died)
	health.died_with_overkill.connect(_on_died_with_overkill)
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
	attack_timer -= delta

	match current_state:
		State.CHASE_PLAYER:
			_chase_player()
		State.ATTACK_TOWER:
			_attack_tower(delta)

func _chase_player() -> void:
	if is_rooted:
		return
	if player and is_instance_valid(player):
		velocity = position.direction_to(player.global_position) * speed
		move_and_slide()
		_sprite_animator.update_animation_no_idle(velocity)

		for i in get_slide_collision_count():
			var collision: KinematicCollision2D = get_slide_collision(i)
			var collider: Object = collision.get_collider()
			if collider and collider.is_in_group(Enums.Group.TOWERS):
				current_state = State.ATTACK_TOWER
				target_tower = collider
				velocity = Vector2.ZERO

func _attack_tower(_delta: float) -> void:
	if not is_instance_valid(target_tower):
		current_state = State.CHASE_PLAYER
		return

	if attack_timer <= 0:
		target_tower.take_damage(tower_attack_damage, self)
		attack_timer = tower_attack_rate

func take_damage(amount: float) -> void:
	# Control 3: 脆弱标记 — 被控制的敌人受到额外伤害
	amount = _apply_vulnerable_mult(amount)
	# 极寒囚笼：frozen_cage 定身中受到 +30% 伤害
	if _root_source == "frozen_cage" and GameData.active_pair_synergies.has("frozen_cage"):
		amount *= 1.3
	health.take_damage(amount)

func die() -> void:
	_on_died()

func _on_died() -> void:
	_knockback.kill_tween()
	# 屏幕震动
	var fx: EffectConfigData = GameConfig.effects
	EventBus.camera_shake_requested.emit(fx.camera_shake_enemy_kill_intensity, fx.camera_shake_enemy_kill_duration)
	GameData.record_kill()
	EventBus.enemy_killed.emit(enemy_type, global_position, is_elite)
	AudioManager.play("enemy_die")
	_drop_coins()
	EffectsManager.spawn_enhanced_death(global_position, health.death_color)
	queue_free()

func _drop_coins() -> void:
	var parent: Node = get_parent()
	if not parent:
		return

	var coin_count: int = randi_range(data.coin_drop_min, data.coin_drop_max)
	coin_count = int(coin_count * _elite_coin_mult)
	for i in coin_count:
		var coin = SceneFactory.create_coin()
		coin.global_position = global_position + Vector2(randf_range(-COIN_SCATTER_RANGE, COIN_SCATTER_RANGE), randf_range(-COIN_SCATTER_RANGE, COIN_SCATTER_RANGE))
		parent.call_deferred("add_child", coin)

func apply_elite(hp_mult: float, damage_mult: float, coin_mult: float, scale_mult: float) -> void:
	is_elite = true
	_elite_coin_mult = coin_mult
	health.max_hp *= hp_mult
	health.current_hp = health.max_hp
	tower_attack_damage *= damage_mult
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
	health.take_damage(damage)
	EffectsManager.sprite_shake(self, 2.0)
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
	var was_chain_freeze: bool = (_root_source == "chain_freeze")
	is_rooted = false
	_root_source = ""
	speed = _pre_root_speed
	# Control 5: 定身到期时也可触发连锁控制（但连锁控制产生的定身不再触发）
	if not was_chain_freeze:
		_try_chain_freeze_from_root()

func _on_speed_changed(new_speed: float) -> void:
	if is_rooted:
		_pre_root_speed = new_speed  # 保存速度但不覆盖实际速度
		return
	speed = new_speed


## Control 5: 从定身到期触发连锁控制
func _try_chain_freeze_from_root() -> void:
	var processor: SynergyEffectProcessor = _get_synergy_processor()
	if processor and processor.should_chain_freeze():
		apply_root(1.0, "chain_freeze")


## Assault 5: 溢杀 — 转发给处理器
func _on_died_with_overkill(overkill_damage: float, death_position: Vector2) -> void:
	var processor: SynergyEffectProcessor = _get_synergy_processor()
	if processor:
		processor.handle_overkill(overkill_damage, death_position)


## Control 3: 脆弱标记伤害加成
func _apply_vulnerable_mult(amount: float) -> float:
	var processor: SynergyEffectProcessor = _get_synergy_processor()
	if processor:
		return amount * processor.get_vulnerable_mult(self)
	return amount


## 获取羁绊效果处理器
func _get_synergy_processor() -> SynergyEffectProcessor:
	if not is_inside_tree():
		return null
	var processors: Array[Node] = get_tree().get_nodes_in_group("synergy_processor")
	if processors.size() > 0:
		return processors[0] as SynergyEffectProcessor
	# 回退：从场景树查找
	var root: Node = get_tree().current_scene
	if root:
		return root.get_node_or_null("SynergyEffectProcessor") as SynergyEffectProcessor
	return null
