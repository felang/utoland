extends CanvasLayer

## 精简战斗 HUD：左上角 HP/XP/金币，顶部居中波次显示

const HP_COLOR_HIGH_THRESHOLD: float = 0.6
const HP_COLOR_LOW_THRESHOLD: float = 0.3

# 节点引用 — 左上角
@onready var hp_icon: PanelContainer = $LeftTop/VBox/HPRow/HPIcon
@onready var hp_progress: ProgressBar = $LeftTop/VBox/HPRow/HPProgress
@onready var xp_icon: PanelContainer = $LeftTop/VBox/XPRow/XPIcon
@onready var xp_progress: ProgressBar = $LeftTop/VBox/XPRow/XPProgress
@onready var level_label: Label = $LeftTop/VBox/XPRow/LevelLabel
@onready var coin_icon: PanelContainer = $LeftTop/VBox/CoinRow/CoinIcon
@onready var coin_text: Label = $LeftTop/VBox/CoinRow/CoinText
# 节点引用 — 顶部居中
@onready var wave_panel: PanelContainer = $WaveCenter/WavePanel
@onready var wave_label: Label = $WaveCenter/WavePanel/WaveVBox/WaveLabel
@onready var countdown_label: Label = $WaveCenter/WavePanel/WaveVBox/CountdownLabel

var player: Node2D = null
var _last_coins: int = -1
var _wave_time_left: float = 0.0
var _is_battle: bool = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	if not player:
		push_warning("HUD: Player node not found in 'player' group")
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.player_level_changed.connect(_on_player_level_changed)
	EventBus.exp_changed.connect(_on_exp_changed)
	_style_ui()
	_init_exp_bar()

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	_update_hp()
	_update_coins()
	_update_countdown(delta)

# ===== HP 更新 =====

func _update_hp() -> void:
	if not player or not is_instance_valid(player):
		return
	var current: float = player.health.current_hp
	var max_hp: float = player.health.max_hp
	hp_progress.max_value = max_hp
	hp_progress.value = current
	# 进度条颜色编码：绿 → 黄 → 红
	var ratio := current / max_hp if max_hp > 0 else 0.0
	var color: Color
	if ratio > HP_COLOR_HIGH_THRESHOLD:
		color = UIConstants.COLOR_POSITIVE
	elif ratio > HP_COLOR_LOW_THRESHOLD:
		color = UIConstants.COLOR_HUD_HP_YELLOW
	else:
		color = UIConstants.COLOR_ACCENT_DANGER
	var fill_style := hp_progress.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		fill_style.bg_color = color

# ===== 金币更新 =====

func _update_coins() -> void:
	if player and is_instance_valid(player):
		var current_coins: int = player.coins
		coin_text.text = str(current_coins)
		if _last_coins >= 0 and current_coins != _last_coins:
			_bounce_label(coin_text)
		_last_coins = current_coins

func _bounce_label(label: Control) -> void:
	label.pivot_offset = label.size / 2
	var tween: Tween = create_tween()
	tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(label, "scale", Vector2.ONE, 0.1)

# ===== 倒计时更新 =====

func _update_countdown(delta: float) -> void:
	if not _is_battle:
		return
	_wave_time_left = maxf(_wave_time_left - delta, 0.0)
	var seconds: int = ceili(_wave_time_left)
	countdown_label.text = "%d:%02d" % [seconds / 60, seconds % 60]

# ===== 阶段切换 =====

func set_battle_phase(is_battle: bool) -> void:
	_is_battle = is_battle
	wave_panel.visible = is_battle

# ===== 信号回调 =====

func _on_wave_started(wave_number: int, wave_data: WaveData) -> void:
	wave_label.text = "第 %d 波" % wave_number
	_wave_time_left = wave_data.time_limit

func _on_player_level_changed(new_level: int) -> void:
	level_label.text = "Lv.%d" % new_level
	_bounce_label(level_label)

func _on_exp_changed(current_exp: int, exp_to_next: int) -> void:
	xp_progress.max_value = exp_to_next
	xp_progress.value = current_exp

func _init_exp_bar() -> void:
	var next_threshold: int = PlayerProgression.exp_for_level(PlayerProgression.player_level + 1)
	xp_progress.max_value = next_threshold
	xp_progress.value = PlayerProgression.current_exp
	level_label.text = "Lv.%d" % PlayerProgression.player_level

# ===== 样式初始化 =====

