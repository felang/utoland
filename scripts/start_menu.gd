extends Control

func _ready():
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)

func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/weapon_select.tscn")
