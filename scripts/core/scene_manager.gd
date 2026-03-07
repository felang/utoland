extends Node

const SCENES: Dictionary = {
	Enums.Scene.START_MENU:          "res://scenes/ui/start_menu.tscn",
	Enums.Scene.CHARACTER_SELECTION: "res://scenes/ui/character_selection.tscn",
	Enums.Scene.WEAPON_SELECT:       "res://scenes/ui/weapon_select.tscn",
	Enums.Scene.MAP_SELECT:          "res://scenes/ui/map_select.tscn",
	Enums.Scene.SHOP:                "res://scenes/ui/shop.tscn",
	Enums.Scene.RESULT:              "res://scenes/ui/result.tscn",
	Enums.Scene.PLACEMENT:           "res://scenes/levels/placement.tscn",
	Enums.Scene.MAIN:                "res://scenes/levels/main.tscn",
}

func go_to(scene_name: String) -> void:
	assert(SCENES.has(scene_name), "未知场景: " + scene_name)
	get_tree().change_scene_to_file(SCENES[scene_name])
