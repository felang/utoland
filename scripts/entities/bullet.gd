extends Area2D

var speed: float = 400.0
var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var lifetime: float = 5.0  # 5秒后自动销毁
var elapsed: float = 0.0

func _ready():
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	global_position += direction * speed * delta
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
