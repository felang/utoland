extends Node

@export var wave_duration: float = 60.0
var time_remaining: float = 60.0

func _ready():
	add_to_group("wave_manager")

func _process(delta):
	time_remaining -= delta

	if time_remaining <= 0:
		victory()

func victory():
	print("Victory! You survived 60 seconds!")
	get_tree().reload_current_scene()
