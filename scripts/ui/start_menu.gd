extends Control

## 开始菜单 — 主标题、开始/设置/退出按钮


func _ready() -> void:
	# 背景色
	$Background.color = UIConstants.COLOR_BG_PRIMARY

	# 标题样式
	var vbox := $CenterContainer/VBoxContainer
	vbox.get_node("TitleLabel").add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_TITLE)
	vbox.get_node("TitleLabel").add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)
	vbox.get_node("SubtitleLabel").add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	vbox.get_node("SubtitleLabel").add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)

	# 版本标签样式
	$VersionLabel.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	$VersionLabel.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)

	# 按钮字号与 hover 动效
	for btn_name in ["StartButton", "SettingsButton", "QuitButton"]:
		var btn: Button = vbox.get_node(btn_name)
		btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
		UIUtils.setup_button_hover(btn)

	# 按钮信号
	vbox.get_node("StartButton").pressed.connect(_on_start_pressed)
	vbox.get_node("QuitButton").pressed.connect(func() -> void: get_tree().quit())
	vbox.get_node("SettingsButton").disabled = true  # 占位，后续实现


func _on_start_pressed() -> void:
	SceneManager.go_to(Enums.Scene.CHARACTER_SELECTION)
