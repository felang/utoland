extends Control

func _ready() -> void:
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	var err: int = get_tree().change_scene_to_file("res://scenes/ui/character_selection.tscn")
	if err != OK:
		push_error("场景切换失败: " + str(err))
