extends PanelContainer
## 角色卡片 — 展示角色属性、亲和标签，支持选中反馈

signal selected(character_id: String)

@onready var portrait_rect: ColorRect = $VBoxContainer/PortraitRect
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var hp_label: Label = $VBoxContainer/StatsContainer/HPLabel
@onready var speed_label: Label = $VBoxContainer/StatsContainer/SpeedLabel
@onready var damage_label: Label = $VBoxContainer/StatsContainer/DamageLabel
@onready var affinity_label: Label = $VBoxContainer/AffinityLabel
@onready var weapon_label: Label = $VBoxContainer/WeaponLabel
@onready var select_button: Button = $VBoxContainer/SelectButton

var _character_id: String = ""


func _ready() -> void:
	select_button.pressed.connect(func(): selected.emit(_character_id))
	_apply_base_style()


func setup(character_id: String, char_data: CharacterData, weapon_data: WeaponData) -> void:
	_character_id = character_id
	name_label.text = char_data.display_name
	hp_label.text = "HP  %d" % int(char_data.max_hp)
	speed_label.text = "速度  %d" % int(char_data.speed)
	damage_label.text = "攻击  x%.1f" % char_data.damage_mult

	# 亲和标签
	if char_data.affinity_tags.size() > 0:
		var tags: Array[String] = []
		for tag in char_data.affinity_tags:
			tags.append(tag)
		affinity_label.text = "亲和: %s  折扣%d%%" % ["/".join(tags), int(char_data.affinity_discount * 100)]
	else:
		affinity_label.text = ""

	weapon_label.text = "武器: %s" % weapon_data.display_name

	# 属性着色
	_color_stat(hp_label, char_data.max_hp, 100.0)
	_color_stat(speed_label, char_data.speed, 100.0)
	_color_stat(damage_label, char_data.damage_mult, 1.0)


func _color_stat(label: Label, value: float, baseline: float) -> void:
	if value > baseline:
		label.add_theme_color_override("font_color", UIConstants.COLOR_POSITIVE)
	elif value < baseline:
		label.add_theme_color_override("font_color", UIConstants.COLOR_ACCENT_DANGER)
	else:
		label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)


func set_selected(is_selected: bool) -> void:
	if is_selected:
		var style := UIConstants.create_panel_stylebox(UIConstants.COLOR_BG_PANEL_ALPHA, UIConstants.CORNER_RADIUS_PANEL, UIConstants.COLOR_GOLD, 2)
		add_theme_stylebox_override("panel", style)
		select_button.text = "已选择"
	else:
		_apply_base_style()
		select_button.text = "选择"


func _apply_base_style() -> void:
	var style := UIConstants.create_panel_stylebox()
	add_theme_stylebox_override("panel", style)
	name_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SUBTITLE)
	for label in [hp_label, speed_label, damage_label]:
		label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	affinity_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	affinity_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
	weapon_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	weapon_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
