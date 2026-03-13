# 体验打磨与 Bug 修复设计

## 概述

先修复已知 Bug，然后对游戏进行体验打磨：打击感增强、UI 动效、音效与 BGM 系统。新增功能尽量扩展现有系统（EffectsManager、AudioManager、EventBus、SceneManager），不新建 Autoload。

## Part 1: Bug 修复

### 1.1 Sunflower 产金事件未接收

**问题**: TowerGenerator（sunflower）定时发出 `EventBus.coins_generated` 信号，但 `main.gd` 未监听该信号，导致产金无效。

**修复方案**:
- `main.gd` 中监听 `EventBus.coins_generated` 信号（信号参数包含 `amount: int` 和 `position: Vector2`）
- 回调中直接更新 `GameData.coins += amount` 并调用 `GameData.add_xp(amount)` 给予经验值
- 同时用 `SceneFactory.create_coin()` 在产金位置生成金币实体作为视觉反馈（自动收集，不重复加金币）
- 注意：`GameData` 没有 `add_coins()` 方法，`player.add_coins()` 方法在 player.gd 中，但 main.gd 可直接操作 GameData

**需修改的文件**:
- `scripts/ui/main.gd` — 添加信号监听和回调

### 1.2 缺失塔放置/移除音效

**问题**: `placement_panel.gd` 调用 `AudioManager.play("tower_place")` 和 `AudioManager.play("tower_remove")`，但：
1. `audio_manager.gd` 的 `sound_map` 字典中未注册 `tower_place` 和 `tower_remove`（`play()` 静默返回）
2. `assets/sfx/` 目录下缺少对应 `.wav` 文件

**修复方案**:
- 用 jsfxr 生成 `tower_place.wav`（短促种植音）和 `tower_remove.wav`（短促拔起音）
- 在 `audio_manager.gd` 的 `sound_map` 中添加 `"tower_place": "tower_place.wav"` 和 `"tower_remove": "tower_remove.wav"`

**需修改的文件**:
- `scripts/systems/audio_manager.gd` — sound_map 添加两个条目
- 新增 `assets/sfx/tower_place.wav`
- 新增 `assets/sfx/tower_remove.wav`

---

## Part 2: 打击感增强

> **注意**: 屏幕震动（Camera Shake）已实现 — `scripts/systems/camera_shake.gd` 已存在，通过 `EventBus.camera_shake_requested` 触发，`enemy.gd` 死亡时已发出该信号。Boss 震动参数已在 `effect_config_data.gd` 中配置。此项无需额外工作。

### 2.1 击杀慢动作（Hitstop）

**效果**:
- 仅 Boss 击杀时触发，普通敌人不触发（避免频繁卡顿）
- 击杀瞬间 `Engine.time_scale = 0.05`，持续 0.1s 实际时间后恢复 1.0

**实现方式**:
- 在 EffectsManager 中新增 `hitstop(duration: float)` 方法
- 使用 `get_tree().create_timer(duration, true, false, true)` — 第 4 个参数 `ignore_time_scale=true` 确保计时器不受 time_scale 影响
- Boss 死亡流程（`boss_base.gd._on_died()`）中调用

**需修改的文件**:
- `scripts/systems/effects_manager.gd` — 新增 `hitstop()` 方法
- `scripts/entities/boss_base.gd` — 死亡时调用 hitstop

### 2.2 死亡特效增强

**当前状态**: 已有 `EffectsManager.spawn_death_effect()`，使用 ColorRect + Tween 实现粒子飘散。

**增强内容**:
- 敌人死亡时白闪 1 帧 → 缩放弹跳（scale 1→1.3→0） → 消失
- 增加碎片粒子数量和速度变化，使效果更有冲击感

