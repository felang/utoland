extends Control
## 待建造栏 — 3 槽水平排列
##
## - 监听 tower_added_to_queue / tower_consumed_from_queue 刷新
## - 点击槽位 → 调 drag_manager.start_tower_placement(tower_id, on_placed, on_cancelled)
##   on_placed 回调时,从 InventoryManager 消费该槽位
##
## drag_manager 由父组件(BattleHUD)注入

const SLOT_SIZE := Vector2(56, 72)

var drag_manager: Node = null  # 外部注入

var _slot_buttons: Array[Button] = []
var _slot_icons: Array[TextureRect] = []
var _slot_names: Array[Label] = []
var _placing_index: int = -1

func _ready() -> void:
	_build_ui()
	EventBus.tower_added_to_queue.connect(_refresh)
	EventBus.tower_consumed_from_queue.connect(func(_idx: int) -> void: _refresh())
	_refresh()

func _build_ui() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	hbox.add_theme_constant_override("separation", 6)
	add_child(hbox)
	for i in GameConfig.shop_config.pending_queue_size:
		hbox.add_child(_create_slot(i))

func _create_slot(idx: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = SLOT_SIZE
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)
	_slot_icons.append(icon)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	_slot_names.append(name_label)

	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on_slot_pressed.bind(idx))
	panel.add_child(btn)
	_slot_buttons.append(btn)
	return panel

func _refresh(_arg = null) -> void:
	for i in _slot_buttons.size():
		if i < InventoryManager.pending_towers.size():
			var tid: String = InventoryManager.pending_towers[i]
			var data: TowerData = GameConfig.towers.get(tid)
			_slot_names[i].text = data.display_name if data else tid
			if data and data.icon_path != "" and ResourceLoader.exists(data.icon_path):
				_slot_icons[i].texture = load(data.icon_path)
			else:
				_slot_icons[i].texture = null
			_slot_buttons[i].disabled = false
			_slot_buttons[i].modulate = Color.WHITE
		else:
			_slot_icons[i].texture = null
			_slot_names[i].text = "空"
			_slot_buttons[i].disabled = true
			_slot_buttons[i].modulate = Color(0.4, 0.4, 0.4)

func _on_slot_pressed(idx: int) -> void:
	if drag_manager == null:
		push_warning("PendingQueuePanel: drag_manager 未注入")
		return
	if idx >= InventoryManager.pending_towers.size():
		return
	if _placing_index >= 0:
		return  # 正在放置另一张
	_placing_index = idx
	var tower_id: String = InventoryManager.pending_towers[idx]
	drag_manager.start_tower_placement(
		tower_id,
		_on_placed,
		_on_cancelled,
	)

func _on_placed(grid_pos: Vector2i) -> void:
	if _placing_index < 0:
		return
	var result: Dictionary = InventoryManager.deploy_pending_tower(_placing_index, grid_pos)
	if not result.is_empty():
		# 移除被合成的旧塔节点
		for old_id in result.merged_away:
			drag_manager._remove_tower_node(old_id)
		# 部署最终塔节点(若合成则是升级产物)
		drag_manager.spawn_tower_node(result.deploy_id, result.tower_id, result.level, grid_pos)
	# 若 result 为空(人口满或失败),pending 不消费,卡片留在栏内 ✓
	_placing_index = -1
	_refresh()

func _on_cancelled() -> void:
	# 玩家取消放置 → pending 不消费,卡片回到栏内
	_placing_index = -1
	_refresh()
