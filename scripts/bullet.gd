extends Area2D

var speed: float = 400.0
var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0

func _ready():
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	if body.is_in_group("enemies"):
		body.take_damage(damage)
		queue_free()
