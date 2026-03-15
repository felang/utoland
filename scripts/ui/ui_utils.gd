class_name UIUtils

## 按钮 hover/press 缩放动效 + 音效
## pivot_offset 在每次交互时动态更新，因为 _ready 时 size 可能还是 Vector2.ZERO
static func setup_button_hover(button: Button) -> void:
	button.mouse_entered.connect(func() -> void:
		button.pivot_offset = button.size / 2
		_kill_hover_tween(button)
		var tw: Tween = button.create_tween()
		button.set_meta("_hover_tween", tw)
		tw.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)
		AudioManager.play("ui_hover", -10.0)
	)
	button.mouse_exited.connect(func() -> void:
		_kill_hover_tween(button)
		var tw: Tween = button.create_tween()
		button.set_meta("_hover_tween", tw)
		tw.tween_property(button, "scale", Vector2.ONE, 0.1)
	)
	button.button_down.connect(func() -> void:
		_kill_hover_tween(button)
		var tw: Tween = button.create_tween()
		button.set_meta("_hover_tween", tw)
		tw.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)
		AudioManager.play("ui_click")
	)
	button.button_up.connect(func() -> void:
		_kill_hover_tween(button)
		var tw: Tween = button.create_tween()
		button.set_meta("_hover_tween", tw)
		tw.tween_property(button, "scale", Vector2(1.05, 1.05), 0.05)
	)


static func _kill_hover_tween(button: Button) -> void:
	if button.has_meta("_hover_tween"):
		var old_tw: Tween = button.get_meta("_hover_tween")
		if old_tw and old_tw.is_valid():
			old_tw.kill()
