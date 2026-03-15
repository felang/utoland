# 开始场景完善 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完善开始场景的视觉品质和交互体验——渐变背景、theme_1 木质主题、入场动画、按钮音效特效、设置面板（音量+全屏）。

**Architecture:** 基于现有 start_menu 场景重构。AudioManager 扩展 SFX/BGM 分总线和音量控制 API。UIUtils 扩展按钮 hover 音效和 Tween 防冲突。设置面板作为 start_menu 子节点，不独立成场景。

**Tech Stack:** Godot 4.6 / GDScript / GUT 测试框架

**Spec:** `docs/superpowers/specs/2026-03-15-start-menu-polish-design.md`

---

## Chunk 1: AudioManager 扩展（SFX/BGM 分总线 + 音量控制）

### Task 1: 创建 SFX/BGM 音频总线

**Files:**
- Create: `default_bus_layout.tres`（项目根目录，Godot 音频总线布局文件）

**Context:** Godot 默认只有 Master 总线。需要添加 SFX 和 BGM 两个子总线，让 AudioManager 的 SFX 播放器和 BGM 播放器分别输出到不同总线，从而实现独立音量控制。

- [ ] **Step 1: 通过 Godot 编辑器创建音频总线布局**

在 Godot 编辑器底部的"音频"面板中：
1. 点击"添加总线"，命名为 `SFX`
2. 再点击"添加总线"，命名为 `BGM`
3. 两个总线都保持默认设置（输出到 Master）
4. 保存（Godot 会自动保存到 `default_bus_layout.tres`）

如果无法通过编辑器操作，手动创建文件：

```tres
[gd_resource type="AudioBusLayout" format=3]

[resource]
bus/1/name = &"SFX"
bus/1/solo = false
bus/1/mute = false
bus/1/bypass_fx = false
bus/1/volume_db = 0.0
bus/1/send = &"Master"
bus/2/name = &"BGM"
bus/2/solo = false
bus/2/mute = false
bus/2/bypass_fx = false
bus/2/volume_db = 0.0
bus/2/send = &"Master"
```

- [ ] **Step 2: 验证总线存在**

在 Godot 编辑器底部"音频"面板确认显示 3 个总线：Master、SFX、BGM。

- [ ] **Step 3: Commit**

```bash
git add default_bus_layout.tres
git commit -m "chore: 添加 SFX 和 BGM 音频总线"
```

---

### Task 2: AudioManager 新增音量控制 API 和总线分配

**Files:**
- Modify: `scripts/systems/audio_manager.gd`
- Modify: `tests/unit/test_audio_manager.gd`

**Context:** 当前 AudioManager 所有播放器都输出到 Master 总线。需要：(1) SFX 播放器池输出到 SFX 总线，BGM 播放器输出到 BGM 总线；(2) 新增 set/get_sfx_volume、set/get_bgm_volume 方法；(3) 注册 4 个新 UI 音效 ID。

- [ ] **Step 1: 写音量控制的测试**

在 `tests/unit/test_audio_manager.gd` 末尾添加：

```gdscript
func test_sfx_pool_uses_sfx_bus():
	for player: AudioStreamPlayer in audio_manager._pool:
		assert_eq(player.bus, "SFX", "SFX 播放器应输出到 SFX 总线")

func test_bgm_player_uses_bgm_bus():
	assert_eq(audio_manager._bgm_player.bus, "BGM", "BGM 播放器应输出到 BGM 总线")

func test_set_sfx_volume():
	audio_manager.set_sfx_volume(50.0)
	var expected_db: float = linear_to_db(0.5)
	var bus_idx: int = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		assert_almost_eq(AudioServer.get_bus_volume_db(bus_idx), expected_db, 0.1, "SFX 音量应设为 50%")

func test_set_sfx_volume_zero_mutes():
	audio_manager.set_sfx_volume(0.0)
	var bus_idx: int = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		assert_true(AudioServer.is_bus_mute(bus_idx), "音量为 0 时应静音")

func test_set_bgm_volume():
	audio_manager.set_bgm_volume(75.0)
	var expected_db: float = linear_to_db(0.75)
	var bus_idx: int = AudioServer.get_bus_index("BGM")
	if bus_idx >= 0:
		assert_almost_eq(AudioServer.get_bus_volume_db(bus_idx), expected_db, 0.1, "BGM 音量应设为 75%")

func test_get_sfx_volume_default():
	var vol: float = audio_manager.get_sfx_volume()
	assert_eq(vol, 100.0, "默认 SFX 音量应为 100")

func test_get_bgm_volume_default():
	var vol: float = audio_manager.get_bgm_volume()
	assert_eq(vol, 100.0, "默认 BGM 音量应为 100")

func test_ui_sound_ids_no_crash():
	audio_manager.play("ui_hover")
	audio_manager.play("ui_click")
	audio_manager.play("ui_panel_open")
	audio_manager.play("ui_panel_close")
	assert_true(true, "UI 音效调用不应崩溃")
```

