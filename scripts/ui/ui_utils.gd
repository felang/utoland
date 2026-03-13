class_name UIUtils

# pivot_offset 在每次交互时动态更新，因为 _ready 时 size 可能还是 Vector2.ZERO
static func setup_button_hover(button: Button) -> void:
	button.mouse_entered.connect(func() -> void:
		button.pivot_offset = button.size / 2
		var tw: Tween = button.create_tween()
		tw.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)
	)
	button.mouse_exited.connect(func() -> void:
		var tw: Tween = button.create_tween()
		tw.tween_property(button, "scale", Vector2.ONE, 0.1)
	)
	button.button_down.connect(func() -> void:
		var tw: Tween = button.create_tween()
		tw.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)
	)
	button.button_up.connect(func() -> void:
		var tw: Tween = button.create_tween()
		tw.tween_property(button, "scale", Vector2(1.05, 1.05), 0.05)
	)
