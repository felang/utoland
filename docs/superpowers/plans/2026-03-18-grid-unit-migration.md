# 网格单位迁移实施计划（16px → 32px）

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将游戏网格单位从 16px 迁移到 32px，地图从 544×416 扩大到 1440×960，视口从 640×360 调整到 960×540，所有空间值等比缩放。

**Architecture:** 自上而下修改：先改核心常量（GameConfig + project.godot），再改资源文件（.tres），再改脚本硬编码值，再改场景文件（.tscn），最后改 UI。大部分文件间无依赖，可并行执行。

**Tech Stack:** Godot 4.6 / GDScript / .tres 资源文件 / .tscn 场景文件

---

## Chunk 1: 核心配置 + 资源文件

### Task 1: 项目视口 + GameConfig 核心常量

**Files:**
- Modify: `project.godot:34-35`
- Modify: `scripts/core/game_config.gd:12-48`

- [ ] **Step 1: 修改 project.godot 视口**

```
viewport_width: 640 → 960
viewport_height: 360 → 540
```

- [ ] **Step 2: 修改 game_config.gd 核心常量**

```gdscript
# Line 12-15
const BASE_VIEWPORT_WIDTH: int = 960    # was 640
const BASE_VIEWPORT_HEIGHT: int = 540   # was 360
const PPU: int = 32                      # was 16
const GRID_SIZE: int = 32                # was 16

# Line 17-19
const MAP_GRID_WIDTH: int = 45           # was 34
const MAP_GRID_HEIGHT: int = 30          # was 26

# Line 28-31
const ENTITY_SIZE_STANDARD: int = 32     # was 16
const ENTITY_SIZE_TANK: int = 64         # was 32
const BULLET_SIZE: int = 6              # was 3
const COIN_RADIUS: int = 6              # was 3

# Line 44 (PLAYER dict)
"initial_speed": 200.0                   # was 100.0
```

注意：`_compute_map_dimensions()` 从 `MAP_GRID_WIDTH * GRID_SIZE` 计算 `MAP_PIXEL_WIDTH` 等，改常量后自动适配。`SPRITES` 字典中的 `frame_size` 不要改（源素材尺寸）。

- [ ] **Step 3: Commit**

```bash
git add project.godot scripts/core/game_config.gd
git commit -m "refactor: 核心常量迁移 16px→32px（视口 960×540，地图 1440×960）"
```

### Task 2: 角色资源 — 速度 ×2

**Files:**
- Modify: `resources/characters/dora.tres:11`
- Modify: `resources/characters/kaze.tres:11`
- Modify: `resources/characters/gorg.tres:11`
- Modify: `resources/characters/merlin.tres:11`
- Modify: `resources/characters/nemo.tres:11`

- [ ] **Step 1: 修改所有角色 speed**

| 文件 | 旧值 | 新值 |
|------|------|------|
| dora.tres | speed = 100.0 | speed = 200.0 |
| kaze.tres | speed = 130.0 | speed = 260.0 |
| gorg.tres | speed = 80.0 | speed = 160.0 |
| merlin.tres | speed = 95.0 | speed = 190.0 |
| nemo.tres | speed = 105.0 | speed = 210.0 |

- [ ] **Step 2: Commit**

```bash
git add resources/characters/
git commit -m "refactor: 角色速度 ×2 适配 32px 网格"
```

### Task 3: 武器资源 — 射程 + pivot_offset ×2

**Files:**
- Modify: `resources/weapons/bow.tres`
- Modify: `resources/weapons/sword.tres`
- Modify: `resources/weapons/shuriken.tres`

- [ ] **Step 1: 修改 bow.tres**

```
attack_range_per_level: [150, 170, 200] → [300, 340, 400]
pivot_offset: 15.0 → 30.0
```

- [ ] **Step 2: 修改 sword.tres**

```
attack_range_per_level: [50, 50, 50] → [100, 100, 100]
pivot_offset: 10.0 → 20.0
```

- [ ] **Step 3: 修改 shuriken.tres**

```
attack_range_per_level: [100, 120, 150] → [200, 240, 300]
pivot_offset: 20.0 → 40.0
```

- [ ] **Step 4: Commit**

