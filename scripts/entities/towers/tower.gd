class_name Tower
extends StaticBody2D

# 由 SceneFactory 注入的 Resource 数据
var data: TowerData = null
var tower_type: String = ""
# 由 SceneFactory 在实例化后注入的等级
var current_level: int = 1

# Buff 系统
var damage_mult: float = 1.0
var speed_mult: float = 1.0
var _buff_sources: Dictionary = {}  # {source_id: {dmg: float, spd: float}}

# 攻击组件引用（RangedAttackComponent 或 MeleeAttackComponent）
var _attack_component: Node = null

# 动画节点
@onready var visual: AnimatedSprite2D = $Visual
@onready var health: HealthComponent = $HealthComponent

const LV2_GLOW_PATH: String = "res://assets/towers/shared/lv2_glow.png"
const LV3_GLOW_PATH: String = "res://assets/towers/shared/lv3_glow.png"

func _ready() -> void:
	var idx: int = current_level - 1
	health.initialize(data.hp_per_level[idx])
	health.died.connect(_on_died)

	# 播放待机动画
	if visual and visual.sprite_frames and visual.sprite_frames.has_animation("idle"):
		visual.play("idle")

	# 自动检测攻击组件
	_attack_component = get_node_or_null("RangedAttackComponent")
	if not _attack_component:
		_attack_component = get_node_or_null("MeleeAttackComponent")

	if _attack_component and data.attack_config:
		_attack_component.attack_config = data.attack_config
		if _attack_component is RangedAttackComponent:
			_attack_component.projectile_data = data.projectile_data
			_attack_component.attack_executed.connect(_on_attack_executed)
			_attack_component.projectile_spawned.connect(_on_projectile_spawned)
			# 为冰花等减速投射物注入 SlowOnHitComponent 参数
			if data.slow_ratio_per_level.size() > 0:
				_attack_component.on_projectile_created = func(proj: Node2D) -> void:
					var slow_comp: Node = proj.get_node_or_null("SlowOnHitComponent")
					if slow_comp:
						slow_comp.slow_ratio = data.slow_ratio_per_level[idx]
						slow_comp.slow_duration = data.slow_duration_per_level[idx]
		_attack_component.set_level(current_level)
		# 应用全局塔伤害加成
		var tower_mult: float = PlayerState.player_stats.get(Enums.Stat.TOWER_MULT, 1.0)
		_buff_sources["_base_tower_mult"] = {dmg = tower_mult, spd = 1.0}
		_recalc_buffs()

	# 自动检测生成组件（向日葵）
	var generator: Node = get_node_or_null("GeneratorComponent")
	if generator and data.generator_config:
		generator.config = data.generator_config
		generator.set_level(current_level)
		generator.generated.connect(_on_generated)

	# 自动检测受击组件（Hurtbox）
	var hurtbox := get_node_or_null("Hurtbox") as Hurtbox
	if hurtbox:
		hurtbox.hit_taken.connect(_on_hurtbox_hit_taken)

	_setup_level_glow()
	add_to_group(Enums.Group.TOWERS)

func _process(delta: float) -> void:
	if _attack_component and _attack_component.has_method("tick"):
		_attack_component.tick(delta)

# --- 公共方法 ---

func take_damage(amount: float, attacker: Node2D = null) -> void:
	health.take_damage(amount, attacker)

func apply_buff(dmg_mult: float, spd_mult: float, source_id: String) -> void:
	_buff_sources[source_id] = {dmg = dmg_mult, spd = spd_mult}
	_recalc_buffs()

func remove_buff(source_id: String) -> void:
	_buff_sources.erase(source_id)
	_recalc_buffs()

func play_attack_animation() -> void:
	if not visual or not visual.sprite_frames:
		return
	if not visual.sprite_frames.has_animation("attack"):
		return
	visual.play("attack")
	if not visual.animation_finished.is_connected(_on_attack_animation_finished):
		visual.animation_finished.connect(_on_attack_animation_finished, CONNECT_ONE_SHOT)

# --- 私有方法 ---

func _recalc_buffs() -> void:
	damage_mult = 1.0
	speed_mult = 1.0
	for entry in _buff_sources.values():
		damage_mult *= entry.dmg
		speed_mult *= entry.spd
	if _attack_component:
		_attack_component.damage_multiplier = damage_mult
		_attack_component.speed_multiplier = speed_mult

func _on_attack_executed(_target: Node2D, _proj: Node2D = null) -> void:
	play_attack_animation()

func _on_projectile_spawned(proj: Node2D) -> void:
	SceneFactory.get_projectile_layer().add_child(proj)

func _on_generated(amount: int, pos: Vector2) -> void:
	EventBus.coins_generated.emit(amount, pos)
	play_attack_animation()

func _on_hurtbox_hit_taken(damage: float, _knockback: Vector2) -> void:
	health.take_damage(damage)

func _on_died() -> void:
	EventBus.tower_destroyed.emit(tower_type, global_position)
	queue_free()

func _on_attack_animation_finished() -> void:
	if visual and visual.sprite_frames and visual.sprite_frames.has_animation("idle"):
		visual.play("idle")

func _setup_level_glow() -> void:
	if current_level < 2:
		return
	var glow_path: String = LV2_GLOW_PATH if current_level == 2 else LV3_GLOW_PATH
	if not ResourceLoader.exists(glow_path):
		return
	var glow := Sprite2D.new()
	glow.texture = load(glow_path)
	glow.z_index = -1
	add_child(glow)
