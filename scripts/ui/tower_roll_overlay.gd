extends CanvasLayer
## Roll 时弹出的 3 选 1 塔卡片面板
##
## 不暂停游戏，玩家可以选 1 张或取消(取消退款)。
## 监听 EventBus.tower_rolled → 弹出 → 玩家点卡 → 调 InventoryManager.confirm_roll_pick

const CARD_SIZE := Vector2(120, 160)

var _root: Control
var _card_buttons: Array[Button] = []
var _card_icons: Array[TextureRect] = []
var _card_names: Array[Label] = []
var _cancel_btn: Button
var _current_offer: Array[String] = []

func _ready() -> void:
	layer = 40
	_build_ui()
	visible = false
	EventBus.tower_rolled.connect(_on_tower_rolled)

func _build_ui() -> void:
	# 半透明背景(可点空白处不取消,需点取消按钮)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.4)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	_root = bg

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Roll 出 3 张,选一张"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)
	for i in 3:
		hbox.add_child(_create_card(i))

	_cancel_btn = Button.new()
	_cancel_btn.text = "取消(退款)"
	_cancel_btn.custom_minimum_size = Vector2(140, 32)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	vbox.add_child(_cancel_btn)

func _create_card(idx: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = CARD_SIZE
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)
	_card_icons.append(icon)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	_card_names.append(name_label)

	btn.pressed.connect(_on_card_pressed.bind(idx))
	_card_buttons.append(btn)
	return btn

func _on_tower_rolled(candidates: Array) -> void:
	_current_offer.clear()
	for c in candidates:
		_current_offer.append(c)
	for i in 3:
		if i < _current_offer.size():
			var tid: String = _current_offer[i]
			var data: TowerData = GameConfig.towers.get(tid)
			_card_names[i].text = data.display_name if data else tid
			if data and data.icon_path != "" and ResourceLoader.exists(data.icon_path):
				_card_icons[i].texture = load(data.icon_path)
			else:
				_card_icons[i].texture = null
			_card_buttons[i].visible = true
		else:
			_card_buttons[i].visible = false
	visible = true

func _on_card_pressed(idx: int) -> void:
	InventoryManager.confirm_roll_pick(idx)
	visible = false

func _on_cancel_pressed() -> void:
	InventoryManager.cancel_roll()
	visible = false
