extends CanvasLayer

const HP_COLOR_HIGH_THRESHOLD: float = 0.6   # HP比例 > 此值显示绿色
const HP_COLOR_LOW_THRESHOLD: float = 0.3    # HP比例 > 此值显示黄色，否则红色
const TIMER_WARNING_SECONDS: int = 5         # 倒计时最后N秒变红
const BUFF_CORNER_RADIUS: int = 6            # 增益标签圆角
const BUFF_PADDING_H: int = 6               # 增益标签水平内边距
const BUFF_PADDING_V: int = 2               # 增益标签垂直内边距

@onready var hp_progress: ProgressBar = $TopBar/MarginContainer/HBoxContainer/HPBar/HPProgress
@onready var hp_text: Label = $TopBar/MarginContainer/HBoxContainer/HPBar/HPText
@onready var hp_icon: Label = $TopBar/MarginContainer/HBoxContainer/HPBar/HPIcon
@onready var coin_icon: Label = $TopBar/MarginContainer/HBoxContainer/CoinDisplay/CoinIcon
@onready var coin_text: Label = $TopBar/MarginContainer/HBoxContainer/CoinDisplay/CoinText
@onready var wave_display: Label = $TopBar/MarginContainer/HBoxContainer/WaveDisplay
@onready var timer_display: Label = $TopBar/MarginContainer/HBoxContainer/TimerDisplay
@onready var kill_display: Label = $TopBar/MarginContainer/HBoxContainer/KillDisplay
@onready var buff_container: HBoxContainer = $BottomBar/MarginContainer/BuffContainer

var player: Node2D = null
var _wave_time_left: float = 0.0
var _is_wave_active: bool = false
var _wave_kills: int = 0

func _ready() -> void:
	player = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	if not player:
		push_warning("HUD: Player node not found in 'player' group")
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)
	_style_ui()
	_update_buffs()

func _process(delta: float) -> void:
	_update_hp()
	_update_coins()
	_update_timer(delta)
	_update_kills()

func _update_hp() -> void:
	if not player or not is_instance_valid(player):
		return
	var current: float = player.health.current_hp
	var max_hp: float = player.health.max_hp
	hp_progress.max_value = max_hp
	hp_progress.value = current
	hp_text.text = "%d/%d" % [int(current), int(max_hp)]
	# HP 颜色编码：绿 → 黄 → 红
	var ratio := current / max_hp if max_hp > 0 else 0.0
	var color: Color
	if ratio > HP_COLOR_HIGH_THRESHOLD:
		color = UIConstants.COLOR_POSITIVE
	elif ratio > HP_COLOR_LOW_THRESHOLD:
		color = UIConstants.COLOR_GOLD
	else:
		color = UIConstants.COLOR_ACCENT_DANGER
	hp_text.add_theme_color_override("font_color", color)

func _update_coins() -> void:
	if player and is_instance_valid(player):
		coin_text.text = str(player.coins)

func _update_timer(delta: float) -> void:
	if _is_wave_active:
		_wave_time_left -= delta
		if _wave_time_left < 0:
			_wave_time_left = 0.0
	var seconds := int(_wave_time_left)
	timer_display.text = "%ds" % seconds
	wave_display.text = "Wave %d/%d" % [GameData.current_wave, GameConfig.waves.size()]
	# 最后 5 秒变红
	if _is_wave_active and seconds <= TIMER_WARNING_SECONDS:
		timer_display.add_theme_color_override("font_color", UIConstants.COLOR_ACCENT_DANGER)
	else:
		timer_display.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)

func _update_kills() -> void:
	kill_display.text = "Kill: %d" % _wave_kills

func _style_ui() -> void:
	# TopBar 半透明背景
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	top_style.content_margin_left = UIConstants.MARGIN_SCREEN
	top_style.content_margin_right = UIConstants.MARGIN_SCREEN
	top_style.content_margin_top = 4
	top_style.content_margin_bottom = 4
	$TopBar.add_theme_stylebox_override("panel", top_style)
	# BottomBar 半透明背景
	var bottom_style := StyleBoxFlat.new()
	bottom_style.bg_color = Color(0.0, 0.0, 0.0, 0.3)
	bottom_style.content_margin_left = UIConstants.MARGIN_SCREEN
	bottom_style.content_margin_right = UIConstants.MARGIN_SCREEN
	bottom_style.content_margin_top = 4
	bottom_style.content_margin_bottom = 4
	$BottomBar.add_theme_stylebox_override("panel", bottom_style)
	# 字号和颜色
	for label in [wave_display, timer_display, kill_display]:
		label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
		label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)
	hp_text.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	hp_icon.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	hp_icon.add_theme_color_override("font_color", UIConstants.COLOR_ACCENT_DANGER)
	coin_text.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	coin_text.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	coin_icon.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BODY)
	coin_icon.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)

func _update_buffs() -> void:
	for child in buff_container.get_children():
		child.queue_free()
	var buffs: Array[String] = []
	if GameData.pierce_count > 0:
		buffs.append("穿甲x%d" % GameData.pierce_count)
	if GameData.multishot_active:
		buffs.append("弹幕")
	if GameData.lifesteal_ratio > 0:
		buffs.append("吸血%d%%" % int(GameData.lifesteal_ratio * 100))
	if GameData.crit_chance > 0:
		buffs.append("暴击%d%%" % int(GameData.crit_chance * 100))
	if GameData.current_shield > 0:
		buffs.append("护盾x%d" % GameData.current_shield)
	if GameData.damage_reduction > 0:
		buffs.append("减伤%d%%" % int(GameData.damage_reduction * 100))
	if GameData.dodge_chance > 0:
		buffs.append("闪避%d%%" % int(GameData.dodge_chance * 100))
	if GameData.slow_aura_active:
		buffs.append("减速光环")
	if GameData.auto_dash_active:
		buffs.append("冲刺")
	if GameData.coin_magnet_mult > 1.0:
		buffs.append("磁铁")
	if GameData.split_count > 0:
		buffs.append("分裂x%d" % GameData.split_count)
	if GameData.bullet_speed_mult > 1.0:
		buffs.append("弹速+")
	if GameData.weapon_range_mult > 1.0:
		buffs.append("射程+")
	for buff_text in buffs:
		var label := Label.new()
		label.text = buff_text
		label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
		label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.0, 0.0, 0.0, 0.6)
		style.corner_radius_top_left = BUFF_CORNER_RADIUS
		style.corner_radius_top_right = BUFF_CORNER_RADIUS
		style.corner_radius_bottom_left = BUFF_CORNER_RADIUS
		style.corner_radius_bottom_right = BUFF_CORNER_RADIUS
		style.content_margin_left = BUFF_PADDING_H
		style.content_margin_right = BUFF_PADDING_H
		style.content_margin_top = BUFF_PADDING_V
		style.content_margin_bottom = BUFF_PADDING_V
		panel.add_theme_stylebox_override("panel", style)
		panel.add_child(label)
		buff_container.add_child(panel)

func _on_wave_started(_wave_number: int, wave_data: WaveData) -> void:
	_is_wave_active = true
	_wave_time_left = wave_data.time_limit
	_wave_kills = 0
	_update_buffs()

func _on_wave_completed(_wave_number: int) -> void:
	_is_wave_active = false
