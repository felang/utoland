# 体验打磨与 Bug 修复设计

## 概述

先修复 3 个已知 Bug，然后对游戏进行体验打磨：打击感增强、UI 动效、音效与 BGM 系统。新增功能尽量扩展现有系统（EffectsManager、AudioManager、EventBus、SceneManager），不新建 Autoload。

## Part 1: Bug 修复

### 1.1 Sunflower 产金事件未接收

**问题**: TowerGenerator（sunflower）定时发出 `EventBus.coins_generated` 信号，但 `main.gd` 未监听该信号，导致产金无效。

**修复方案**:
- `main.gd` 中监听 `EventBus.coins_generated` 信号
- 回调中调用 `GameData.add_coins(amount)` + 在产金位置生成金币实体（视觉反馈）
- sunflower 产金同样给 XP（因为 `add_coins` 已内置 `add_xp` 调用，无需额外处理）

**需修改的文件**:
- `scripts/ui/main.gd` — 添加信号监听和回调

### 1.2 缺失音效文件

**问题**: AudioManager 已注册 `tower_place` 和 `tower_remove` 触发点，但 `assets/sfx/` 下缺少对应 `.wav` 文件。

**修复方案**:
- 用 jsfxr 生成 `tower_place.wav` 和 `tower_remove.wav`
- 风格：tower_place 短促的"放置"音（类似种植），tower_remove 短促的"拔起"音

**需新增的文件**:
- `assets/sfx/tower_place.wav`
- `assets/sfx/tower_remove.wav`

### 1.3 空壳测试修复

**问题**: `test_upgrade_has_next_level` 测试方法体为空，缺少实际断言逻辑。

**修复方案**:
- 给 `test_upgrade_has_next_level` 加实际断言逻辑，验证升级是否存在下一等级

**需修改的文件**:
- 对应测试文件中的 `test_upgrade_has_next_level` 方法

---

## Part 2: 打击感增强

### 2.1 屏幕震动（Camera Shake）

**效果**:
- 敌人死亡时轻微震动（intensity=1, duration=0.1s）
- Boss 死亡时强烈震动（intensity=3, duration=0.3s）

**实现方式**:
- 主场景 Camera2D 添加 `shake(intensity, duration)` 方法
- 通过 EventBus 触发（监听敌人/Boss 死亡信号）
- shake 内部用 Tween 驱动 `camera.offset` 随机偏移并衰减回零

**需修改的文件**:
- `scripts/ui/main.gd` — Camera2D shake 方法 + EventBus 监听
- `scripts/core/event_bus.gd` — 若需新增信号（如 `enemy_killed(is_boss: bool, position: Vector2)`）

### 2.2 击杀慢动作（Hitstop）

**效果**:
- 仅 Boss 击杀时触发，普通敌人不触发（避免频繁卡顿）
- 击杀瞬间 `Engine.time_scale = 0.1`，持续 0.05s 后恢复 1.0

**实现方式**:
- 在 EffectsManager 中新增 `hitstop(duration: float)` 方法
- 使用 `get_tree().create_timer(duration, true, false, true)` (process_always=true) 确保暂停期间计时器仍运行
- Boss 死亡流程中调用

**需修改的文件**:
- `scripts/systems/effects_manager.gd` — 新增 `hitstop()` 方法
- `scripts/entities/boss_base.gd` — 死亡时调用 hitstop

### 2.3 死亡特效增强

**当前状态**: 已有 `EffectsManager.death_effect`（基础死亡特效）。

**增强内容**:
- 敌人死亡时白闪 1 帧 → 缩放弹跳（scale 1→1.3→0） → 消失
- 击杀时掉落碎片粒子（GPUParticles2D，2-4 个小方块飘散）

**实现方式**:
- 扩展 `EffectsManager.death_effect()` 增加白闪+缩放弹跳序列
- 新增 `spawn_death_particles(position: Vector2, color: Color)` 方法
- 碎片用 GPUParticles2D + 简单方形纹理，one_shot 模式，lifetime=0.5s

**需修改的文件**:
- `scripts/systems/effects_manager.gd` — 扩展 death_effect + 新增 spawn_death_particles
- 可能新增粒子材质资源

### 2.4 击中反馈增强

**效果**:
- 敌人受击时红闪（区别于已有的 flash_white）
- 受击时微小抖动（sprite 偏移 1-2px 后回弹，纯视觉效果，区别于实际击退位移）

