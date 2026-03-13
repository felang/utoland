# MeleeProjectile — 玩家中心圆形瞬时 hitbox
class_name MeleeProjectile
extends Projectile

var melee_radius: float = 60.0
var _duration: float = 0.1

func _on_setup(_direction: Vector2) -> void:
	var shape := CircleShape2D.new()
	shape.radius = melee_radius
	var col: CollisionShape2D = hitbox.get_node("CollisionShape2D")
	col.shape = shape
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	var timer: SceneTreeTimer = get_tree().create_timer(_duration)
	timer.timeout.connect(queue_free)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		EffectsManager.spawn_hit_sparks(global_position)
