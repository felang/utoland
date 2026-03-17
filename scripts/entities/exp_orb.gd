extends Area2D

const FORCE_ATTRACT_SPEED_MULT: float = 1.6

@export var value: int = 1
@export var attract_speed: float = 200.0
@export var attract_range: float = 30.0

var player: Node2D = null
var is_attracted: bool = false
var _is_pooled: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	player = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	add_to_group(Enums.Group.EXP_ORBS)

func _process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
		if not player:
			return

	if global_position.distance_to(player.global_position) < attract_range:
		is_attracted = true

	if is_attracted:
		var direction: Vector2 = global_position.direction_to(player.global_position)
		global_position += direction * attract_speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(Enums.Group.PLAYER):
		body.add_exp(value)
		AudioManager.play("coin_pickup")
		_play_pickup_effect()

func _play_pickup_effect() -> void:
	set_deferred("monitoring", false)
	var shrink_dur: float = GameConfig.effects.coin_pickup_shrink_duration
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), shrink_dur)
	tween.tween_property(self, "modulate:a", 0.0, shrink_dur)
	tween.set_parallel(false)
	tween.tween_callback(func(): SceneFactory.release_exp_orb(self))

func reset_for_pool() -> void:
	value = 1
	is_attracted = false
	attract_speed = 200.0
	attract_range = 30.0
	player = null
	visible = true
	modulate.a = 1.0
	scale = Vector2.ONE
	set_deferred("monitoring", true)

func force_attract() -> void:
	is_attracted = true
	attract_speed = attract_speed * FORCE_ATTRACT_SPEED_MULT
