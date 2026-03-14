extends Tower
class_name TowerSniper

# 仙人掌 — 远程狙击，优先攻击血量最高的敌人

var attack_damage: float = 35.0
var attack_rate: float = 2.5
var attack_range: float = 450.0

@onready var _detect_area: Area2D = $DetectArea
@onready var _shoot_timer: Timer = $ShootTimer

func _ready() -> void:
	tower_type = Enums.TowerId.CACTUS
	super._ready()
	_shoot_timer.timeout.connect(_shoot_highest_hp)

func _apply_level_stats() -> void:
	super._apply_level_stats()
	if not data:
		return
	var idx: int = current_level - 1
	attack_damage = data.damage_per_level[idx] * GameData.player_stats.get(Enums.Stat.TOWER_MULT, 1.0) * damage_mult
	attack_rate = data.fire_rate_per_level[idx] / maxf(speed_mult, 0.1)
	attack_range = data.attack_range_per_level[idx]
	if _detect_area and _detect_area.get_node_or_null("CollisionShape2D"):
		_detect_area.get_node("CollisionShape2D").shape.radius = attack_range
	if _shoot_timer and not _shoot_timer.is_stopped():
		_shoot_timer.wait_time = attack_rate
		_shoot_timer.start()

func _shoot_highest_hp() -> void:
	var target: Node2D = _find_highest_hp_target()
	if not target:
		return
	var dir: Vector2 = global_position.direction_to(target.global_position)
	var bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
	bullet.speed = 400.0
	get_parent().add_child(bullet)
	bullet.setup(attack_damage, 60.0, global_position, dir)

func _find_highest_hp_target() -> Node2D:
	var bodies: Array = _detect_area.get_overlapping_bodies()
	var best: Node2D = null
	var max_hp: float = 0.0
	for body in bodies:
		if body.is_in_group(Enums.Group.ENEMIES) and body.has_node("HealthComponent"):
			var hp: float = body.health.current_hp
			if hp > max_hp:
				max_hp = hp
				best = body
	return best

func _on_body_entered(_body: Node2D) -> void:
	if _shoot_timer.is_stopped():
		_shoot_timer.wait_time = attack_rate
		_shoot_timer.start()

func _on_body_exited(_body: Node2D) -> void:
	if _detect_area.get_overlapping_bodies().is_empty():
		_shoot_timer.stop()