**实现方式**:
- 在 `enemy.gd._on_died()` 中，死亡前对自身执行白闪 + 缩放弹跳序列（但因 queue_free 是立即执行的，改为：在 queue_free 前调用 `EffectsManager.spawn_enhanced_death(position, color)` 产生独立的白闪+缩放动画节点）
- 保持现有 ColorRect + Tween 方案的一致性，不引入 GPUParticles2D
- 增强 `spawn_death_effect` 参数：可选 `is_enhanced: bool`，Boss 死亡时产生更大更多的碎片

**需修改的文件**:
- `scripts/systems/effects_manager.gd` — 新增增强死亡特效方法
- `scripts/entities/enemy.gd` — 死亡时调用增强特效

### 2.3 击中反馈增强

**当前状态**: `enemy.gd` 有 `_flash_white()` 方法但 `_on_hurtbox_hit` 中**未调用**，实际上敌人受击没有任何闪光效果。

**效果**:
- 敌人受击时红闪（Color(1, 0.3, 0.3)），持续 0.05s，取代未使用的白闪
- 受击时微小抖动（sprite 偏移 1-2px 后回弹，纯视觉效果，区别于实际击退位移）

**实现方式**:
- EffectsManager 新增 `flash_hit(node: Node2D)` 方法，红色 modulate + Tween 恢复
- EffectsManager 新增 `sprite_shake(node: Node2D, amount: float)` 方法，Tween 驱动 position 偏移抖动
- 在 `enemy.gd._on_hurtbox_hit()` 中调用 `EffectsManager.flash_hit(self)` 和 `EffectsManager.sprite_shake(self, 2.0)`

**需修改的文件**:
- `scripts/systems/effects_manager.gd` — 新增 flash_hit + sprite_shake
- `scripts/entities/enemy.gd` — `_on_hurtbox_hit()` 中调用新特效

---

## Part 3: UI 动效

### 3.1 场景切换过渡

**效果**: 简单的淡入淡出（fade out → 切换 → fade in），0.3s 黑色遮罩。

**实现方式**:
- 在 SceneManager 中添加 ColorRect 遮罩（CanvasLayer, layer=200, 确保最上层）
- `go_to()` 改为 async（使用 `await`）：fade_out(0.3s) → 实际切换场景 → fade_in(0.3s)
- 遮罩初始透明，Tween 驱动 alpha 0→1→0
- 所有调用 `SceneManager.go_to()` 的地方无需改动 — 调用者 fire-and-forget，SceneManager 内部管理异步流程。场景切换时旧场景已被替换，不存在 freed node 问题

**需修改的文件**:
- `scripts/core/scene_manager.gd` — 添加过渡遮罩和动画逻辑

### 3.2 升级弹窗动效

**效果**:
- 弹窗出现：从缩放 0 弹到 1（overshoot easing），0.3s
- 卡片出现：3 张卡片依次从下方滑入，间隔 0.1s
- 选择卡片时：选中的放大高亮，未选中的淡出缩小

**实现方式**:
- 弹窗根节点 scale 动画：`Tween.set_ease(EASE_OUT).set_trans(TRANS_BACK)`
- 卡片用 `position.y` 偏移 + alpha 动画，`create_tween()` 链式延迟
- 选择时 Tween 驱动选中卡片 scale=1.1 + modulate.a=1，其余 scale=0.9 + modulate.a=0.3

**需修改的文件**:
- `scripts/ui/upgrade_popup.gd` — 添加弹窗/卡片出现动画和选择动画

### 3.3 HUD 数字变化

**效果**:
- 金币/XP 数字变化时短暂放大弹跳效果（scale 1→1.3→1，0.2s）
- 升级时经验条闪光 + "Level Up!" 文字弹出

**实现方式**:
- HUD 脚本中，数值更新时对 Label 执行 scale Tween 弹跳（pivot_offset 设为中心）
- 升级时在经验条位置实例化临时 Label "Level Up!"，scale+alpha 动画后 queue_free

**需修改的文件**:
- `scripts/ui/hud.gd` — 数字弹跳动画 + 升级文字弹出

### 3.4 按钮交互

