# RocketProjectile — 直线飞行，碰撞后范围爆炸
class_name RocketProjectile
extends Projectile

var speed: float = 300.0
var lifetime: float = 3.0
var explosion_radius: float = 80.0
var _direction: Vector2 = Vector2.RIGHT
var _elapsed: float = 0.0

func _on_setup(direction: Vector2) -> void:
	_direction = direction
	_elapsed = 0.0
	hitbox.area_entered.connect(_on_hitbox_area_entered)

func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta
	_elapsed += delta
	if _elapsed >= lifetime:
		_explode()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		_explode()

func _explode() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	for enemy in enemies:
		if enemy is Node2D:
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist <= explosion_radius:
				if enemy.has_method("take_damage"):
					enemy.take_damage(hitbox.damage)
	EffectsManager.spawn_death_effect(global_position, Color.ORANGE)
	queue_free()