func _style_ui() -> void:
	# HP 图标 — 红底白框小方块
	_style_icon(hp_icon, "♥", UIConstants.COLOR_ACCENT_DANGER, Color.WHITE)
	# XP 图标 — 深蓝底蓝框小方块
	_style_icon(xp_icon, "★", UIConstants.COLOR_HUD_XP_BG, UIConstants.COLOR_HUD_XP)
	# 金币图标 — 深金底金框小方块
	_style_icon(coin_icon, "$", UIConstants.COLOR_HUD_COIN_BG, UIConstants.COLOR_GOLD)

	# HP 进度条样式
	_style_progress_bar(hp_progress, UIConstants.COLOR_POSITIVE, UIConstants.HUD_HP_BAR_HEIGHT)
	# XP 进度条样式
	_style_progress_bar(xp_progress, UIConstants.COLOR_HUD_XP, UIConstants.HUD_XP_BAR_HEIGHT)

	# 等级标签
	level_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	level_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
	level_label.text = "Lv.%d" % PlayerProgression.player_level

	# 金币文字
	coin_text.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	coin_text.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)

	# 波次面板
	var wave_style := StyleBoxFlat.new()
	wave_style.bg_color = UIConstants.COLOR_HUD_BG
	wave_style.border_color = UIConstants.COLOR_HUD_BORDER
	wave_style.border_width_left = UIConstants.HUD_ICON_BORDER
	wave_style.border_width_right = UIConstants.HUD_ICON_BORDER
	wave_style.border_width_top = UIConstants.HUD_ICON_BORDER
	wave_style.border_width_bottom = UIConstants.HUD_ICON_BORDER
	wave_style.corner_radius_top_left = UIConstants.HUD_ICON_CORNER
	wave_style.corner_radius_top_right = UIConstants.HUD_ICON_CORNER
	wave_style.corner_radius_bottom_left = UIConstants.HUD_ICON_CORNER
	wave_style.corner_radius_bottom_right = UIConstants.HUD_ICON_CORNER
	wave_style.content_margin_left = UIConstants.HUD_WAVE_PADDING_H
	wave_style.content_margin_right = UIConstants.HUD_WAVE_PADDING_H
	wave_style.content_margin_top = UIConstants.HUD_WAVE_PADDING_V
	wave_style.content_margin_bottom = UIConstants.HUD_WAVE_PADDING_V
	wave_panel.add_theme_stylebox_override("panel", wave_style)

	# 波次标签
	wave_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	wave_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_PRIMARY)
	wave_label.text = "第 %d 波" % max(PlayerState.current_wave, 1)

	# 倒计时标签
	countdown_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	countdown_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
	countdown_label.text = ""

func _style_icon(panel: PanelContainer, symbol: String, bg_color: Color, border_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = UIConstants.HUD_ICON_BORDER
	style.border_width_right = UIConstants.HUD_ICON_BORDER
	style.border_width_top = UIConstants.HUD_ICON_BORDER
	style.border_width_bottom = UIConstants.HUD_ICON_BORDER
	style.corner_radius_top_left = UIConstants.HUD_ICON_CORNER
	style.corner_radius_top_right = UIConstants.HUD_ICON_CORNER
	style.corner_radius_bottom_left = UIConstants.HUD_ICON_CORNER
	style.corner_radius_bottom_right = UIConstants.HUD_ICON_CORNER
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", style)
	var label: Label = panel.get_child(0)
	label.text = symbol
	label.add_theme_font_size_override("font_size", UIConstants.HUD_ICON_FONT_SIZE)
	label.add_theme_color_override("font_color", Color.WHITE)

func _style_progress_bar(bar: ProgressBar, fill_color: Color, height: int) -> void:
	# 背景样式
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = UIConstants.COLOR_HUD_BG
	bg_style.border_color = UIConstants.COLOR_HUD_BORDER
	bg_style.border_width_left = UIConstants.HUD_ICON_BORDER
	bg_style.border_width_right = UIConstants.HUD_ICON_BORDER
	bg_style.border_width_top = UIConstants.HUD_ICON_BORDER
	bg_style.border_width_bottom = UIConstants.HUD_ICON_BORDER
	bg_style.corner_radius_top_left = UIConstants.HUD_BAR_CORNER
	bg_style.corner_radius_top_right = UIConstants.HUD_BAR_CORNER
	bg_style.corner_radius_bottom_left = UIConstants.HUD_BAR_CORNER
	bg_style.corner_radius_bottom_right = UIConstants.HUD_BAR_CORNER
	bg_style.content_margin_left = 0
	bg_style.content_margin_right = 0
	bg_style.content_margin_top = 0
	bg_style.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", bg_style)
	# 填充样式
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.corner_radius_top_left = UIConstants.HUD_BAR_CORNER
	fill_style.corner_radius_top_right = UIConstants.HUD_BAR_CORNER
	fill_style.corner_radius_bottom_left = UIConstants.HUD_BAR_CORNER
	fill_style.corner_radius_bottom_right = UIConstants.HUD_BAR_CORNER
	fill_style.content_margin_left = 0
	fill_style.content_margin_right = 0
	fill_style.content_margin_top = 0
	fill_style.content_margin_bottom = 0
	bar.add_theme_stylebox_override("fill", fill_style)
	bar.custom_minimum_size = Vector2(UIConstants.HUD_BAR_WIDTH, height)
