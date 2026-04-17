extends Control
## 角色选择界面 — 左侧头像列表 + 右侧详情面板

# 属性基准值（用于颜色标记）
# 注意：speed 基准值为 200.0（CharacterData 默认值），旧代码误用 100.0 导致速度始终显绿
const PORTRAIT_BUTTON_SIZE := Vector2(56, 56)
const PORTRAIT_BORDER_WIDTH := 2
const PORTRAIT_BORDER_RADIUS := 4

const CHARACTER_ORDER: Array[String] = ["ranger"]
const UNLOCKED_CHARACTERS: Array[String] = ["ranger"]

const STAT_BASELINES := {
	"max_hp": 100.0,
	"speed": 100.0,
	"starting_gold": 0,
}

# 节点引用
@onready var _portrait_list: VBoxContainer = %PortraitList
@onready var _large_portrait: TextureRect = %LargePortrait
@onready var _character_name: Label = %CharacterName
@onready var _weapon_label: Label = %WeaponLabel
@onready var _hp_value: Label = %HPValue
@onready var _speed_value: Label = %SpeedValue
@onready var _damage_value: Label = %DamageValue
@onready var _attack_speed_value: Label = %AttackSpeedValue
@onready var _starting_gold_value: Label = %StartingGoldValue
@onready var _passive_desc: Label = %PassiveDesc
@onready var _select_button: Button = %SelectButton
@onready var _back_button: Button = %BackButton
@onready var _right_panel: PanelContainer = %RightPanel
@onready var _stats_section: PanelContainer = %StatsSection
@onready var _passive_title: Label = %PassiveTitle

var _selected_id: String = ""
var _portrait_buttons: Dictionary = {}  # character_id → TextureButton
var _selected_style: StyleBoxFlat
var _unselected_style: StyleBoxEmpty


func _ready() -> void:
	_init_portrait_styles()
	_apply_styles()
	_connect_buttons()
	_generate_portrait_list()
	# 默认选中第一个可用角色
	if GameConfig.characters.has("ranger"):
		_select_character("ranger")
	elif GameConfig.characters.size() > 0:
		_select_character(GameConfig.characters.keys()[0])


func _init_portrait_styles() -> void:
	_selected_style = StyleBoxFlat.new()
	_selected_style.bg_color = Color.TRANSPARENT
	_selected_style.border_color = UIConstants.COLOR_GOLD
	_selected_style.border_width_left = PORTRAIT_BORDER_WIDTH
	_selected_style.border_width_right = PORTRAIT_BORDER_WIDTH
	_selected_style.border_width_top = PORTRAIT_BORDER_WIDTH
	_selected_style.border_width_bottom = PORTRAIT_BORDER_WIDTH
	_selected_style.corner_radius_top_left = PORTRAIT_BORDER_RADIUS
	_selected_style.corner_radius_top_right = PORTRAIT_BORDER_RADIUS
	_selected_style.corner_radius_bottom_left = PORTRAIT_BORDER_RADIUS
	_selected_style.corner_radius_bottom_right = PORTRAIT_BORDER_RADIUS
	_unselected_style = StyleBoxEmpty.new()


func _apply_styles() -> void:
	# 背景
	$Background.color = UIConstants.COLOR_BG_PRIMARY

	# 标题
	var title: Label = $MainVBox/TitleLabel
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_TITLE)
	title.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)

	# 右侧面板
	_right_panel.add_theme_stylebox_override("panel", UIConstants.create_panel_stylebox())

	# 角色名
	_character_name.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SUBTITLE)
	_character_name.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)

	# 武器
	_weapon_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	_weapon_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)

	# 属性区域
	_stats_section.add_theme_stylebox_override("panel", UIConstants.create_panel_stylebox(UIConstants.COLOR_BG_PANEL))

	# 属性标题标签
	var stats_grid: GridContainer = _stats_section.get_node("StatsGrid")
	for i in range(0, stats_grid.get_child_count(), 2):
		var title_label: Label = stats_grid.get_child(i)
		title_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
		title_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)

	# 属性值标签
	for value_label in [_hp_value, _speed_value, _damage_value, _attack_speed_value, _starting_gold_value]:
		value_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)

	# 被动技能
	_passive_title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	_passive_title.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)
	_passive_desc.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	_passive_desc.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)

	# 选择按钮样式
	_select_button.add_theme_stylebox_override("normal", UIConstants.create_button_stylebox(UIConstants.COLOR_BUTTON_NORMAL))
	_select_button.add_theme_stylebox_override("hover", UIConstants.create_button_stylebox(UIConstants.COLOR_BUTTON_HOVER))
	_select_button.add_theme_stylebox_override("pressed", UIConstants.create_button_stylebox(UIConstants.COLOR_BUTTON_PRESSED))
	_select_button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	_select_button.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)

	# 返回按钮
	_back_button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)


func _connect_buttons() -> void:
	_select_button.pressed.connect(_on_select_pressed)
	_back_button.pressed.connect(func(): SceneManager.go_to(Enums.Scene.START_MENU))
	UIUtils.setup_button_hover(_select_button)
	UIUtils.setup_button_hover(_back_button)


