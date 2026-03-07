extends Control

# 武器选择界面 — 数据驱动，从 GameConfig.weapons 生成按钮

@onready var container: VBoxContainer = $VBoxContainer

func _ready() -> void:
	# 清除旧的硬编码按钮（保留 TitleLabel）
	for child in container.get_children():
		if child is Button:
			child.queue_free()

	# 从 GameConfig 动态生成武器按钮
	for weapon_id in GameConfig.weapons:
		var w: WeaponData = GameConfig.weapons[weapon_id]
		var button: Button = Button.new()
		button.text = w.display_name
		button.custom_minimum_size = GameConfig.UI_BUTTON_SIZE
		button.pressed.connect(_on_weapon_selected.bind(weapon_id))
		container.add_child(button)

func _on_weapon_selected(weapon_id: String) -> void:
	GameData.selected_weapon = weapon_id
	SceneManager.go_to(Enums.Scene.MAP_SELECT)
