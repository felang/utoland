extends Control

## 开始菜单 — 标题、按钮、入场动画、设置面板

const STAR_COUNT: int = 7
const STAR_MIN_ALPHA: float = 0.3
const STAR_MAX_ALPHA: float = 1.0
const STAR_MIN_PERIOD: float = 1.5
const STAR_MAX_PERIOD: float = 3.0

@onready var _background: TextureRect = $Background
@onready var _title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var _start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var _settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var _quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var _version_label: Label = $VersionLabel
@onready var _stars: Node2D = $Stars
@onready var _settings_panel: Control = $SettingsPanel
@onready var _overlay: ColorRect = $SettingsPanel/Overlay
@onready var _panel_container: PanelContainer = $SettingsPanel/CenterContainer/PanelContainer
@onready var _sfx_slider: HSlider = $SettingsPanel/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SFXSection/SFXSlider
@onready var _sfx_value_label: Label = $SettingsPanel/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SFXSection/SFXHeader/SFXValueLabel
@onready var _bgm_slider: HSlider = $SettingsPanel/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BGMSection/BGMSlider
@onready var _bgm_value_label: Label = $SettingsPanel/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BGMSection/BGMHeader/BGMValueLabel
@onready var _fullscreen_check: CheckButton = $SettingsPanel/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/FullscreenRow/FullscreenCheck
@onready var _close_x_button: Button = $SettingsPanel/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleBar/CloseXButton
@onready var _close_button: Button = $SettingsPanel/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CloseButton

var _panel_tween: Tween


func _ready() -> void:
	_setup_background()
	_setup_title_style()
	_setup_version_style()
	_setup_buttons()
	_create_stars()
	_setup_settings_panel()
	_play_entrance_animation()


# --- 背景 ---

func _setup_background() -> void:
	var gradient := Gradient.new()
	# 默认 Gradient 有 2 个点（0 和 1），直接设置首尾颜色，中间用 add_point
	gradient.set_color(0, Color("#0a0a2e"))
	gradient.set_color(1, Color("#c06030"))
	gradient.add_point(0.25, Color("#1a1040"))
	gradient.add_point(0.45, Color("#2d1b4e"))
	gradient.add_point(0.65, Color("#4a2040"))
	gradient.add_point(0.85, Color("#8b4020"))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 2
	tex.height = 648
	_background.texture = tex


# --- 标题样式 ---

func _setup_title_style() -> void:
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", Color("#f0e0c0"))
	_title_label.add_theme_color_override("font_outline_color", Color("#4a2800"))
	_title_label.add_theme_constant_override("outline_size", 6)
	_title_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.7, 0.24, 0.3))
	_title_label.add_theme_constant_override("shadow_offset_x", 0)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)


# --- 版本号样式 ---

func _setup_version_style() -> void:
	_version_label.add_theme_color_override("font_color", Color("#605040"))


# --- 按钮设置 ---

func _setup_buttons() -> void:
	for btn_name in ["StartButton", "SettingsButton", "QuitButton"]:
		var btn: Button = $CenterContainer/VBoxContainer.get_node(btn_name)
		UIUtils.setup_button_hover(btn)

	_start_button.pressed.connect(_on_start_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(func() -> void: get_tree().quit())


func _on_start_pressed() -> void:
	SceneManager.go_to(Enums.Scene.CHARACTER_SELECTION)


# --- 星星 ---

func _create_stars() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	for i in STAR_COUNT:
		var star := Sprite2D.new()
		var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		var tex := ImageTexture.create_from_image(img)
		star.texture = tex
		star.position = Vector2(
			randf_range(20, viewport_size.x - 20),
			randf_range(20, viewport_size.y * 0.5)
		)
		star.modulate.a = randf_range(STAR_MIN_ALPHA, STAR_MAX_ALPHA)
		_stars.add_child(star)
		_start_star_twinkle(star)


func _start_star_twinkle(star: Sprite2D) -> void:
	var period: float = randf_range(STAR_MIN_PERIOD, STAR_MAX_PERIOD)
	var tw: Tween = create_tween().set_loops()
	tw.tween_property(star, "modulate:a", STAR_MIN_ALPHA, period / 2.0)
	tw.tween_property(star, "modulate:a", STAR_MAX_ALPHA, period / 2.0)


# --- 入场动画 ---

func _play_entrance_animation() -> void:
	# VBoxContainer 布局下子节点 position 由容器管理，因此使用纯淡入动画
	_title_label.modulate.a = 0.0
	_stars.modulate.a = 0.0
	_version_label.modulate.a = 0.0

	var buttons: Array[Button] = [_start_button, _settings_button, _quit_button]
	for btn in buttons:
		btn.modulate.a = 0.0

	var tw: Tween = create_tween()

	# 标题和星星淡入
	tw.tween_interval(0.2)
	tw.tween_property(_title_label, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(_stars, "modulate:a", 1.0, 0.4)

	# 按钮依次淡入
	for btn in buttons:
		tw.tween_interval(0.1)
		tw.tween_property(btn, "modulate:a", 1.0, 0.3)

	# 版本号渐现
	tw.tween_interval(0.1)
	tw.tween_property(_version_label, "modulate:a", 1.0, 0.3)


# --- 设置面板 ---

func _setup_settings_panel() -> void:
	_settings_panel.visible = false

	_overlay.gui_input.connect(_on_overlay_input)
	_close_x_button.pressed.connect(_close_settings)
	_close_button.pressed.connect(_close_settings)
	UIUtils.setup_button_hover(_close_x_button)
	UIUtils.setup_button_hover(_close_button)

	_sfx_slider.value = AudioManager.get_sfx_volume()
	_bgm_slider.value = AudioManager.get_bgm_volume()
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_bgm_slider.value_changed.connect(_on_bgm_volume_changed)

	_fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)


func _on_settings_pressed() -> void:
	_open_settings()


func _open_settings() -> void:
	_settings_panel.visible = true
	_panel_container.pivot_offset = _panel_container.size / 2
	_panel_container.scale = Vector2.ZERO

	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()
	_panel_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_panel_tween.tween_property(_panel_container, "scale", Vector2.ONE, 0.2)

	AudioManager.play("ui_panel_open")
	_sfx_slider.grab_focus()


func _close_settings() -> void:
	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()
	_panel_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	_panel_tween.tween_property(_panel_container, "scale", Vector2.ZERO, 0.15)
	_panel_tween.tween_callback(func() -> void:
		_settings_panel.visible = false
	)

	AudioManager.play("ui_panel_close")
	_settings_button.grab_focus()


func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_settings()


func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)
	_sfx_value_label.text = "%d%%" % int(value)
	AudioManager.play("ui_click")


func _on_bgm_volume_changed(value: float) -> void:
	AudioManager.set_bgm_volume(value)
	_bgm_value_label.text = "%d%%" % int(value)


func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
