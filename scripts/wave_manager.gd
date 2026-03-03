extends Node

@export var wave_duration: float = 60.0
var time_remaining: float
var victory_triggered: bool = false

func _ready():
	time_remaining = wave_duration
	add_to_group("wave_manager")

func _process(delta):
	if victory_triggered:
		return
	time_remaining -= delta

	if time_remaining <= 0:
		victory_triggered = true
		victory()

func victory():
	print("Victory! You survived 60 seconds!")
	get_tree().reload_current_scene()
