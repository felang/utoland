extends CanvasLayer
## 升级 3 选 1 暂停弹窗
##
## - 监听 EventBus.perk_offered → 弹出 + 设置 paused
## - 玩家点选一张卡 → PerkManager.select_perk(id) → 关闭面板 + paused=false
## - process_mode = ALWAYS,不被暂停影响

const CARD_SIZE := Vector2(180, 240)

var _root: Control
var _card_buttons: Array[Button] = []
var _card_titles: Array[Label] = []
var _card_descs: Array[Label] = []
var _current_offer: Array = []

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	EventBus.perk_offered.connect(_on_perk_offered)

func _build_ui() -> void:
	# 半透明遮罩
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	_root = bg

	# 标题
	var title := Label.new()
	title.text = "升级!选一个加成"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position.y = 80
	bg.add_child(title)

	# 3 张卡片
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	hbox.position = Vector2(-CARD_SIZE.x * 1.5 - 16, -CARD_SIZE.y * 0.5)
	bg.add_child(hbox)

	for i in 3:
		var card := _create_card(i)
		hbox.add_child(card)

func _create_card(idx: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = CARD_SIZE
	btn.flat = false
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	_card_titles.append(title)

	var desc := Label.new()
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(CARD_SIZE.x - 20, 0)
	vbox.add_child(desc)
	_card_descs.append(desc)

	btn.pressed.connect(_on_card_pressed.bind(idx))
	_card_buttons.append(btn)
	return btn

func _on_perk_offered(perks: Array) -> void:
	_current_offer = perks
	for i in 3:
		if i < perks.size():
			var p: PerkData = perks[i]
			_card_titles[i].text = p.display_name
			_card_descs[i].text = p.description
			_card_buttons[i].visible = true
			_card_buttons[i].disabled = false
		else:
			_card_buttons[i].visible = false
	visible = true
	get_tree().paused = true

func _on_card_pressed(idx: int) -> void:
	if idx < 0 or idx >= _current_offer.size():
		return
	var perk: PerkData = _current_offer[idx]
	PerkManager.select_perk(perk.id)
	# 检查是否还有排队的升级 — 若有,PerkManager 会自动 emit 下一个 perk_offered
	if PerkManager.has_pending():
		# 等待下一个 offer 弹窗(_on_perk_offered 会立即被再次调用)
		return
	# 否则关闭面板并恢复
	visible = false
	get_tree().paused = false
