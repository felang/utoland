extends CanvasLayer
## 波次结束升级弹窗 — 多轮 3 选 1（武器+塔混合池）

signal upgrade_selected(type: String, id: String)
signal all_upgrades_completed
signal skipped

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
	_animate_popup_in()
	_animate_cards_in()

func _rebuild_cards() -> void:
	for child in _cards_container.get_children():
		child.queue_free()
	for i in _options.size():
		var card: PanelContainer = UpgradeCardBuilder.create_card(
			_options[i],
			func(): _on_option_selected(i)
		)
		_cards_container.add_child(card)

func _on_option_selected(index: int) -> void:
	_animate_card_selection(index)
	await get_tree().create_timer(0.3).timeout
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

func _animate_popup_in() -> void:
	_container.pivot_offset = _container.size / 2
	_container.scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(_container, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _animate_cards_in() -> void:
	var cards: Array = _cards_container.get_children()
	for i in cards.size():
		var card: Control = cards[i]
		var target_pos: float = card.position.y
		card.position.y += 50.0
		card.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(card, "position:y", target_pos, 0.25).set_ease(Tween.EASE_OUT).set_delay(i * 0.1)
		tween.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(i * 0.1)

func _animate_card_selection(selected_index: int) -> void:
	var cards: Array = _cards_container.get_children()
	for i in cards.size():
		var card: Control = cards[i]
		card.pivot_offset = card.size / 2
		var tween: Tween = create_tween()
		if i == selected_index:
			tween.tween_property(card, "scale", Vector2(1.1, 1.1), 0.15)
		else:
			tween.set_parallel(true)
			tween.tween_property(card, "scale", Vector2(0.9, 0.9), 0.15)
			tween.tween_property(card, "modulate:a", 0.3, 0.15)

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
