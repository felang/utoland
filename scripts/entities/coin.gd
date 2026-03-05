extends Area2D

@export var value: int = 1
@export var attract_speed: float = 500.0
@export var attract_range: float = 150.0

var player: Node2D = null
var is_attracted: bool = false

func _ready():
	body_entered.connect(_on_body_entered)
	player = get_tree().get_first_node_in_group("player")
	add_to_group("coins")

func _process(delta):
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return

	if global_position.distance_to(player.global_position) < attract_range:
		is_attracted = true

	if is_attracted:
		var direction = global_position.direction_to(player.global_position)
		global_position += direction * attract_speed * delta

func _on_body_entered(body):
	if body.is_in_group("player"):
		body.add_coins(value)
		queue_free()

func force_attract():
	is_attracted = true
	attract_speed = 800.0
