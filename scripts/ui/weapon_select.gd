extends Control

func _ready():
	$VBoxContainer/RifleButton.pressed.connect(_on_rifle_selected)
	$VBoxContainer/ShotgunButton.pressed.connect(_on_shotgun_selected)

func _on_rifle_selected():
	GameData.selected_weapon = "rifle"
	start_game()

func _on_shotgun_selected():
	GameData.selected_weapon = "shotgun"
	start_game()

func start_game():
	get_tree().change_scene_to_file("res://scenes/ui/map_select.tscn")