```bash
git add resources/weapons/
git commit -m "refactor: 武器射程/pivot_offset ×2 适配 32px 网格"
```

### Task 4: 塔资源 — 射程 ×2

**Files:**
- Modify: `resources/towers/pea_shooter.tres`
- Modify: `resources/towers/ice_flower.tres`

- [ ] **Step 1: 修改 pea_shooter.tres**

```
attack_range_per_level: [150, 170, 200] → [300, 340, 400]
```

- [ ] **Step 2: 修改 ice_flower.tres**

```
attack_range_per_level: [100, 120, 150] → [200, 240, 300]
```

sunflower.tres 无空间值，不改。

- [ ] **Step 3: Commit**

```bash
git add resources/towers/
git commit -m "refactor: 塔射程 ×2 适配 32px 网格"
```

### Task 5: 敌人资源 — 速度 ×2

**Files:**
- Modify: `resources/enemies/normal.tres`
- Modify: `resources/enemies/fast.tres`
- Modify: `resources/enemies/tank.tres`
- Modify: `resources/enemies/boss_brute.tres`
- Modify: `resources/enemies/boss_summoner.tres`
- Modify: `resources/enemies/boss_guardian.tres`

- [ ] **Step 1: 修改所有敌人 speed**

| 文件 | 旧值 | 新值 |
|------|------|------|
| normal.tres | 50.0 | 100.0 |
| fast.tres | 90.0 | 180.0 |
| tank.tres | 25.0 | 50.0 |
| boss_brute.tres | 30.0 | 60.0 |
| boss_summoner.tres | 25.0 | 50.0 |
| boss_guardian.tres | 20.0 | 40.0 |

- [ ] **Step 2: Commit**

```bash
git add resources/enemies/
git commit -m "refactor: 敌人速度 ×2 适配 32px 网格"
```

### Task 6: 投射物 + 近战资源 — 速度/空间值 ×2

**Files:**
- Modify: `resources/projectiles/arrow.tres`
- Modify: `resources/projectiles/pea_bullet.tres`
- Modify: `resources/projectiles/shuriken.tres`
- Modify: `resources/projectiles/ice_bullet.tres`
- Modify: `resources/projectiles/sword_melee.tres`

- [ ] **Step 1: 修改投射物 speed**

| 文件 | 旧值 | 新值 |
|------|------|------|
| arrow.tres | 300.0 | 600.0 |
| pea_bullet.tres | 800.0 | 1600.0 |
| shuriken.tres | 175.0 | 350.0 |
| ice_bullet.tres | 800.0 | 1600.0 |

- [ ] **Step 2: 修改 sword_melee.tres**

```
hit_radius: 14.0 → 28.0
knockback_force: 80.0 → 160.0
hit_angle: 90.0（不变）
```

- [ ] **Step 3: Commit**

```bash
git add resources/projectiles/
git commit -m "refactor: 投射物速度/近战空间值 ×2 适配 32px 网格"
```

### Task 7: 生成配置 — min_distance ×2

**Files:**
- Modify: `resources/spawn/default_spawn.tres`
- Modify: `scripts/systems/enemy_spawner.gd:26`

- [ ] **Step 1: 修改 default_spawn.tres**

```
min_distance_from_player: 75.0 → 150.0
```

- [ ] **Step 2: 修改 enemy_spawner.gd fallback 默认值**

```gdscript
# Line 26
var min_distance_from_player: float = 200.0  # was 100.0
```

- [ ] **Step 3: Commit**

```bash
git add resources/spawn/default_spawn.tres scripts/systems/enemy_spawner.gd
git commit -m "refactor: 敌人生成最小距离 ×2 适配 32px 网格"
```

---

## Chunk 2: 脚本硬编码值

### Task 8: exp_orb.gd + coin.gd — 吸引范围/速度 ×2

**Files:**
- Modify: `scripts/entities/exp_orb.gd:5-7,47-60`
- Modify: `scripts/entities/coin.gd:5-7,48-57`

- [ ] **Step 1: 修改 exp_orb.gd**

```gdscript
# Lines 5-7: @export 默认值
@export var value: int = 1
@export var attract_speed: float = 400.0   # was 200.0
@export var attract_range: float = 60.0    # was 30.0
```

同时检查 `reset_for_pool()` 方法中是否硬编码了旧值，如有则同步修改。

