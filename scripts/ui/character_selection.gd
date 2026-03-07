extends Control

@onready var warrior_button: Button = $CharacterContainer/WarriorButton
@onready var ranger_button: Button = $CharacterContainer/RangerButton
@onready var tank_button: Button = $CharacterContainer/TankButton

func _ready() -> void:
	warrior_button.pressed.connect(_on_character_selected.bind("warrior"))
	ranger_button.pressed.connect(_on_character_selected.bind("ranger"))
	tank_button.pressed.connect(_on_character_selected.bind("tank"))

func _on_character_selected(character_id: String) -> void:
	GameData.current_character = character_id
	GameData.init_character(character_id)  # 立即初始化角色属性
	print("选择角色: ", character_id)
	SceneManager.go_to("weapon_select")