**实现方式**:
- EffectsManager 新增 `flash_hit(sprite: Node2D)` 方法，用红色 modulate（Color(1, 0.3, 0.3)），持续 0.05s
- EffectsManager 新增 `sprite_shake(sprite: Node2D, amount: float)` 方法，Tween 驱动 offset 抖动
- 在 enemy.gd 的 `_on_damaged()` 回调中调用

**需修改的文件**:
- `scripts/systems/effects_manager.gd` — 新增 flash_hit + sprite_shake
- `scripts/entities/enemy.gd` — 受伤回调中调用新特效

---

## Part 3: UI 动效

### 3.1 场景切换过渡

**效果**: 简单的淡入淡出（fade out → 切换 → fade in），0.3s 黑色遮罩。

**实现方式**:
- 在 SceneManager 中添加 ColorRect 遮罩（CanvasLayer, layer=200, 确保最上层）
- `go_to()` 流程改为：fade_out(0.3s) → 实际切换场景 → fade_in(0.3s)
- 遮罩初始透明，Tween 驱动 alpha 0→1→0

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
- HUD 脚本中，数值更新时对 Label 执行 scale Tween 弹跳
- 升级时在经验条位置实例化临时 Label "Level Up!"，scale+alpha 动画后 queue_free

**需修改的文件**:
- `scripts/ui/hud.gd` — 数字弹跳动画 + 升级文字弹出

### 3.4 按钮交互

**效果**:
- 所有按钮 hover 时轻微放大（1.05x），pressed 时缩小（0.95x）

**实现方式**:
- 用 Tween 实现，不改现有按钮结构
- 方案 A：创建通用工具方法（如 `_setup_button_anim(button: Button)`），在各 UI 脚本 `_ready()` 中对按钮调用
- 方案 B：创建自定义 Button 脚本继承 Button，在 `_ready()` 中自动连接 `mouse_entered`/`mouse_exited`/`button_down`/`button_up` 信号
- 推荐方案 A，侵入性最小

**需修改的文件**:
- 可在 `scripts/ui/` 下新增通用 UI 工具方法，或在各 UI 脚本中逐个添加

---

## Part 4: 音效与 BGM

### 4.1 补齐缺失音效

同 1.2 Bug 修复，用 jsfxr 生成：
- `assets/sfx/tower_place.wav` — 短促放置音
- `assets/sfx/tower_remove.wav` — 短促拔起音

### 4.2 BGM 系统

**实现方式**: 扩展现有 AudioManager，不新建 Autoload。

**新增内容**:
- AudioManager 新增独立的 `AudioStreamPlayer` 专用于 BGM（loop 播放）
- 新增方法：
  - `play_bgm(track_id: String)` — 播放指定 BGM
  - `stop_bgm()` — 停止当前 BGM
  - `fade_bgm(duration: float)` — 淡出当前 BGM
- 场景切换时自动切换 BGM，带 0.5s 淡出淡入
- SceneManager 的 `go_to()` 中调用 `AudioManager.fade_bgm()` + 切换后 `play_bgm()`

**需修改的文件**:
- `scripts/systems/audio_manager.gd` — 新增 BGM AudioStreamPlayer + play_bgm/stop_bgm/fade_bgm
- `scripts/core/scene_manager.gd` — 场景切换时触发 BGM 切换

### 4.3 BGM 曲目规划（4 首）

| 场景 | 风格 | 文件 |
|------|------|------|
| 主菜单/选择界面 | 轻松像素风 | `assets/bgm/menu.ogg` |
| 布置阶段 | 平静准备感 | `assets/bgm/placement.ogg` |
| 战斗阶段 | 紧张节奏快 | `assets/bgm/battle.ogg` |
| 结算界面 | 胜利/失败各一 | `assets/bgm/result.ogg` |

### 4.4 BGM 获取方案

两个路线：
- **免费现成曲目**: itch.io chiptune 资源或 Soundimage.org — CC 协议免费商用
- **AI 生成定制**: Wondera 8-bit Generator 或 Musely — 描述场景风格自动生成

建议先用免费现成曲目占位，后续有需要再替换定制版。

---

## 不在范围内

- Boss 补齐（boss_summoner/boss_guardian，后续单独做）
- 设置界面（音量调节等）
- 新地图内容

## 技术要点

- 项目基于 Godot 4.6, GDScript
- 渲染器：GL Compatibility
- 物理引擎：Jolt Physics
- 已有系统：EffectsManager（特效）、AudioManager（音效池）、EventBus（事件总线）、SceneManager（场景切换）
- 新增功能尽量扩展现有系统，不新建 Autoload
- 所有新增代码需附带单元测试