- [ ] **Step 2: 修改 coin.gd**

```gdscript
# Lines 5-7: @export 默认值
@export var value: int = 1
@export var attract_speed: float = 500.0   # was 250.0
@export var attract_range: float = 150.0   # was 75.0
```

同时检查 `reset_for_pool()` 方法中是否硬编码了旧值，如有则同步修改。

- [ ] **Step 3: Commit**

```bash
git add scripts/entities/exp_orb.gd scripts/entities/coin.gd
git commit -m "refactor: 经验球/金币吸引范围和速度 ×2 适配 32px 网格"
```

### Task 9: enemy.gd + boss_brute.gd — 散布范围/冲锋距离 ×2

**Files:**
- Modify: `scripts/entities/enemy.gd:5-6`
- Modify: `scripts/entities/boss_brute.gd:15`

- [ ] **Step 1: 修改 enemy.gd 散布常量**

```gdscript
# Lines 5-6
const COIN_SCATTER_RANGE: float = 40.0   # was 20.0
const EXP_SCATTER_RANGE: float = 40.0    # was 20.0
```

同时搜索 enemy.gd 中调用 `EffectsManager.sprite_shake` 时传入的硬编码 `2.0`，改为 `4.0`。

- [ ] **Step 2: 修改 boss_brute.gd 冲锋距离**

```gdscript
# Line 15
var _min_charge_distance: float = 80.0   # was 40.0
```

- [ ] **Step 3: Commit**

```bash
git add scripts/entities/enemy.gd scripts/entities/boss_brute.gd
git commit -m "refactor: 敌人散布范围/Boss冲锋距离 ×2 适配 32px 网格"
```

### Task 10: map_boundary.gd — 墙壁厚度 ×2

**Files:**
- Modify: `scripts/shared/map_boundary.gd:5`

- [ ] **Step 1: 修改 WALL_THICKNESS**

```gdscript
# Line 5
const WALL_THICKNESS: float = 32.0  # was 16.0
```

墙体位置/尺寸由 `_ready()` 从 GameConfig 动态计算，不需要额外修改。

- [ ] **Step 2: Commit**

```bash
git add scripts/shared/map_boundary.gd
git commit -m "refactor: 地图边界墙壁厚度 ×2 适配 32px 网格"
```

### Task 11: main.gd — 相机参数 + 硬编码视口尺寸

**Files:**
- Modify: `scripts/ui/main.gd:11-13,125-134`

- [ ] **Step 1: 修改相机常量**

```gdscript
# Lines 11-13
const CAMERA_TRANSITION_DURATION: float = 0.5  # 不变
const SHOP_ZOOM: float = 0.56                   # was 0.82
const SHOP_CAMERA_POS := Vector2(-196, 0)        # was Vector2(-98, 0)
```

- [ ] **Step 2: 修改 _get_clamped_camera_pos() 中硬编码 640.0/360.0**

```gdscript
# Lines ~127-128: 将硬编码值改为引用 GameConfig
var view_half_w: float = float(GameConfig.BASE_VIEWPORT_WIDTH) / (2.0 * zoom_val)
var view_half_h: float = float(GameConfig.BASE_VIEWPORT_HEIGHT) / (2.0 * zoom_val)
```

- [ ] **Step 3: 修改 battle camera limits**

