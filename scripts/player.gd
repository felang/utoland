extends CharacterBody2D

@export var speed: float = 200.0
@export var max_hp: float = 100.0
var current_hp: float = 100.0

func _physics_process(_delta):
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_axis("ui_left", "ui_right")
	input_vector.y = Input.get_axis("ui_up", "ui_down")
	
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
	
	velocity = input_vector * speed
	move_and_slide()

func take_damage(amount: float):
	current_hp -= amount
	if current_hp <= 0:
		die()

func die():
	print("Player died!")
	get_tree().reload_current_scene()