- [ ] **Step 2: 运行测试验证失败**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_audio_manager.gd
```

Expected: 新增的测试失败（bus 不是 SFX/BGM，方法不存在）。

- [ ] **Step 3: 修改 AudioManager 实现**

在 `scripts/systems/audio_manager.gd` 中：

1. 在文件顶部变量区新增：

```gdscript
var _sfx_volume: float = 100.0
var _bgm_volume: float = 100.0
```

2. 修改 `_create_pool()` 中 `player.bus = "Master"` 改为 `player.bus = "SFX"`。

3. 修改 `_create_bgm_player()` 中 `_bgm_player.bus = "Master"` 改为 `_bgm_player.bus = "BGM"`。

4. 在 `_register_sounds()` 的 `sound_map` 字典中添加 4 个 UI 音效：

```gdscript
"ui_hover": "ui_hover.wav",
"ui_click": "ui_click.wav",
"ui_panel_open": "ui_panel_open.wav",
"ui_panel_close": "ui_panel_close.wav",
```

5. 在文件末尾（公共方法区域）添加音量控制方法：

```gdscript
func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 100.0)
	var bus_idx: int = AudioServer.get_bus_index("SFX")
	if bus_idx < 0:
		return
	if _sfx_volume <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(_sfx_volume / 100.0))

func get_sfx_volume() -> float:
	return _sfx_volume

func set_bgm_volume(value: float) -> void:
	_bgm_volume = clampf(value, 0.0, 100.0)
	var bus_idx: int = AudioServer.get_bus_index("BGM")
	if bus_idx < 0:
		return
	if _bgm_volume <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(_bgm_volume / 100.0))

func get_bgm_volume() -> float:
	return _bgm_volume
```

- [ ] **Step 4: 运行测试验证通过**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_audio_manager.gd
```

Expected: 所有测试 PASS。注意：如果 SFX/BGM 总线在 headless 模式下不存在（因为 `default_bus_layout.tres` 可能未加载），总线相关测试中的 `if bus_idx >= 0` 会跳过断言——这是可接受的。

- [ ] **Step 5: Commit**

```bash
git add scripts/systems/audio_manager.gd tests/unit/test_audio_manager.gd
git commit -m "feat: AudioManager 添加 SFX/BGM 分总线和音量控制 API"
```

---

### Task 2.5: 添加占位 UI 音效文件

**Files:**
- Create: `assets/sfx/ui_hover.wav`
- Create: `assets/sfx/ui_click.wav`
- Create: `assets/sfx/ui_panel_open.wav`
- Create: `assets/sfx/ui_panel_close.wav`

**Context:** AudioManager 的 `_register_sounds()` 只注册 `ResourceLoader.exists(path)` 为 true 的音效。如果没有实际文件，4 个 UI 音效 ID 不会被注册，`play()` 调用会静默无效。需要添加占位音效文件。

- [ ] **Step 1: 添加占位音效**

方案 A（推荐）：从已有的 `assets/sfx/` 中复制一个短促音效作为占位：
```bash
cp assets/sfx/coin_pickup.wav assets/sfx/ui_hover.wav
cp assets/sfx/coin_pickup.wav assets/sfx/ui_click.wav
cp assets/sfx/coin_pickup.wav assets/sfx/ui_panel_open.wav
cp assets/sfx/coin_pickup.wav assets/sfx/ui_panel_close.wav
```

方案 B：如果有合适的 8-bit UI 音效素材，直接放入。

后续可替换为正式的像素风 UI 音效。

- [ ] **Step 2: 在 Godot 编辑器中重新导入**

打开 Godot 编辑器让其自动扫描并生成 `.import` 文件。

- [ ] **Step 3: Commit**

```bash
git add assets/sfx/ui_*.wav
git commit -m "chore: 添加占位 UI 音效文件"
```

---

## Chunk 2: UIUtils 扩展 + 场景重构

### Task 3: UIUtils 添加 Tween 防冲突和音效

**Files:**
- Modify: `scripts/ui/ui_utils.gd`
- Modify: `tests/unit/test_ui_utils.gd`