搜索 `_restore_battle_camera()` 或设置 `camera.limit_*` 的代码，将 `±272` → `±720`，`±208` → `±480`。如果这些值是从 `GameConfig.MAP_HALF_WIDTH/HEIGHT` 计算的，则不需要改。

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/main.gd
git commit -m "refactor: 相机参数适配 32px 网格（SHOP_ZOOM/POS/viewport引用）"
```

---

## Chunk 3: 特效系统

### Task 12: EffectsManager — 硬编码尺寸 ×2

**Files:**
- Modify: `scripts/systems/effects_manager.gd:8-9,26,136`

- [ ] **Step 1: 修改常量**

```gdscript
# Lines 8-9
const HIT_SPARK_SIZE := Vector2(4, 4)        # was Vector2(2, 2)
const DEATH_PARTICLE_SIZE := Vector2(6, 6)    # was Vector2(3, 3)
```

- [ ] **Step 2: 修改 sprite_shake 默认 amount**

```gdscript
# Line 26: sprite_shake 函数签名
func sprite_shake(sprite: Node2D, duration: float = 0.15, amount: float = 4.0) -> void:
#                                                                   was 2.0
```

- [ ] **Step 3: 修改 spawn_enhanced_death flash_rect 尺寸**

```gdscript
# Line ~136: flash_rect size
flash_rect.size = Vector2(24, 24)    # was Vector2(12, 12)
```

- [ ] **Step 4: Commit**

```bash
git add scripts/systems/effects_manager.gd
git commit -m "refactor: 特效管理器空间值 ×2 适配 32px 网格"
```

### Task 13: EffectConfigData — 空间默认值 ×2

**Files:**
- Modify: `scripts/resources/effect_config_data.gd`

- [ ] **Step 1: 修改所有空间类默认值（约 14 处）**

```gdscript
# Line 13-14: Knockback
@export var knockback_distance: float = 15.0      # was 7.5
# knockback_duration 不变（时间值）

# Line 26-27: Damage number
@export var damage_number_float_distance: float = 30.0   # was 15.0
@export var damage_number_random_offset_x: float = 10.0  # was 5.0

# Line 40-41: Death particles
@export var death_particle_speed_min: float = 50.0   # was 25.0
@export var death_particle_speed_max: float = 120.0  # was 60.0

# Line 47: Hit sparks
@export var hit_spark_spread_speed: float = 100.0    # was 50.0

# Line 54-55: Bullet trail
@export var bullet_trail_length: float = 15.0        # was 7.5
@export var bullet_trail_width: float = 4.0          # was 2.0

# Line 62-65: Shuriken
@export var shuriken_trail_width: float = 6.0        # was 3.0
@export var shuriken_return_distance: float = 15.0   # was 7.5

# Line 68-70: Laser
@export var laser_beam_width: float = 6.0            # was 3.0
@export var laser_beam_hitbox_height: float = 16.0   # was 8.0

# Line 83: Camera
@export var camera_look_ahead_distance: float = 40.0  # was 20.0

# Line 92: Muzzle flash
@export var muzzle_flash_size := Vector2(6, 6)        # was Vector2(3, 3)
```

不改的值：时间（duration）、颜色、倍率、角度、帧数、z_index。

- [ ] **Step 2: Commit**

```bash
git add scripts/resources/effect_config_data.gd
git commit -m "refactor: 特效配置空间默认值 ×2 适配 32px 网格"
```

---

## Chunk 4: UI + 场景文件

### Task 14: UI 常量 — ×1.5 适配新视口

**Files:**
- Modify: `scripts/core/ui_constants.gd:30-51`

- [ ] **Step 1: 修改 HUD 尺寸**

```gdscript
# Lines 30-38
const HUD_ICON_FONT_SIZE: int = 12    # was 8
const HUD_ICON_BORDER: int = 2        # was 1
const HUD_ICON_CORNER: int = 3        # was 2
const HUD_BAR_WIDTH: int = 120        # was 80
const HUD_HP_BAR_HEIGHT: int = 15     # was 10
const HUD_XP_BAR_HEIGHT: int = 12     # was 8
const HUD_BAR_CORNER: int = 2         # was 1
const HUD_WAVE_PADDING_H: int = 12    # was 8
const HUD_WAVE_PADDING_V: int = 3     # was 2
```

- [ ] **Step 2: 修改字体大小**

```gdscript
# Lines 41-45
const FONT_SIZE_TITLE: int = 48       # was 32
const FONT_SIZE_SUBTITLE: int = 36    # was 24
const FONT_SIZE_BODY: int = 27        # was 18
const FONT_SIZE_SMALL: int = 21       # was 14
const FONT_SIZE_TINY: int = 18        # was 12
```

- [ ] **Step 3: 修改间距**

```gdscript
# Lines 48-51
const MARGIN_SCREEN: int = 18         # was 12
const MARGIN_PANEL: int = 24          # was 16
const GAP_ITEMS: int = 18             # was 12
const GAP_SECTIONS: int = 30          # was 20
```

- [ ] **Step 4: Commit**

```bash
git add scripts/core/ui_constants.gd
git commit -m "refactor: UI 常量 ×1.5 适配 960×540 视口"
```

### Task 15: GameConfig UI 常量 + shop_overlay.gd 硬编码值

**Files:**
- Modify: `scripts/core/game_config.gd:34-39`
- Modify: `scripts/ui/shop_overlay.gd:7,66,71,109,142,147`

- [ ] **Step 1: 修改 game_config.gd 中的 UI 尺寸常量**

```gdscript
# Lines 34-39
const UI_BUTTON_SIZE := Vector2(240, 54)          # was (160, 36)
const UI_BUTTON_SMALL_SIZE := Vector2(180, 48)    # was (120, 32)
const UI_MAP_CARD_SIZE := Vector2(360, 210)        # was (240, 140)
const UI_RESULT_PANEL_SIZE := Vector2(480, 330)    # was (320, 220)
const UI_SHOP_PANEL_SIZE := Vector2(840, 450)      # was (560, 300)
const UI_CARD_GAP: int = 30                        # was 20
```

- [ ] **Step 2: 修改 shop_overlay.gd 硬编码值**

```gdscript
# Line 7
const CARD_ICON_SIZE := Vector2(24, 24)    # was Vector2(16, 16)

