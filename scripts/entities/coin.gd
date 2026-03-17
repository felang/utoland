extends Area2D

const FORCE_ATTRACT_SPEED_MULT: float = 1.6  # 波次结束强制吸引时的速度倍率

@export var value: int = 1
@export var attract_speed: float = 250.0
@export var attract_range: float = 75.0

var player: Node2D = null
var is_attracted: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	player = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	add_to_group(Enums.Group.COINS)

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
		body.add_coins(value)
		StatsTracker.record_coins_earned(value)
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
	tween.tween_callback(queue_free)

func force_attract() -> void:
	is_attracted = true
	attract_speed = attract_speed * FORCE_ATTRACT_SPEED_MULT
