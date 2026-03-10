extends CanvasLayer

## 暂停覆盖层 — ESC 切换暂停，显示暂停菜单

var _is_paused: bool = false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	_is_paused = not _is_paused
	get_tree().paused = _is_paused
	visible = _is_paused

func _build_ui() -> void:
	# 半透明背景
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 居中容器
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "已暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	# 继续按钮
	var resume_btn := Button.new()
	resume_btn.text = "继续"
	resume_btn.pressed.connect(_toggle_pause)
	resume_btn.custom_minimum_size = Vector2(120, 36)
	vbox.add_child(resume_btn)

	# 返回主菜单按钮
	var menu_btn := Button.new()
	menu_btn.text = "返回主菜单"
	menu_btn.pressed.connect(_on_return_to_menu)
	menu_btn.custom_minimum_size = Vector2(120, 36)
	vbox.add_child(menu_btn)

func _on_return_to_menu() -> void:
	get_tree().paused = false
	_is_paused = false
	SceneManager.go_to(Enums.Scene.START_MENU)