# Line 109: recycle area height
_recycle_area.custom_minimum_size = Vector2(0, 60)  # was 40

# Lines 66, 71, 142, 147: 硬编码字体大小
add_theme_font_size_override("font_size", 14)  # was 9 (共 4 处)
```

- [ ] **Step 3: Commit**

```bash
git add scripts/core/game_config.gd scripts/ui/shop_overlay.gd
git commit -m "refactor: UI 面板尺寸/商店硬编码值适配 960×540 视口"
```

### Task 16: 场景文件 — 碰撞体 ×2

**Files:**
- Modify: `scenes/entities/player.tscn`
- Modify: `scenes/entities/enemies/*.tscn`
- Modify: `scenes/entities/towers/*.tscn`
- Modify: `scenes/entities/projectiles/*.tscn`

- [ ] **Step 1: 修改 player.tscn**

- Body CollisionShape2D: RectangleShape2D size `(16, 16)` → `(32, 32)`
- Hurtbox CircleShape2D: radius `6.5` → `13.0`
- ColorRect（临时视觉）: size `(16, 16)` → `(32, 32)`，offset 相应调整

- [ ] **Step 2: 修改敌人场景碰撞体**

对 `scenes/entities/enemies/` 下所有 .tscn，碰撞体尺寸 ×2。精灵由 SpriteAnimator 根据 `ENTITY_SIZE_STANDARD` 自动缩放，不需要手动改 sprite scale。

- [ ] **Step 3: 修改塔场景碰撞体 + 精灵 scale**

对 `scenes/entities/towers/` 下所有 .tscn：
- 碰撞体 ×2
- 精灵节点 scale 设为 `Vector2(2, 2)`（塔精灵不走 SpriteAnimator）

- [ ] **Step 4: 修改投射物场景碰撞体 + 精灵 scale**

对 `scenes/entities/projectiles/` 下所有 .tscn：
- 碰撞体 ×2
- 精灵节点 scale 设为 `Vector2(2, 2)`

- [ ] **Step 5: Commit**

```bash
git add scenes/entities/
git commit -m "refactor: 场景碰撞体 ×2 + 精灵 scale 适配 32px 网格"
```

---

## Chunk 5: 验证

### Task 17: 运行游戏验证

- [ ] **Step 1: 通过 Godot 编辑器运行游戏**

检查项：
1. 玩家在新地图上移动速度体感合理
2. 相机跟随和 SHOP_ZOOM 正确框住地图
3. 商店 UI 布局正常（卡片、按钮、字体大小）
4. 塔放置网格对齐 32px
5. 敌人从边界外正常生成
6. 特效尺寸视觉合理（伤害数字、火花、粒子）
7. 精灵缩放正确（16px 素材在 32px 格子中显示）
8. 碰撞体与视觉匹配
9. 投射物飞行速度/武器射程体感合理

- [ ] **Step 2: 修复验证中发现的问题**

- [ ] **Step 3: 最终 Commit**

```bash
git commit -m "fix: 32px 网格迁移验证修复"
```
