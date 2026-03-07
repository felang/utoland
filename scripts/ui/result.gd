extends Control

func _ready() -> void:
	if GameData.current_wave > 10:
		$VBoxContainer/TitleLabel.text = "胜利！"
	else:
		$VBoxContainer/TitleLabel.text = "失败"

	$VBoxContainer/WaveLabel.text = "存活波次: %d" % GameData.current_wave
	$VBoxContainer/RestartButton.pressed.connect(_on_restart)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit)

func _on_restart() -> void:
	GameData.reset()
	SceneManager.go_to(Enums.Scene.START_MENU)

func _on_quit() -> void:
	get_tree().quit()
