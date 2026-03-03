extends StaticBody2D

@export var max_hp: float = 300.0
var current_hp: float = 300.0

func _ready():
	add_to_group("towers")

func take_damage(amount: float):
	current_hp -= amount
	if current_hp <= 0:
		die()

func die():
	queue_free()
