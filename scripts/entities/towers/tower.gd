extends StaticBody2D
class_name Tower

# 由 SceneFactory 注入的 Resource 数据
var data: TowerData = null
var tower_type: String = ""
# 由 SceneFactory 在实例化后注入的等级
var current_level: int = 1

# Buff 系统
var damage_mult: float = 1.0
var speed_mult: float = 1.0
var _buff_sources: Dictionary = {}  # {source_id: {dmg: float, spd: float}}

# 动画节点 — 使用 get_node_or_null 安全引用
var visual: AnimatedSprite2D = null

# 等级装饰
var _level_glow: Sprite2D = null

const LV2_GLOW_PATH: String = "res://assets/towers/shared/lv2_glow.png"
const LV3_GLOW_PATH: String = "res://assets/towers/shared/lv3_glow.png"

@onready var health: HealthComponent = $HealthComponent

func _ready() -> void:
	visual = get_node_or_null("Visual") as AnimatedSprite2D
	_apply_level_stats()
	_setup_level_glow()
	health.death_color = Color.GREEN
	health.died.connect(_on_died)
	add_to_group(Enums.Group.TOWERS)
	# 播放待机动画
	if visual and visual.sprite_frames and visual.sprite_frames.has_animation("idle"):
		visual.play("idle")

func _apply_level_stats() -> void:
	var idx: int = current_level - 1
	health.initialize(data.hp_per_level[idx])

func take_damage(amount: float, attacker: Node2D = null) -> void:
	health.take_damage(amount, attacker)

func apply_buff(dmg_mult: float, spd_mult: float, source_id: String) -> void:
	_buff_sources[source_id] = {"dmg": dmg_mult, "spd": spd_mult}
	_recalc_buffs()

func remove_buff(source_id: String) -> void:
	_buff_sources.erase(source_id)
	_recalc_buffs()

func _recalc_buffs() -> void:
	damage_mult = 1.0
	speed_mult = 1.0
	for data_entry in _buff_sources.values():
		damage_mult *= data_entry["dmg"]
		speed_mult *= data_entry["spd"]

func _on_died() -> void:
	EventBus.tower_destroyed.emit(tower_type, global_position)
	queue_free()

func _setup_level_glow() -> void:
	if current_level < 2:
		return
	var glow_path: String = LV2_GLOW_PATH if current_level == 2 else LV3_GLOW_PATH
	if ResourceLoader.exists(glow_path):
		_level_glow = Sprite2D.new()
		_level_glow.texture = load(glow_path)
		_level_glow.z_index = -1
		add_child(_level_glow)

func play_attack_animation() -> void:
	if not visual or not visual.sprite_frames:
		return
	if not visual.sprite_frames.has_animation("attack"):
		return
	visual.play("attack")
	if not visual.animation_finished.is_connected(_on_attack_animation_finished):
		visual.animation_finished.connect(_on_attack_animation_finished, CONNECT_ONE_SHOT)

func _on_attack_animation_finished() -> void:
	if visual and visual.sprite_frames and visual.sprite_frames.has_animation("idle"):
		visual.play("idle")
