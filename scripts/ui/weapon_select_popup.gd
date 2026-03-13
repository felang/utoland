extends CanvasLayer
## 武器选择弹窗 — 波次结束后 3 选 1

signal weapon_selected(weapon_id: String)
signal skipped

var _generator := WeaponUpgradeGenerator.new()
var _options: Array[Dictionary] = []

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_options() -> void:
	_options = _generator.generate_options()
	if _options.is_empty():
		skipped.emit()
		queue_free()
		return
	_build_ui()
	get_tree().paused = true

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := Label.new()
	title.text = "选择武器升级"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	for i in range(_options.size()):
		var card := _create_card(i)
		hbox.add_child(card)

func _create_card(index: int) -> PanelContainer:
	var opt: Dictionary = _options[index]
	var weapon_id: String = opt["weapon_id"]
	var target_level: int = opt["target_level"]
	var is_new: bool = opt["is_new"]
	var wd: WeaponData = GameConfig.weapons[weapon_id]

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 200)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var card_vbox := VBoxContainer.new()
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(card_vbox)

	var name_label := Label.new()
	name_label.text = wd.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	card_vbox.add_child(name_label)

	var level_label := Label.new()
	if is_new:
		level_label.text = "新武器! Lv1"
		level_label.add_theme_color_override("font_color", Color("#80ff80"))
	else:
		level_label.text = "Lv%d → Lv%d" % [target_level - 1, target_level]
		level_label.add_theme_color_override("font_color", Color("#ffd040"))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 13)
	card_vbox.add_child(level_label)

	var stats_label := Label.new()
	stats_label.text = _get_stats_text(wd, target_level, is_new)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", Color("#c0c0c0"))
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(stats_label)

	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_option_selected(index)
	)
	return card

func _get_stats_text(wd: WeaponData, target_level: int, is_new: bool) -> String:
	var idx: int = target_level - 1
	if is_new:
		return "伤害: %.0f\n射速: %.2f\n射程: %.0f" % [
			wd.damage_per_level[0], wd.fire_rate_per_level[0], wd.weapon_range_per_level[0]
		]
	else:
		var prev_idx: int = idx - 1
		return "伤害: %.0f → %.0f\n射速: %.2f → %.2f\n射程: %.0f → %.0f" % [
			wd.damage_per_level[prev_idx], wd.damage_per_level[idx],
			wd.fire_rate_per_level[prev_idx], wd.fire_rate_per_level[idx],
			wd.weapon_range_per_level[prev_idx], wd.weapon_range_per_level[idx],
		]

func _on_option_selected(index: int) -> void:
	var opt: Dictionary = _options[index]
	GameData.upgrade_weapon(opt["weapon_id"])
	get_tree().paused = false
	weapon_selected.emit(opt["weapon_id"])
	queue_free()
