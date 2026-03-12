extends Node

const SCENES: Dictionary = {
	"start_menu":          "res://scenes/ui/start_menu.tscn",
	"character_selection": "res://scenes/ui/character_selection.tscn",
	"map_select":          "res://scenes/ui/map_select.tscn",
	"result":              "res://scenes/ui/result.tscn",
	"placement":           "res://scenes/levels/placement.tscn",
	"main":                "res://scenes/levels/main.tscn",
}

func go_to(scene_name: String) -> void:
	assert(SCENES.has(scene_name), "未知场景: " + scene_name)
	get_tree().change_scene_to_file(SCENES[scene_name])
