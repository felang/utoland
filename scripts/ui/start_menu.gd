extends Control

func _ready() -> void:
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	SceneManager.go_to("character_selection")