**效果**:
- 所有按钮 hover 时轻微放大（1.05x），pressed 时缩小（0.95x）

**实现方式（方案 A — 通用工具方法）**:
- 在 `scripts/ui/` 下新增 `ui_utils.gd` 静态工具类
- 提供 `static func setup_button_hover(button: Button)` 方法，连接 `mouse_entered`/`mouse_exited`/`button_down`/`button_up` 信号，用 Tween 驱动 scale
- 各 UI 脚本 `_ready()` 中对按钮调用 `UIUtils.setup_button_hover(button)`
- 不改现有按钮结构，不继承自定义 Button 类

**需修改/新增的文件**:
- 新增 `scripts/ui/ui_utils.gd` — 通用按钮动画工具
- 各 UI 脚本 — `_ready()` 中调用

---

## Part 4: 音效与 BGM

### 4.1 BGM 系统

**实现方式**: 扩展现有 AudioManager，不新建 Autoload。

**新增内容**:
- AudioManager 新增独立的 `AudioStreamPlayer` 专用于 BGM（loop 播放）
- 新增 BGM 注册字典 `_bgm_tracks: Dictionary`（track_id → AudioStream）
- 新增方法：
  - `play_bgm(track_id: String)` — 播放指定 BGM（若已在播放同一首则忽略）
  - `stop_bgm()` — 停止当前 BGM
  - `fade_bgm(duration: float)` — 淡出当前 BGM 音量后停止
- 场景切换时自动切换 BGM，带 0.5s 淡出淡入

**场景 → BGM 映射**:
```
start_menu      → menu
character_selection → menu
map_select      → menu
placement       → placement
main            → battle
result          → result
```
映射字典维护在 SceneManager 中，`go_to()` 时根据目标场景名查找并调用 `AudioManager.play_bgm()`。

**需修改的文件**:
- `scripts/systems/audio_manager.gd` — 新增 BGM AudioStreamPlayer + play_bgm/stop_bgm/fade_bgm + BGM 注册
- `scripts/core/scene_manager.gd` — 场景切换时触发 BGM 切换

### 4.2 BGM 曲目规划（4 首）

| 场景 | 风格 | 文件 |
|------|------|------|
| 主菜单/选择界面 | 轻松像素风 | `assets/bgm/menu.ogg` |
| 布置阶段 | 平静准备感 | `assets/bgm/placement.ogg` |
| 战斗阶段 | 紧张节奏快 | `assets/bgm/battle.ogg` |
| 结算界面 | 通用结算感 | `assets/bgm/result.ogg` |

### 4.3 BGM 获取方案

两个路线：
- **免费现成曲目**: [itch.io chiptune 资源](https://itch.io/game-assets/free/tag-chiptune) 或 [Soundimage.org Chiptunes](https://soundimage.org/chiptunes/) — CC 协议免费商用
- **AI 生成定制**: [Wondera 8-bit Generator](https://www.wondera.ai/tools/en/ai-8-bit-music-generator) 或 [Musely](https://musely.ai/tools/pixel-art-game-soundtrack) — 描述场景风格自动生成

建议先用免费现成曲目占位，后续有需要再替换定制版。BGM 文件由用户手动获取放入 `assets/bgm/` 目录，代码侧做好加载和播放框架。

---

## 不在范围内

- Boss 补齐（boss_summoner/boss_guardian，后续单独做）
- 设置界面（音量调节等）
- 新地图内容

## 技术要点

- 项目基于 Godot 4.6, GDScript
- 渲染器：GL Compatibility
- 物理引擎：Jolt Physics
- 已有系统：EffectsManager（特效）、AudioManager（音效池）、EventBus（事件总线）、SceneManager（场景切换）、CameraShake（屏幕震动，已实现）
- 新增功能尽量扩展现有系统，不新建 Autoload
- 所有新增代码需附带单元测试
- 实施顺序：Part 1 (Bug 修复) → Part 2 (打击感) → Part 3 (UI 动效) → Part 4 (音效/BGM)
