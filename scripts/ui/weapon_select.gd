extends Control

# 武器选择界面 — 数据驱动，从 GameConfig.WEAPONS 生成按钮

@onready var container: VBoxContainer = $VBoxContainer

func _ready() -> void:
	# 清除旧的硬编码按钮（保留 TitleLabel）
	for child in container.get_children():
		if child is Button:
			child.queue_free()

	# 从 GameConfig 动态生成武器按钮
	for weapon_id in GameConfig.WEAPONS:
		var weapon_data: Dictionary = GameConfig.WEAPONS[weapon_id]
		var button: Button = Button.new()
		button.text = weapon_data["name"]
		button.custom_minimum_size = GameConfig.UI_BUTTON_SIZE
		button.pressed.connect(_on_weapon_selected.bind(weapon_id))
		container.add_child(button)

func _on_weapon_selected(weapon_id: String) -> void:
	GameData.selected_weapon = weapon_id
	get_tree().change_scene_to_file("res://scenes/ui/map_select.tscn")