func _get_sorted_character_ids() -> Array[String]:
	var sorted: Array[String] = []
	# 按预定义顺序添加
	for cid in CHARACTER_ORDER:
		if GameConfig.characters.has(cid):
			sorted.append(cid)
	# 添加不在预定义列表中的角色（兜底）
	for cid in GameConfig.characters:
		if cid not in sorted:
			sorted.append(cid)
	return sorted


func _generate_portrait_list() -> void:
	for child in _portrait_list.get_children():
		child.queue_free()
	_portrait_buttons.clear()

	for character_id in _get_sorted_character_ids():
		var char_data: CharacterData = GameConfig.characters[character_id]
		var is_locked: bool = character_id not in UNLOCKED_CHARACTERS

		# 外层 PanelContainer 用于显示选中边框
		var panel := PanelContainer.new()
		panel.custom_minimum_size = PORTRAIT_BUTTON_SIZE

		# 内层 TextureButton 显示头像
		var btn := TextureButton.new()
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL

		# 加载头像纹理
		var portrait: Texture2D = _load_portrait(char_data.portrait_path)
		if portrait:
			btn.texture_normal = portrait
		else:
			var placeholder := ColorRect.new()
			placeholder.color = UIConstants.COLOR_BG_PANEL
			placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			btn.add_child(placeholder)

		if is_locked:
			# 锁定角色：灰度 + 不可点击
			btn.modulate = Color(0.4, 0.4, 0.4, 0.7)
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			btn.pressed.connect(_select_character.bind(character_id))

		panel.add_child(btn)
		_portrait_list.add_child(panel)
		_portrait_buttons[character_id] = panel

	# 添加 5 个"敬请期待"占位卡（不可点击，灰色）
	for i in range(5):
		var placeholder_panel := PanelContainer.new()
		placeholder_panel.custom_minimum_size = PORTRAIT_BUTTON_SIZE

		var coming_soon_bg := ColorRect.new()
		coming_soon_bg.color = Color(0.2, 0.2, 0.2, 0.8)
		coming_soon_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		coming_soon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var coming_soon_label := Label.new()
		coming_soon_label.text = "敬请\n期待"
		coming_soon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		coming_soon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		coming_soon_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		coming_soon_label.add_theme_font_size_override("font_size", 9)
		coming_soon_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.8))
		coming_soon_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		coming_soon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		placeholder_panel.add_child(coming_soon_bg)
		placeholder_panel.add_child(coming_soon_label)
		placeholder_panel.modulate = Color(0.6, 0.6, 0.6, 0.7)
		placeholder_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		_portrait_list.add_child(placeholder_panel)


func _load_portrait(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _select_character(character_id: String) -> void:
	_selected_id = character_id
	_update_portrait_borders()
	_fill_detail_panel(character_id)


func _update_portrait_borders() -> void:
	for cid in _portrait_buttons:
		var panel: PanelContainer = _portrait_buttons[cid]
		if cid == _selected_id:
			panel.add_theme_stylebox_override("panel", _selected_style)
		else:
			panel.add_theme_stylebox_override("panel", _unselected_style)


func _fill_detail_panel(character_id: String) -> void:
	var char_data: CharacterData = GameConfig.characters[character_id]

	# 头像
	var portrait: Texture2D = _load_portrait(char_data.portrait_path)
	if portrait:
		_large_portrait.texture = portrait
	else:
		_large_portrait.texture = null

	# 名称
	_character_name.text = char_data.display_name
	_weapon_label.text = ""

	# 属性
	_hp_value.text = "%d" % int(char_data.max_hp)
	_speed_value.text = "%d" % int(char_data.speed)
	_damage_value.text = "—"
	_attack_speed_value.text = "—"
	_starting_gold_value.text = "%d" % char_data.starting_gold

	# 属性颜色
	_color_stat(_hp_value, char_data.max_hp, STAT_BASELINES["max_hp"])
	_color_stat(_speed_value, char_data.speed, STAT_BASELINES["speed"])
	_color_stat(_starting_gold_value, float(char_data.starting_gold), float(STAT_BASELINES["starting_gold"]))

	# 技能描述（Task 15 改造为能力列表）
	if char_data.description != "":
		_passive_desc.text = char_data.description
	else:
		_passive_desc.text = "暂无描述"


func _color_stat(label: Label, value: float, baseline: float) -> void:
	if value > baseline:
		label.add_theme_color_override("font_color", UIConstants.COLOR_POSITIVE)
	elif value < baseline:
		label.add_theme_color_override("font_color", UIConstants.COLOR_ACCENT_DANGER)
	else:
		label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)


func _on_select_pressed() -> void:
	if _selected_id == "":
		return
	# 重置顺序：PlayerState → PlayerProgression → InventoryManager → StatsTracker → PerkManager
	PlayerState.init_character(_selected_id)
	PlayerProgression.reset()
	InventoryManager.reset()
	StatsTracker.reset()
	PerkManager.reset()
	PerkManager.refresh_pool_for_current_character()
	SceneManager.go_to(Enums.Scene.MAP_SELECT)
