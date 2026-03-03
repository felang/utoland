extends Control

func _ready():
	if GameData.current_wave >= 10:
		$VBoxContainer/TitleLabel.text = "胜利！"
	else:
		$VBoxContainer/TitleLabel.text = "失败"

	$VBoxContainer/WaveLabel.text = "存活波次: %d" % GameData.current_wave
	$VBoxContainer/RestartButton.pressed.connect(_on_restart)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit)

func _on_restart():
	GameData.reset()
	get_tree().change_scene_to_file("res://scenes/ui/start_menu.tscn")

func _on_quit():
	get_tree().quit()
