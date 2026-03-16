extends Tower

@export var attack_range: float = 300.0
@export var attack_damage: float = 10.0
@export var attack_rate: float = 1.0

var slow_on_hit: float = 0.0
var slow_duration: float = 0.0

@onready var detect_area: Area2D = $DetectArea
@onready var shoot_timer: Timer = $ShootTimer

func _ready() -> void:
	super._ready()
	shoot_timer.wait_time = attack_rate
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	shoot_timer.start()

func _apply_level_stats() -> void:
	super._apply_level_stats()
	var idx: int = current_level - 1
	attack_damage = data.damage_per_level[idx] * GameData.player_stats[Enums.Stat.TOWER_MULT]
	attack_rate = data.fire_rate_per_level[idx]
	attack_range = data.attack_range_per_level[idx]
	# 更新射击间隔
	if is_instance_valid(shoot_timer):
		shoot_timer.wait_time = attack_rate
	# 减速弹道（仅冰花塔有这些字段）
	if data.slow_ratio_per_level.size() > 0:
		slow_on_hit = data.slow_ratio_per_level[idx]
	if data.slow_duration_per_level.size() > 0:
		slow_duration = data.slow_duration_per_level[idx]

func _on_shoot_timer_timeout() -> void:
	_shoot_nearest_enemy()

func _shoot_nearest_enemy() -> void:
	var enemies: Array[Node2D] = detect_area.get_overlapping_bodies()
	var closest: Node2D = null
	var min_dist: float = attack_range

	for enemy: Node2D in enemies:
		if enemy.is_in_group(Enums.Group.ENEMIES):
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy

	if closest:
		var bullet: ProjectileBase = SceneFactory.create_bullet_projectile()
		var direction: Vector2 = global_position.direction_to(closest.global_position)
		# 弹道精灵（附加到 bullet，跟随方向旋转）+ 禁用拖尾
		if data.projectile_sprite_path != "" and ResourceLoader.exists(data.projectile_sprite_path):
			var proj_sprite: Sprite2D = Sprite2D.new()
			proj_sprite.texture = load(data.projectile_sprite_path)
			proj_sprite.rotation = direction.angle()
			bullet.add_child(proj_sprite)
			bullet.show_trail = false
		if slow_on_hit > 0.0:
			bullet.slow_on_hit = slow_on_hit
			bullet.slow_duration = slow_duration
		get_parent().add_child(bullet)
		bullet.setup_legacy(attack_damage, 0.0, global_position, direction)
		# 攻击动画
		play_attack_animation()
