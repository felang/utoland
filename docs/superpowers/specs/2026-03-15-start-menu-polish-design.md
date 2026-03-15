# 开始场景完善设计

## 概述

完善开始场景（start_menu）的视觉品质和交互体验。保持简洁布局，通过渐变背景、木质 UI 主题、入场动画、交互特效和音效反馈提升第一印象。新增基础设置面板（音量 + 全屏）。

## 设计目标

- **简洁精致**：保持当前清爽布局，重点提升美术品质
- **风格统一**：混合风格 — 渐变/像素风景背景 + 木质像素风 UI（theme_1）
- **交互完整**：全方位反馈（视觉特效 + 音效）
- **功能补全**：设置按钮可用，提供基础设置

## 1. 整体布局

### 变更说明

相对于当前场景，以下节点将被**移除**：
- `SubtitleLabel`（中文副标题"类幸存者塔防射击"）

当前 `start_menu.gd` 中所有 `UIConstants` 引用将被移除，改为统一使用 `theme_1` 主题。标题的描边/发光等特殊样式通过 `add_theme_*_override()` 在代码中设置。

### 结构

```
StartMenu (Control, 全屏, theme=theme_1)
├── Background (TextureRect, stretch_mode=KEEP_ASPECT_COVERED)
│   └── texture: GradientTexture2D（渐变天空），后续替换为像素插画 PNG
├── Stars (Node2D, z_index=1)
│   └── 6-8 个子 Sprite2D（2-3px 白色小圆点），随机位置分布在上半部分
├── CenterContainer (z_index=2)
│   └── VBoxContainer
│       ├── TitleLabel — "UTOLAND"
│       ├── Spacer (Control, custom_minimum_size.y=60)
│       ├── StartButton — "开始游戏"（主按钮）
│       ├── SettingsButton — "设置"（次要按钮）
│       └── QuitButton — "退出"（次要按钮）
├── VersionLabel — "v0.1.0"（右下角, z_index=2）
└── SettingsPanel (Control, 默认 visible=false, z_index=10)
    ├── Overlay (ColorRect, 全屏, mouse_filter=MOUSE_FILTER_STOP)
    └── PanelContainer — 设置面板内容
```

### 标题

- 文字内容：`UTOLAND`
- 字体：使用 theme_1 的像素字体
- 样式：暖金色（#f0e0c0），四向描边（深棕色 #4a2800），微发光效果（rgba(255,180,60,0.3)）
- 字号：较大（对应像素字体约 32-42px），加宽字间距
- 预留后续替换为 Logo 图的可能性（替换 TitleLabel 为 TextureRect 即可）

### 背景

- **初期实现**：`GradientTexture2D` 渐变色背景（深蓝 #0a0a2e → 紫 #2d1b4e → 暖橙 #c06030，从上到下），通过 TextureRect 显示
- **后续替换**：替换 TextureRect 的 texture 为像素风景插画 PNG 即可
- 叠加星星点缀（6-8 个 Sprite2D 小圆点，随机分布在上半部分）

#### 背景插画需求（供后续采购/制作参考）

- 风格：像素风（pixel art）
- 内容：纯装饰性自然风景（森林、远山、天空渐变），黄昏/夜幕色调
- 色调：暗色系（深蓝/紫/暖橙），不要太亮以免影响 UI 可读性
- 构图：上半部分留空（天空区域，放标题），下半部分有层次感的地形/植被
- 尺寸：原始像素 384×216 或 576×324（整数倍缩放到 1152×648）
- 格式：PNG

### 按钮

- 使用 theme_1 的木质 9-patch 纹理按钮
- **主按钮**（开始游戏）：更亮的金色调，与次要按钮形成对比
- **次要按钮**（设置、退出）：暗木色调
- 宽度 240px，垂直间距 14px
- 按钮组与标题之间间距 60px
- 按钮保持键盘可聚焦（Tab 导航，Enter 触发），不破坏默认 focus 行为

### 版本号

- 位置：右下角
- 样式：小字号，低对比度颜色（#605040）

## 2. 设置面板

### 触发方式

- 点击"设置"按钮弹出

### 面板结构

```
SettingsPanel (Control, 默认 visible=false)
├── Overlay (ColorRect, 全屏, rgba(0,0,0,0.5), mouse_filter=MOUSE_FILTER_STOP)
│   └── 点击 Overlay 关闭面板，阻止输入穿透到底层按钮
└── PanelContainer (居中, 320px 宽)
    ├── TitleBar (HBoxContainer)
    │   ├── Label — "设置"
    │   └── CloseButton — "✕"
    ├── SFXVolume (VBoxContainer)
    │   ├── Label + ValueLabel — "音效音量 80%"
    │   └── HSlider — 0~100
    ├── BGMVolume (VBoxContainer)
    │   ├── Label + ValueLabel — "音乐音量 60%"
    │   └── HSlider — 0~100
    ├── HSeparator
    ├── FullscreenToggle (HBoxContainer)
    │   ├── Label — "全屏模式"
    │   └── CheckButton — toggle 开关
    └── CloseBtn (Button) — "关闭"
```

### 交互行为

- **弹出动画**：从中央缩放弹出（scale 0→1，0.2s ease-out）
- **关闭方式**：点击 ✕ 按钮 / 点击"关闭"按钮 / 点击遮罩区域
- **关闭动画**：缩放收回（scale 1→0，0.15s ease-in）
- **输入隔离**：Overlay 的 `mouse_filter = MOUSE_FILTER_STOP`，防止点击穿透到底层菜单按钮
- **焦点捕获**：面板打开时将焦点设到面板内第一个控件，关闭时恢复焦点到"设置"按钮

### 功能

