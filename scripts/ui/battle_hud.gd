extends CanvasLayer
## 战斗 HUD 主组件
##
## 包含:
##   - 底部中央: Roll 按钮 + 待建造栏(实例化 PendingQueuePanel.tscn)
##   - 左上角: 猎杀充能条 + 标记剩余时间标签
##   - 右上角: 箭雨 CD 指示器
##
## 外部依赖:drag_manager,由 main.gd 注入。

const ROLL_BTN_SIZE := Vector2(120, 36)
const PENDING_PANEL_SCENE := preload("res://scenes/ui/pending_queue_panel.tscn")

var drag_manager: Node = null

var _roll_button: Button
var _pending_panel: Control

# 猎杀充能条
var _hunt_mark_bar: ProgressBar
var _hunt_mark_duration_label: Label

# 箭雨 CD 指示器
var _rain_indicator: Label

func _ready() -> void:
	layer = 10
	_build_ui()
	_refresh_roll_button()
	EventBus.coins_changed.connect(func(_d: int, _t: int) -> void: _refresh_roll_button())
	EventBus.tower_added_to_queue.connect(func(_t: String) -> void: _refresh_roll_button())
	EventBus.tower_consumed_from_queue.connect(func(_i: int) -> void: _refresh_roll_button())
	EventBus.tower_roll_canceled.connect(func() -> void: _refresh_roll_button())

func _process(_delta: float) -> void:
	_update_hunt_mark()
	_update_rain_indicator()

func _build_ui() -> void:
	# 左上角: 猎杀充能条容器
	var mark_vbox := VBoxContainer.new()
	mark_vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mark_vbox.position = Vector2(12, 12)
	mark_vbox.add_theme_constant_override("separation", 2)
	add_child(mark_vbox)

	_hunt_mark_bar = ProgressBar.new()
	_hunt_mark_bar.custom_minimum_size = Vector2(120, 14)
	_hunt_mark_bar.min_value = 0.0
	_hunt_mark_bar.max_value = 1.0
	_hunt_mark_bar.value = 0.0
	_hunt_mark_bar.show_percentage = false
	_hunt_mark_bar.visible = false
	mark_vbox.add_child(_hunt_mark_bar)

	_hunt_mark_duration_label = Label.new()
	_hunt_mark_duration_label.add_theme_font_size_override("font_size", 11)
	_hunt_mark_duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hunt_mark_duration_label.visible = false
	mark_vbox.add_child(_hunt_mark_duration_label)

	# 右上角: 箭雨 CD 指示器
	_rain_indicator = Label.new()
	_rain_indicator.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_rain_indicator.position = Vector2(-80, 12)
	_rain_indicator.custom_minimum_size = Vector2(68, 28)
	_rain_indicator.text = "箭雨"
	_rain_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rain_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rain_indicator.add_theme_font_size_override("font_size", 14)
	_rain_indicator.modulate.a = 0.3
	_rain_indicator.visible = false
	add_child(_rain_indicator)

	# 底部:Roll 按钮 + 待建造栏
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 12)
	bottom.position.y = -100
	add_child(bottom)

	_roll_button = Button.new()
	_roll_button.custom_minimum_size = ROLL_BTN_SIZE
	_roll_button.pressed.connect(_on_roll_pressed)
	bottom.add_child(_roll_button)

	_pending_panel = PENDING_PANEL_SCENE.instantiate()
	bottom.add_child(_pending_panel)

func _refresh_roll_button() -> void:
	var cost: int = GameConfig.shop_config.roll_cost
	_roll_button.text = "Roll $%d" % cost
	_roll_button.disabled = not InventoryManager.can_roll()

func _on_roll_pressed() -> void:
	InventoryManager.roll_tower()
	_refresh_roll_button()

func set_drag_manager(dm: Node) -> void:
	drag_manager = dm
	if _pending_panel:
		_pending_panel.drag_manager = dm

# ===== 能力 HUD 更新 =====

func _update_hunt_mark() -> void:
	var player: Node = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	if player == null:
		_hunt_mark_bar.visible = false
		return
	var abilities: Node = player.get_node_or_null("Abilities")
	if abilities == null:
		_hunt_mark_bar.visible = false
		return
	var mark_comp: HuntMarkSkillComponent = null
	for c in abilities.get_children():
		if c is HuntMarkSkillComponent:
			mark_comp = c
			break
	if mark_comp == null:
		_hunt_mark_bar.visible = false
		return
	_hunt_mark_bar.visible = true
	_hunt_mark_bar.max_value = mark_comp.get_charge_required()
	_hunt_mark_bar.value = mark_comp.get_charge()
	if mark_comp.get_marked_target() != null:
		_hunt_mark_bar.modulate = Color.RED
		_hunt_mark_duration_label.visible = true
		_hunt_mark_duration_label.text = "%.1fs" % mark_comp.get_mark_remaining()
	else:
		_hunt_mark_bar.modulate = Color.YELLOW
		_hunt_mark_duration_label.visible = false

func _update_rain_indicator() -> void:
	var player: Node = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	if player == null:
		_rain_indicator.visible = false
		return
	var abilities: Node = player.get_node_or_null("Abilities")
	if abilities == null:
		_rain_indicator.visible = false
		return
	var rain_comp: ArrowRainSkillComponent = null
	for c in abilities.get_children():
		if c is ArrowRainSkillComponent:
			rain_comp = c
			break
	if rain_comp == null:
		_rain_indicator.visible = false
		return
	_rain_indicator.visible = true
	if rain_comp.is_ready():
		_rain_indicator.modulate.a = 1.0
		_rain_indicator.text = "箭雨"
	else:
		_rain_indicator.modulate.a = 0.3
		_rain_indicator.text = "箭雨\n%.1fs" % rain_comp.get_cooldown_remaining()