**Context:** 当前 `setup_button_hover()` 每次交互都创建新 Tween 但不 kill 旧的，快速操作会导致动画冲突。需要：(1) 用 meta 存储 Tween 引用并在创建新 Tween 前 kill 旧的；(2) 在 hover/click 时播放音效。

- [ ] **Step 1: 写 Tween 防冲突和音效的测试**

在 `tests/unit/test_ui_utils.gd` 末尾添加：

```gdscript
func test_setup_button_hover_connects_button_down():
	var btn := Button.new()
	add_child(btn)
	UIUtils.setup_button_hover(btn)
	assert_true(btn.button_down.get_connections().size() > 0, "应连接 button_down")
	btn.queue_free()

func test_setup_button_hover_connects_button_up():
	var btn := Button.new()
	add_child(btn)
	UIUtils.setup_button_hover(btn)
	assert_true(btn.button_up.get_connections().size() > 0, "应连接 button_up")
	btn.queue_free()

func test_setup_button_hover_stores_tween_meta():
	var btn := Button.new()
	add_child(btn)
	UIUtils.setup_button_hover(btn)
	# 触发 mouse_entered 后应有 tween meta
	btn.emit_signal("mouse_entered")
	await get_tree().process_frame
	assert_true(btn.has_meta("_hover_tween"), "应存储 _hover_tween meta")
	btn.queue_free()
```

- [ ] **Step 2: 运行测试验证失败**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_ui_utils.gd
```

Expected: `test_setup_button_hover_stores_tween_meta` 失败（当前代码不存储 meta）。

- [ ] **Step 3: 重写 UIUtils.setup_button_hover()**

将 `scripts/ui/ui_utils.gd` 全部替换为：

```gdscript
class_name UIUtils

## 按钮 hover/press 缩放动效 + 音效
## pivot_offset 在每次交互时动态更新，因为 _ready 时 size 可能还是 Vector2.ZERO
static func setup_button_hover(button: Button) -> void:
	button.mouse_entered.connect(func() -> void:
		button.pivot_offset = button.size / 2
		_kill_hover_tween(button)
		var tw: Tween = button.create_tween()
		button.set_meta("_hover_tween", tw)
		tw.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)
		AudioManager.play("ui_hover", -10.0)
	)
	button.mouse_exited.connect(func() -> void:
		_kill_hover_tween(button)
		var tw: Tween = button.create_tween()
		button.set_meta("_hover_tween", tw)
		tw.tween_property(button, "scale", Vector2.ONE, 0.1)
	)
	button.button_down.connect(func() -> void:
		_kill_hover_tween(button)
		var tw: Tween = button.create_tween()
		button.set_meta("_hover_tween", tw)
		tw.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)
		AudioManager.play("ui_click")
	)
	button.button_up.connect(func() -> void:
		_kill_hover_tween(button)
		var tw: Tween = button.create_tween()
		button.set_meta("_hover_tween", tw)
		tw.tween_property(button, "scale", Vector2(1.05, 1.05), 0.05)
	)


static func _kill_hover_tween(button: Button) -> void:
	if button.has_meta("_hover_tween"):
		var old_tw: Tween = button.get_meta("_hover_tween")
		if old_tw and old_tw.is_valid():
			old_tw.kill()
```

- [ ] **Step 4: 运行测试验证通过**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_ui_utils.gd
```

Expected: 所有测试 PASS。

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/ui_utils.gd tests/unit/test_ui_utils.gd
git commit -m "feat: UIUtils 添加 Tween 防冲突和按钮音效"
```

---

### Task 4: 重构 start_menu 场景文件

**Files:**
- Modify: `scenes/ui/start_menu.tscn`

**Context:** 需要重构场景树：移除 SubtitleLabel；Background 从 ColorRect 改为 TextureRect + GradientTexture2D；新增 Stars (Node2D)；Spacer 调整为 60px；按钮调整为 240px 宽；新增 SettingsPanel 节点树；根节点设置 theme=theme_1。

由于 `.tscn` 文件手动编辑容易出错，建议通过 Godot MCP 工具操作。以下列出需要执行的操作：

- [ ] **Step 1: 通过 MCP 打开 start_menu 场景并修改结构**

1. 打开场景 `res://scenes/ui/start_menu.tscn`
2. **删除** SubtitleLabel 节点
3. **修改** 根节点 StartMenu：设置 theme 属性为 `res://assets/themes/theme_1/theme_1.tres`
4. **修改** Background 节点：类型从 ColorRect 改为 TextureRect（或删除旧的 ColorRect 并新建 TextureRect），设置 stretch_mode=KEEP_ASPECT_COVERED，texture 设为 GradientTexture2D（深蓝→紫→暖橙渐变）
5. **新增** Stars (Node2D) 作为根节点的子节点，z_index=1
6. **修改** CenterContainer：设置 z_index=2
7. **修改** Spacer：custom_minimum_size 从 Vector2(0, 30) 改为 Vector2(0, 60)
8. **修改** 三个按钮：custom_minimum_size 从 Vector2(200, 44) 改为 Vector2(240, 44)
9. **修改** VBoxContainer：theme_override_constants/separation 从 20 改为 14
10. **修改** TitleLabel：text 从 "Survivor Tower Defense" 改为 "UTOLAND"
11. **修改** VersionLabel：设置 z_index=2
12. **新增** SettingsPanel 节点树（见下方结构）

