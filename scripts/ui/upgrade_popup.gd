extends CanvasLayer
## 波次结束升级弹窗 — 多轮 3 选 1（武器+塔混合池）

signal upgrade_selected(type: String, id: String)
signal all_upgrades_completed
signal skipped

const CARD_WIDTH: int = 180
const CARD_HEIGHT: int = 200
const CARD_GAP: int = 16

var _total_rounds: int = 0
var _current_round: int = 0
var _refresh_count: int = 0
var _options: Array[Dictionary] = []
var _generator: UpgradeGenerator = UpgradeGenerator.new()

# UI 节点引用
var _title_label: Label
var _coins_label: Label
var _cards_container: HBoxContainer
var _refresh_button: Button
var _container: VBoxContainer

func show_upgrades(count: int) -> void:
	_total_rounds = count
	_current_round = 0
	if _total_rounds <= 0:
		skipped.emit()
		queue_free()
		return
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build_ui()
	_start_round()

func _start_round() -> void:
	_refresh_count = 0
	_options = _generator.generate_options()
	if _options.size() == 0:
		_finish()
		return
	_update_display()

func _update_display() -> void:
	_title_label.text = "选择升级 (%d/%d)" % [_current_round + 1, _total_rounds]
	_coins_label.text = "金币: %d" % GameData.coins
	_rebuild_cards()
	_update_refresh_button()

func _rebuild_cards() -> void:
	for child in _cards_container.get_children():
		child.queue_free()
	for i in _options.size():
		var card: PanelContainer = _create_card(i)
		_cards_container.add_child(card)

func _create_card(index: int) -> PanelContainer:
	var opt: Dictionary = _options[index]
	var is_weapon: bool = opt["type"] == "weapon"

	var border_color: Color = Color("#4fc3f7") if is_weapon else Color("#66bb6a")
	var bg_color: Color = Color("#1a1a3a") if is_weapon else Color("#1a2a1a")
	var type_label_text: String = "⚔ 武器" if is_weapon else "🏗 塔"
	var type_label_color: Color = border_color

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# 类型标签
	var type_lbl := Label.new()
	type_lbl.text = type_label_text
	type_lbl.add_theme_font_size_override("font_size", 11)
	type_lbl.add_theme_color_override("font_color", type_label_color)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_lbl)

	# 名称
	var name_lbl := Label.new()
	name_lbl.text = _get_display_name(opt)
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# 等级信息
	var level_lbl := Label.new()
	if opt["is_new"]:
		var new_text: String = "新武器! Lv1" if is_weapon else "新塔! Lv1"
		level_lbl.text = new_text
		level_lbl.add_theme_color_override("font_color", Color("#4caf50"))
	else:
		level_lbl.text = "Lv%d → Lv%d" % [opt["current_level"], opt["target_level"]]
		level_lbl.add_theme_color_override("font_color", Color("#ffd700"))
	level_lbl.add_theme_font_size_override("font_size", 12)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_lbl)

	# 属性预览
	var stats_lbl := Label.new()
	stats_lbl.text = _get_stats_text(opt)
	stats_lbl.add_theme_font_size_override("font_size", 11)
	stats_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_lbl)

	# 点击事件
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_option_selected(index)
	)

	return panel

func _get_display_name(opt: Dictionary) -> String:
	if opt["type"] == "weapon":
		var wd: WeaponData = GameConfig.weapons[opt["id"]]
		return wd.display_name
	else:
		var td: TowerData = GameConfig.towers[opt["id"]]
		return td.display_name

func _get_stats_text(opt: Dictionary) -> String:
	var level: int = opt["target_level"]
	var idx: int = level - 1
	if opt["type"] == "weapon":
		var wd: WeaponData = GameConfig.weapons[opt["id"]]
		var lines: Array[String] = []
		if wd.damage_per_level.size() > idx:
			lines.append("伤害: %d" % int(wd.damage_per_level[idx]))
		if wd.fire_rate_per_level.size() > idx:
			lines.append("射速: %.1f" % wd.fire_rate_per_level[idx])
		if wd.weapon_range_per_level.size() > idx:
			lines.append("范围: %d" % int(wd.weapon_range_per_level[idx]))
		return "\n".join(lines)
	else:
		var td: TowerData = GameConfig.towers[opt["id"]]
		var lines: Array[String] = []
		if td.damage_per_level.size() > idx and td.damage_per_level[idx] > 0:
			lines.append("伤害: %d" % int(td.damage_per_level[idx]))
		if td.fire_rate_per_level.size() > idx and td.fire_rate_per_level[idx] > 0:
			lines.append("射速: %.1f" % td.fire_rate_per_level[idx])
		if td.attack_range_per_level.size() > idx and td.attack_range_per_level[idx] > 0:
			lines.append("范围: %d" % int(td.attack_range_per_level[idx]))
		if td.slow_ratio_per_level.size() > idx and td.slow_ratio_per_level[idx] > 0:
			lines.append("减速: %d%%" % int(td.slow_ratio_per_level[idx] * 100))
		if td.hp_per_level.size() > idx and td.hp_per_level[idx] > 0:
			lines.append("HP: %d" % int(td.hp_per_level[idx]))
		return "\n".join(lines)

func _on_option_selected(index: int) -> void:
	var opt: Dictionary = _options[index]
	if opt["type"] == "weapon":
		GameData.upgrade_weapon(opt["id"])
	elif opt["type"] == "tower":
		GameData.upgrade_tower(opt["id"])
	upgrade_selected.emit(opt["type"], opt["id"])
	GameData.pending_upgrades -= 1
	_current_round += 1
	if _current_round < _total_rounds:
		_start_round()
	else:
		_finish()

func _on_refresh_pressed() -> void:
	var cost: int = _generator.get_refresh_cost(_refresh_count)
	if cost > 0 and GameData.coins < cost:
		return
	if cost > 0:
		GameData.coins -= cost
	_refresh_count += 1
	_options = _generator.generate_options(_options)
	if _options.size() == 0:
		_finish()
		return
	_update_display()

func _finish() -> void:
	get_tree().paused = false
	all_upgrades_completed.emit()
	queue_free()

func _update_refresh_button() -> void:
	var cost: int = _generator.get_refresh_cost(_refresh_count)
	if cost == 0:
		_refresh_button.text = "🔄 刷新 (免费)"
		_refresh_button.disabled = false
	else:
		_refresh_button.text = "🔄 刷新 (%d金币)" % cost
		_refresh_button.disabled = GameData.coins < cost

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	_container = VBoxContainer.new()
	_container.set_anchors_preset(Control.PRESET_CENTER)
	_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_container.add_theme_constant_override("separation", 12)
	overlay.add_child(_container)

	_container.set_anchors_preset(Control.PRESET_CENTER)
	_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_container.grow_vertical = Control.GROW_DIRECTION_BOTH

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_container.add_child(_title_label)

	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 14)
	_coins_label.add_theme_color_override("font_color", Color("#ffd700"))
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_container.add_child(_coins_label)

	_cards_container = HBoxContainer.new()
	_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_container.add_theme_constant_override("separation", CARD_GAP)
	_container.add_child(_cards_container)

	_refresh_button = Button.new()
	_refresh_button.add_theme_font_size_override("font_size", 14)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_child(_refresh_button)
	_container.add_child(btn_container)
