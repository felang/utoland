extends Control

func _ready() -> void:
	$Background.color = Color(0, 0, 0, 0.85)
	var vbox := $CenterContainer/VBoxContainer
	var total_waves := GameConfig.waves.size()
	var is_victory := GameData.current_wave > total_waves

	# 标题
	var title: Label = vbox.get_node("TitleLabel")
	title.text = "胜利！" if is_victory else "失败"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_TITLE)
	title.add_theme_color_override("font_color", UIConstants.COLOR_GOLD if is_victory else UIConstants.COLOR_ACCENT_DANGER)

	# 波次进度条
	var wave_label: Label = vbox.get_node("WaveProgress/WaveLabel")
	var wave_bar: ProgressBar = vbox.get_node("WaveProgress/WaveBar")
	wave_label.text = "存活波次: %d/%d" % [mini(GameData.current_wave, total_waves), total_waves]
	wave_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	wave_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)
	wave_bar.max_value = total_waves
	wave_bar.value = mini(GameData.current_wave, total_waves)

	# 统计面板
	var stats_panel: PanelContainer = vbox.get_node("StatsPanel")
	stats_panel.add_theme_stylebox_override("panel", UIConstants.create_panel_stylebox())
	var stats_grid: GridContainer = vbox.get_node("StatsPanel/StatsGrid")
	_add_stat_row(stats_grid, "击杀总数", str(GameData.total_kills))
	_add_stat_row(stats_grid, "获取金币", str(GameData.total_coins_earned))
	_add_stat_row(stats_grid, "拥有武器", str(GameData.owned_weapons.size()))
	_add_stat_row(stats_grid, "拥有塔", str(GameData.owned_towers.size()))
	_add_stat_row(stats_grid, "受到伤害", str(int(GameData.total_damage_taken)))
	_add_stat_row(stats_grid, "最高连杀", str(GameData.max_kill_streak))

	# 拥有的武器和塔
	var items_panel: PanelContainer = vbox.get_node("ItemsPanel")
	items_panel.add_theme_stylebox_override("panel", UIConstants.create_panel_stylebox())
	var items_flow: HFlowContainer = vbox.get_node("ItemsPanel/ItemsFlow")
	var has_items := false
	for weapon_id in GameData.owned_weapons:
		has_items = true
		var level: int = GameData.owned_weapons[weapon_id]
		var wdata: WeaponData = GameConfig.weapons.get(weapon_id)
		var text: String = (wdata.display_name if wdata else weapon_id) + " Lv%d" % level
		_add_pill(items_flow, text)
	for tower_id in GameData.owned_towers:
		has_items = true
		var level: int = GameData.owned_towers[tower_id]
		var tdata: TowerData = GameConfig.towers.get(tower_id)
		var text: String = (tdata.display_name if tdata else tower_id) + " Lv%d" % level
		_add_pill(items_flow, text)
	if not has_items:
		var label := Label.new()
		label.text = "无"
		label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
		label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
		items_flow.add_child(label)

	# 按钮
	var restart_btn: Button = vbox.get_node("ButtonRow/RestartButton")
	var menu_btn: Button = vbox.get_node("ButtonRow/MenuButton")
	restart_btn.pressed.connect(_on_restart)
	menu_btn.pressed.connect(_on_menu)
	restart_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	menu_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)


func _add_pill(flow: HFlowContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)
	var pill := PanelContainer.new()
	var pill_style := UIConstants.create_panel_stylebox(Color(0.2, 0.2, 0.3, 0.8), 6)
	pill_style.content_margin_left = 8
	pill_style.content_margin_right = 8
	pill_style.content_margin_top = 4
	pill_style.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", pill_style)
	pill.add_child(label)
	flow.add_child(pill)


func _add_stat_row(grid: GridContainer, label_text: String, value_text: String) -> void:
	var name_l := Label.new()
	name_l.text = label_text
	name_l.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	name_l.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
	grid.add_child(name_l)
	var value_l := Label.new()
	value_l.text = value_text
	value_l.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	value_l.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)
	value_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(value_l)


func _on_restart() -> void:
	GameData.reset()
	SceneManager.go_to(Enums.Scene.CHARACTER_SELECTION)


func _on_menu() -> void:
	GameData.reset()
	SceneManager.go_to(Enums.Scene.START_MENU)