SettingsPanel 结构：
```
SettingsPanel (Control, visible=false, z_index=10, anchors_preset=15 全屏)
├── Overlay (ColorRect, anchors_preset=15 全屏, color=rgba(0,0,0,0.5), mouse_filter=STOP)
└── CenterContainer (anchors_preset=15 全屏)
    └── PanelContainer (custom_minimum_size=Vector2(320, 0))
        └── MarginContainer (margin 16px)
            └── VBoxContainer (separation=12)
                ├── TitleBar (HBoxContainer)
                │   ├── SettingsTitleLabel (Label, text="设置", size_flags_horizontal=EXPAND_FILL)
                │   └── CloseXButton (Button, text="✕", custom_minimum_size=Vector2(32, 32))
                ├── SFXSection (VBoxContainer)
                │   ├── SFXHeader (HBoxContainer)
                │   │   ├── SFXLabel (Label, text="音效音量")
                │   │   └── SFXValueLabel (Label, text="100%", horizontal_alignment=RIGHT, size_flags_horizontal=EXPAND_FILL)
                │   └── SFXSlider (HSlider, min_value=0, max_value=100, value=100, step=1)
                ├── BGMSection (VBoxContainer)
                │   ├── BGMHeader (HBoxContainer)
                │   │   ├── BGMLabel (Label, text="音乐音量")
                │   │   └── BGMValueLabel (Label, text="100%", horizontal_alignment=RIGHT, size_flags_horizontal=EXPAND_FILL)
                │   └── BGMSlider (HSlider, min_value=0, max_value=100, value=100, step=1)
                ├── HSeparator
                ├── FullscreenRow (HBoxContainer)
                │   ├── FullscreenLabel (Label, text="全屏模式", size_flags_horizontal=EXPAND_FILL)
                │   └── FullscreenCheck (CheckButton)
                └── CloseButton (Button, text="关闭")
```

- [ ] **Step 2: 保存场景并验证**

在 Godot 编辑器中保存场景，确认场景树结构正确、无错误。

- [ ] **Step 3: Commit**

```bash
git add scenes/ui/start_menu.tscn
git commit -m "refactor: 重构 start_menu 场景树结构"
```

---

### Task 5: 重写 start_menu.gd 脚本

**Files:**
- Modify: `scripts/ui/start_menu.gd`

**Context:** 完全重写脚本：移除 UIConstants 引用，使用 theme_1 主题；新增标题样式、入场动画、星星创建与闪烁、设置面板逻辑。

- [ ] **Step 1: 重写 start_menu.gd**

```gdscript
extends Control

## 开始菜单 — 标题、按钮、入场动画、设置面板

const STAR_COUNT: int = 7
const STAR_MIN_ALPHA: float = 0.3
const STAR_MAX_ALPHA: float = 1.0
const STAR_MIN_PERIOD: float = 1.5
const STAR_MAX_PERIOD: float = 3.0

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
	_setup_title_style()
	_setup_version_style()
	_setup_buttons()
	_create_stars()
	_setup_settings_panel()
	_play_entrance_animation()


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
		# 创建小圆点纹理
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
	# 注意：规格中设计了位移滑入动画（offset_y），但 VBoxContainer 布局下子节点
	# position 由容器管理，手动修改 position 会与布局冲突。因此改为纯淡入动画。
	# 初始状态：全部透明
	_title_label.modulate.a = 0.0
	_stars.modulate.a = 0.0
	_version_label.modulate.a = 0.0

	var buttons: Array[Button] = [_start_button, _settings_button, _quit_button]
	for btn in buttons:
		btn.modulate.a = 0.0

	# 入场序列
	var tw: Tween = create_tween()

	# 0.2s 后标题淡入
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

	# 信号连接
	_overlay.gui_input.connect(_on_overlay_input)
	_close_x_button.pressed.connect(_close_settings)
	_close_button.pressed.connect(_close_settings)
	UIUtils.setup_button_hover(_close_x_button)
	UIUtils.setup_button_hover(_close_button)

	# 滑块信号
	_sfx_slider.value = AudioManager.get_sfx_volume()
	_bgm_slider.value = AudioManager.get_bgm_volume()
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_bgm_slider.value_changed.connect(_on_bgm_volume_changed)

	# 全屏检查
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
```