- **音效音量**（HSlider）：
  - 范围 0~100，使用 `linear_to_db(value / 100.0)` 进行感知线性映射（value=0 时 mute bus）
  - 通过 `AudioManager.set_sfx_volume(value)` 调节（需新增此方法）
  - 拖拽时播放一个示例音效以便试听
  - 显示当前百分比值
- **音乐音量**（HSlider）：
  - 范围 0~100，同样使用 `linear_to_db()` 映射
  - 通过 `AudioManager.set_bgm_volume(value)` 调节（需新增此方法）
  - 显示当前百分比值
- **全屏模式**（CheckButton）：
  - 切换 `DisplayServer.window_set_mode()` 在全屏和窗口模式之间
  - 即时生效

### 视觉风格

- 面板背景：木质深色渐变，与 theme_1 风格一致
- 边框：金色调（#6b5525），与按钮统一
- 滑块和复选框使用 theme_1 主题自带样式

## 3. 交互特效

### 按钮视觉特效

theme_1 已提供 `button_normal.png`/`button_hover.png`/`button_pressed.png` 的 9-patch 纹理，Godot 会自动在 hover/press 时切换。在此基础上叠加以下效果：

| 触发时机 | 叠加效果 | 实现方式 |
|---------|---------|---------|
| hover | 放大 1.05x | Tween scale（叠加在 theme 自动切换的纹理之上） |
| press | 缩小 0.95x | Tween scale |
| release | 回到 hover 状态（1.05x） | Tween scale |

注意：每次创建新 Tween 前先 `kill()` 上一个 Tween，避免快速操作时动画冲突。扩展 `UIUtils.setup_button_hover()` 实现此逻辑。

### 入场动画

| 元素 | 动画 | 时机 |
|-----|------|-----|
| 标题 | 从上方淡入滑落到位（offset_y: -30→0, alpha: 0→1） | 场景加载后 0.2s 开始，持续 0.4s |
| 按钮组 | 依次从下方滑入（offset_y: 30→0, alpha: 0→1） | 标题动画结束后，每个按钮间隔 0.1s |
| 星星 | 渐现 | 与标题同步 |
| 版本号 | 渐现 | 按钮入场结束后 |

入场动画只在场景首次加载时播放一次。

### 星星闪烁

- 6-8 个 Sprite2D 子节点，挂在 Stars (Node2D) 下
- 使用 2-3px 的白色小圆点纹理
- 随机分布在屏幕上半部分（y < 50% 屏幕高度）
- 随机亮度脉冲：modulate.a 在 0.3~1.0 之间循环
- 每颗星星独立的随机周期（1.5~3.0s）
- 使用 Tween 循环实现（set_loops()）

## 4. 音效

### 音效清单

| 音效 ID | 触发时机 | 描述 |
|--------|---------|------|
| ui_hover | 按钮悬停 | 轻柔的 tick，像素风木质轻敲 |
| ui_click | 按钮点击 | 明确的 click，木质按压确认感 |
| ui_panel_open | 设置面板弹出 | 轻柔的展开音 |
| ui_panel_close | 设置面板关闭 | 轻柔的收回音 |

### 音效资源

- 格式：.wav 或 .ogg
- 风格：8-bit 像素风短促音效
- 存放目录：`assets/sfx/`
- 在 AudioManager 中注册对应 sound_id
- 如暂无资源，可先用占位音效后续替换

## 5. 技术要点

### AudioManager 扩展

需要为 AudioManager 新增音量控制 API：

1. **新增音频总线**：在 Godot 项目设置中添加 `SFX` 和 `BGM` 两个子总线（挂在 Master 下）
2. **AudioManager 新增方法**：
   - `set_sfx_volume(value: float)` — value 0~100，内部用 `linear_to_db(value / 100.0)` 转换后设置 SFX 总线音量，value=0 时 mute
   - `set_bgm_volume(value: float)` — 同上，设置 BGM 总线音量
   - `get_sfx_volume() -> float` — 返回当前 SFX 音量（0~100）
   - `get_bgm_volume() -> float` — 返回当前 BGM 音量（0~100）
3. **现有播放方法调整**：SFX AudioStreamPlayer 输出到 SFX 总线，BGM AudioStreamPlayer 输出到 BGM 总线

### 文件变更

| 文件 | 变更内容 |
|-----|---------|
| `scenes/ui/start_menu.tscn` | 重构场景树：移除 SubtitleLabel；新增 Stars (Node2D + Sprite2D 子节点)、SettingsPanel 节点树；Background 改为 TextureRect；Spacer 用 Control(min_size.y=60)；根节点设置 theme=theme_1 |
| `scripts/ui/start_menu.gd` | 移除所有 UIConstants 引用；新增入场动画、星星闪烁、设置面板开关逻辑、音效播放、音量/全屏控制 |
| `scripts/ui/ui_utils.gd` | 扩展 `setup_button_hover()`：添加 Tween kill 防冲突，新增音效播放（ui_hover, ui_click） |
| `scripts/systems/audio_manager.gd` | 注册新音效 ID（ui_hover, ui_click, ui_panel_open, ui_panel_close）；新增 set/get_sfx_volume、set/get_bgm_volume 方法；SFX/BGM 播放器分别输出到对应总线 |
| `project.godot` | 新增 SFX、BGM 音频总线配置 |

### 注意事项

- 设置面板作为 start_menu 场景的子节点，不单独成为场景
- 音量设置值目前不需要持久化存储（重启游戏恢复默认值），后续可加 ConfigFile 持久化
- theme_1 主题应用到 start_menu 场景根节点，子节点自动继承
- Stars 使用 z_index=1 确保在背景之上、UI 之下正确渲染
- 所有音量调节通过 AudioManager 接口，不直接调用 AudioServer
