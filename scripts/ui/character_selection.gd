extends Control

# 角色选择界面 — 数据驱动，从 GameConfig.characters 生成卡片

@onready var _container: HBoxContainer = $CharacterContainer

func _ready() -> void:
	# 清除编辑器中的占位节点
	for child in _container.get_children():
		child.queue_free()

	# 从 GameConfig 动态生成角色卡片
	for character_id in GameConfig.characters:
		var char_data: CharacterData = GameConfig.characters[character_id]
		var weapon_data: WeaponData = GameConfig.weapons[char_data.default_weapon]
		_container.add_child(_create_card(character_id, char_data, weapon_data))


func _create_card(character_id: String, char_data: CharacterData, weapon_data: WeaponData) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(160, 180)

	var vbox := VBoxContainer.new()
	card.add_child(vbox)

	# 角色名称
	var name_label := Label.new()
	name_label.text = char_data.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# 属性信息
	var stats_label := Label.new()
	stats_label.text = "生命: %d\n速度: %d\n伤害: x%.1f" % [
		int(char_data.max_hp), int(char_data.speed), char_data.damage_mult
	]
	vbox.add_child(stats_label)

	# 武器名称
	var weapon_label := Label.new()
	weapon_label.text = "武器: " + weapon_data.display_name
	vbox.add_child(weapon_label)

	# 选择按钮
	var button := Button.new()
	button.text = "选择"
	button.pressed.connect(_on_character_selected.bind(character_id))
	vbox.add_child(button)

	return card


func _on_character_selected(character_id: String) -> void:
	var char_data: CharacterData = GameConfig.characters[character_id]
	GameData.current_character = character_id
	GameData.selected_weapon = char_data.default_weapon
	GameData.init_character(character_id)
	SceneManager.go_to(Enums.Scene.MAP_SELECT)
