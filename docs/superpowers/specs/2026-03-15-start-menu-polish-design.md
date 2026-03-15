# 开始场景完善设计

## 概述

完善开始场景（start_menu）的视觉品质和交互体验。保持简洁布局，通过渐变背景、木质 UI 主题、入场动画、交互特效和音效反馈提升第一印象。新增基础设置面板（音量 + 全屏）。

## 设计目标

- **简洁精致**：保持当前清爽布局，重点提升美术品质
- **风格统一**：混合风格 — 渐变/像素风景背景 + 木质像素风 UI（theme_1）
- **交互完整**：全方位反馈（视觉特效 + 音效）
- **功能补全**：设置按钮可用，提供基础设置

## 1. 整体布局

### 结构

```
StartMenu (Control, 全屏)
├── Background (TextureRect 或 ColorRect)
│   └── 渐变天空背景，预留后续替换为像素插画
├── Stars (Node2D)
│   └── 多个小圆点，随机闪烁动画
├── CenterContainer
│   └── VBoxContainer
│       ├── TitleLabel — "UTOLAND"
│       ├── Spacer — 60px 间距
│       ├── StartButton — "开始游戏"（主按钮）
│       ├── SettingsButton — "设置"（次要按钮）
│       └── QuitButton — "退出"（次要按钮）
├── VersionLabel — "v0.1.0"（右下角）
└── SettingsPanel (Control, 默认隐藏)
    ├── Overlay — 半透明黑色遮罩
    └── PanelContainer — 设置面板内容
```

### 标题

- 文字内容：`UTOLAND`
- 字体：使用 theme_1 的像素字体
- 样式：暖金色（#f0e0c0），四向描边（深棕色 #4a2800），微发光效果（rgba(255,180,60,0.3)）
- 字号：较大（对应像素字体约 32-42px），加宽字间距
- 预留后续替换为 Logo 图的可能性（替换 TitleLabel 为 TextureRect 即可）

### 背景

- **初期实现**：代码生成的渐变色背景（深蓝 #0a0a2e → 紫 #2d1b4e → 暖橙 #c06030，从上到下）
- **后续替换**：替换为像素风景插画 PNG，作为 TextureRect 铺满屏幕
- 叠加星星点缀（6-8 个小圆点，随机分布在上半部分）

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

### 版本号

- 位置：右下角
- 样式：小字号，低对比度颜色（#605040）

## 2. 设置面板

### 触发方式

- 点击"设置"按钮弹出

### 面板结构

```
SettingsPanel (Control, 默认 visible=false)
├── Overlay (ColorRect, 全屏, rgba(0,0,0,0.5))
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

### 功能

- **音效音量**（HSlider）：
  - 范围 0~100，对应 AudioServer bus volume -80~0 dB
  - 拖拽时实时调节 AudioManager SFX 音量
  - 拖拽时播放一个示例音效以便试听
  - 显示当前百分比值
- **音乐音量**（HSlider）：
  - 范围 0~100，对应 AudioServer bus volume -80~0 dB
  - 拖拽时实时调节 AudioManager BGM 音量
  - 显示当前百分比值
- **全屏模式**（CheckButton）：
  - 切换 `DisplayServer.window_set_mode()` 在全屏和窗口模式之间
  - 即时生效

### 视觉风格

- 面板背景：木质深色渐变，与 theme_1 风格一致
- 边框：金色调（#6b5525），与按钮统一
- 滑块轨道：深色凹槽（#1a1008）
- 滑块填充：金色渐变（#8b6914 → #a07818）
- 使用 theme_1 主题的 HSlider 和 CheckButton 样式

## 3. 交互特效

### 按钮视觉特效

| 触发时机 | 效果 | 实现方式 |
|---------|------|---------|
| hover | 放大 1.05x + 边框变亮 + 外发光光晕 | Tween scale + StyleBox 动态切换 |
| press | 缩小 0.95x + 背景变暗 + 内凹阴影 | Tween scale + pressed StyleBox |
| release | 回到 hover 状态（1.05x） | Tween scale |

### 入场动画

| 元素 | 动画 | 时机 |
|-----|------|-----|
| 标题 | 从上方淡入滑落到位（offset_y: -30→0, alpha: 0→1） | 场景加载后 0.2s 开始，持续 0.4s |
| 按钮组 | 依次从下方滑入（offset_y: 30→0, alpha: 0→1） | 标题动画结束后，每个按钮间隔 0.1s |
| 星星 | 渐现 | 与标题同步 |
| 版本号 | 渐现 | 按钮入场结束后 |

### 星星闪烁

- 6-8 个小圆点随机分布在背景上半部分
- 随机亮度脉冲：alpha 在 0.3~1.0 之间循环
- 每颗星星独立的随机周期（1.5~3.0s）
- 使用 Tween 循环实现

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

### 文件变更

- `scripts/ui/start_menu.gd` — 主要修改：布局重构、入场动画、星星闪烁、设置面板逻辑
- `scenes/ui/start_menu.tscn` — 场景结构调整：新增 Stars、SettingsPanel 等节点
- `scripts/ui/ui_utils.gd` — 可能扩展：增强 hover 效果（光晕）、入场动画工具方法
- `scripts/systems/audio_manager.gd` — 注册新音效 ID（ui_hover, ui_click, ui_panel_open, ui_panel_close）

### 注意事项

- 设置面板作为 start_menu 场景的子节点，不单独成为场景
- 音量设置值目前不需要持久化存储（重启游戏恢复默认值），后续可加 ConfigFile 持久化
- 背景渐变使用 `_draw()` 或预生成 GradientTexture2D 实现
- 入场动画只在场景首次加载时播放一次
- theme_1 主题应用到整个 start_menu 场景的根节点
