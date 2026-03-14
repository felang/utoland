class_name UpgradeCardBuilder
extends RefCounted
## 升级卡片 UI 构建器 — 从升级选项数据创建卡片 PanelContainer

const CARD_WIDTH: int = 180
const CARD_HEIGHT: int = 200
const RARITY_COLORS: Dictionary = {
	Enums.WeaponRarity.COMMON: Color("#4fc3f7"),
	Enums.WeaponRarity.RARE: Color("#ab47bc"),
	Enums.WeaponRarity.EPIC: Color("#ffa726"),
}

static func create_card(opt: Dictionary, on_selected: Callable) -> PanelContainer:
	var is_weapon: bool = opt["type"] == "weapon"
	var border_color: Color
	if is_weapon:
		var wd: WeaponData = GameConfig.weapons[opt["id"]]
		border_color = RARITY_COLORS.get(wd.rarity, Color("#4fc3f7"))
	else:
		border_color = Color("#66bb6a")
	var bg_color: Color = Color("#1a1a3a") if is_weapon else Color("#1a2a1a")

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
	type_lbl.text = "⚔ 武器" if is_weapon else "🏗 塔"
	type_lbl.add_theme_font_size_override("font_size", 11)
	type_lbl.add_theme_color_override("font_color", border_color)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_lbl)

	# 名称
	var name_lbl := Label.new()
	name_lbl.text = _get_display_name(opt)
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# 描述文字（仅武器且 description 非空时显示）
	if is_weapon:
		if not opt.has("_wd"):
			var wd_for_desc: WeaponData = GameConfig.weapons[opt["id"]]
			if wd_for_desc.description != "":
				var desc_lbl := Label.new()
				desc_lbl.text = wd_for_desc.description
				desc_lbl.add_theme_font_size_override("font_size", 10)
				desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
				desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				vbox.add_child(desc_lbl)

	# 等级信息
	var level_lbl := Label.new()
	if opt["is_new"]:
		level_lbl.text = "新武器! Lv1" if is_weapon else "新塔! Lv1"
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
			on_selected.call()
	)

	return panel


static func _get_display_name(opt: Dictionary) -> String:
	if opt["type"] == "weapon":
		var wd: WeaponData = GameConfig.weapons[opt["id"]]
		return wd.display_name
	else:
		var td: TowerData = GameConfig.towers[opt["id"]]
		return td.display_name


static func _get_stats_text(opt: Dictionary) -> String:
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
