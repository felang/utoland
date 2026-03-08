extends Control
## 角色选择界面 — 数据驱动，从 GameConfig.characters 生成卡片

const CARD_SCENE = preload("res://scenes/ui/character_card.tscn")

@onready var _container: HBoxContainer = $VBoxContainer/CardContainer
@onready var _desc_label: Label = $VBoxContainer/DescPanel/DescLabel
@onready var _back_button: Button = $VBoxContainer/BackButton

var _cards: Array = []


func _ready() -> void:
	# 背景与标题样式
	$Background.color = UIConstants.COLOR_BG_PRIMARY
	$VBoxContainer/TitleLabel.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_TITLE)
	$VBoxContainer/TitleLabel.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)

	# 描述面板样式
	_desc_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	_desc_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
	$VBoxContainer/DescPanel.add_theme_stylebox_override("panel", UIConstants.create_panel_stylebox())

	# 返回按钮
	_back_button.pressed.connect(func(): SceneManager.go_to(Enums.Scene.START_MENU))
	_back_button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)

	# 清除并生成卡片
	for child in _container.get_children():
		child.queue_free()
	_cards.clear()
	for character_id in GameConfig.characters:
		var char_data: CharacterData = GameConfig.characters[character_id]
		var weapon_data: WeaponData = GameConfig.weapons[char_data.default_weapon]
		var card = CARD_SCENE.instantiate()
		_container.add_child(card)
		card.setup(character_id, char_data, weapon_data)
		card.selected.connect(_on_character_selected)
		card.mouse_entered.connect(_on_card_hovered.bind(character_id))
		_cards.append(card)


func _on_card_hovered(character_id: String) -> void:
	var char_data: CharacterData = GameConfig.characters[character_id]
	if char_data.passive_description != "":
		_desc_label.text = char_data.passive_description
	else:
		_desc_label.text = char_data.display_name


func _on_character_selected(character_id: String) -> void:
	for card in _cards:
		card.set_selected(card._character_id == character_id)
	var char_data: CharacterData = GameConfig.characters[character_id]
	GameData.current_character = character_id
	GameData.selected_weapon = char_data.default_weapon
	GameData.init_character(character_id)
	SceneManager.go_to(Enums.Scene.MAP_SELECT)