- [ ] **Step 2: 运行场景验证**

通过 MCP 或 Godot 编辑器运行 start_menu 场景，确认：
1. 标题 "UTOLAND" 有描边和发光效果
2. 星星闪烁正常
3. 入场动画流畅（淡入序列）
4. 按钮 hover/click 有缩放效果
5. 设置面板弹出/关闭正常
6. 滑块调节音量正常
7. 全屏切换正常

注意：渐变背景在 Task 6 中添加，此阶段 Background 可能显示为空白。

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/start_menu.gd
git commit -m "feat: 重写 start_menu 脚本 — 入场动画、星星、设置面板"
```

---

## Chunk 3: 背景渐变 + 全量测试 + 收尾

### Task 6: 创建渐变背景纹理

**Files:**
- 修改场景中 Background 节点的 texture 属性

**Context:** Background TextureRect 需要一个 GradientTexture2D 作为渐变背景。可以通过 Godot 编辑器 UI 创建，或通过代码在 `_ready()` 中动态创建。

由于 GradientTexture2D 在 `.tscn` 中内联较复杂，**推荐在 start_menu.gd 的 `_ready()` 中动态创建**。

- [ ] **Step 1: 在 start_menu.gd 中添加背景创建逻辑**

在 `@onready` 区域添加：

```gdscript
@onready var _background: TextureRect = $Background
```

在 `_ready()` 的最前面（`_setup_title_style()` 之前）添加调用：

```gdscript
_setup_background()
```

在 `_setup_title_style()` 前面添加方法：

```gdscript
func _setup_background() -> void:
	var gradient := Gradient.new()
	# 清除默认点，从头构建
	while gradient.get_point_count() > 0:
		gradient.remove_point(0)
	gradient.add_point(0.0, Color("#0a0a2e"))
	gradient.add_point(0.25, Color("#1a1040"))
	gradient.add_point(0.45, Color("#2d1b4e"))
	gradient.add_point(0.65, Color("#4a2040"))
	gradient.add_point(0.85, Color("#8b4020"))
	gradient.add_point(1.0, Color("#c06030"))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 2
	tex.height = 648
	_background.texture = tex
```

- [ ] **Step 2: 运行场景验证渐变效果**

运行 start_menu 场景，确认渐变从深蓝到暖橙平滑过渡。

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/start_menu.gd
git commit -m "feat: 添加渐变天空背景"
```

---

### Task 7: 运行全量测试

**Files:** 无修改

- [ ] **Step 1: 运行全量测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 所有测试通过（595+ tests）。如有失败，排查修复。

- [ ] **Step 2: 修复失败测试（如有）**

常见可能的失败：
- `test_ui_constants.gd` — 如果测试了 start_menu 中 UIConstants 的使用，需要更新
- 其他引用 SubtitleLabel 的测试 — 需要移除

- [ ] **Step 3: Commit 修复（如有）**

```bash
git add -A
git commit -m "fix: 修复全量测试中的兼容性问题"
```

---

### Task 8: 手动验收测试

**Files:** 无修改

- [ ] **Step 1: 完整游戏流程测试**

运行游戏主场景（或从 start_menu 开始），验证：

1. **开始场景**
   - 渐变背景正确显示（深蓝→紫→暖橙）
   - 标题 "UTOLAND" 显示正确（金色、描边、居中）
   - 星星闪烁（上半部分，6-7 个）
   - 入场动画：标题淡入 → 按钮依次淡入 → 版本号渐现
   - 按钮使用 theme_1 木质纹理
   - hover 时放大 + 音效 tick
   - click 时缩小 + 音效 click
   - "开始游戏" 按钮正确跳转到角色选择

2. **设置面板**
   - 点击"设置"按钮弹出面板（缩放动画 + 展开音效）
   - 音效音量滑块可拖拽，数值更新
   - 音乐音量滑块可拖拽，数值更新
   - 全屏切换正常
   - 点击 ✕ / 关闭 / 遮罩 均可关闭（收回动画 + 关闭音效）
   - 面板打开时底层按钮不可点击

3. **后续流程不受影响**
   - 角色选择 → 地图选择 → 主游戏 流程正常

- [ ] **Step 2: 确认完成**

所有验收项通过后，最终 commit（如有任何微调）。
