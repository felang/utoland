# 尺寸调整后适配 实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 同步调整 UI 字体（像素风格）、布置场景缩放、物理参数（×0.5），使其匹配缩小后的游戏尺寸。

**Architecture:** 三个独立调整点：(1) 全局 Theme 资源实现像素字体渲染，(2) 布置场景初始缩放从 0.375 调至 0.75，(3) 所有距离/速度/范围参数统一乘以 0.5。

**Tech Stack:** Godot 4.6, GDScript, .tres Resource 文件

**Spec:** `docs/superpowers/specs/2026-03-13-post-resize-adaptation-design.md`

---

## Chunk 1: 像素字体 + 布置场景缩放

### Task 1: 全局像素字体 Theme

**Files:**
- Create: `assets/themes/default_theme.tres`
- Modify: `project.godot`

这个任务需要通过 MCP 工具在 Godot 编辑器中创建 Theme 资源，因为 .tres 文件的序列化格式由 Godot 引擎决定。

- [ ] **Step 1: 通过 MCP 创建 Theme 资源**

使用 `execute_editor_script` 在 Godot 编辑器中运行以下脚本来创建 Theme 资源：

```gdscript
# 创建 FontFile 并配置像素渲染
var font = SystemFont.new()
font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
font.hinting = TextServer.HINTING_NONE
font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED

# 创建 Theme 并设置默认字体
var theme = Theme.new()
theme.default_font = font

# 保存 Theme 资源
var dir = DirAccess.open("res://")
if not dir.dir_exists("assets/themes"):
    dir.make_dir_recursive("assets/themes")
ResourceSaver.save(theme, "res://assets/themes/default_theme.tres")
print("Theme saved successfully")
```

- [ ] **Step 2: 在 project.godot 中设置默认 Theme**

修改 `project.godot`，在 `[gui]` 节下添加：

```ini
[gui]
theme/custom="res://assets/themes/default_theme.tres"
```

如果 `[gui]` 节不存在则新建。

- [ ] **Step 3: 验证字体效果**

通过 MCP `play_scene` 运行游戏，截图确认 UI 文字是否呈现像素风格（无抗锯齿平滑边缘）。

- [ ] **Step 4: Commit**

```bash
git add assets/themes/default_theme.tres project.godot
git commit -m "feat: 全局像素字体 Theme（禁用抗锯齿和 hinting）"
```

---

### Task 2: 布置场景初始缩放

**Files:**
- Modify: `scripts/ui/placement.gd:4,8`

- [ ] **Step 1: 修改缩放和平移速度常量**

在 `scripts/ui/placement.gd` 中修改：

```gdscript
# 第 4 行
const CAMERA_PAN_SPEED = 300.0  # 原 600.0

# 第 8 行
const PLACEMENT_ZOOM_INIT = Vector2(0.75, 0.75)  # 原 Vector2(0.375, 0.375)
```

- [ ] **Step 2: Commit**

```bash
git add scripts/ui/placement.gd
git commit -m "fix: 布置场景初始缩放从 0.375 调至 0.75，平移速度同步调整"
```

---

## Chunk 2: 物理参数缩放 — 脚本默认值

### Task 3: 武器/投射物脚本默认值 ×0.5

**Files:**
- Modify: `scripts/resources/weapon_data.gd:17,20,21,26,29`
- Modify: `scripts/entities/projectiles/bullet_projectile.gd:11`
- Modify: `scripts/entities/projectiles/boomerang_projectile.gd:6,7`
- Modify: `scripts/entities/projectiles/laser_projectile.gd:7`

- [ ] **Step 1: 修改 weapon_data.gd 默认值**

```gdscript
# 第 17 行
@export var bullet_speed: float = 300.0  # 原 600.0

# 第 20 行
@export var boomerang_speed: float = 175.0  # 原 350.0

# 第 21 行
@export var outbound_distance: float = 100.0  # 原 200.0

# 第 26 行
@export var knockback_force: float = 40.0  # 原 80.0

# 第 29 行
@export var beam_range: float = 200.0  # 原 400.0
```

- [ ] **Step 2: 修改 bullet_projectile.gd 默认值**

```gdscript
# 第 11 行
var speed: float = 300.0  # 原 600.0
```

- [ ] **Step 3: 修改 boomerang_projectile.gd 默认值**

```gdscript
# 第 6 行
var speed: float = 175.0  # 原 350.0

# 第 7 行
var outbound_distance: float = 100.0  # 原 200.0
```

注意：`_on_setup()` 会从 WeaponData 配置覆盖这些默认值，但默认值仍需同步以保持一致。

- [ ] **Step 4: 修改 laser_projectile.gd 默认值**

```gdscript
# 第 7 行
var beam_range: float = 200.0  # 原 400.0
```

- [ ] **Step 5: Commit**

```bash
git add scripts/resources/weapon_data.gd scripts/entities/projectiles/bullet_projectile.gd scripts/entities/projectiles/boomerang_projectile.gd scripts/entities/projectiles/laser_projectile.gd
git commit -m "fix: 武器和投射物速度/范围/击退默认值 ×0.5"
```

---

### Task 4: 特效/金币/Boss/生成距离脚本默认值 ×0.5

**Files:**
- Modify: `scripts/resources/effect_config_data.gd` (多行)
- Modify: `scripts/entities/coin.gd:6,7`
- Modify: `scripts/entities/boss_brute.gd:15`
- Modify: `scripts/resources/spawn_config_data.gd:4`
- Modify: `scripts/systems/enemy_spawner.gd:18`
- Modify: `scripts/core/game_config.gd:44`
- Modify: `scripts/resources/enemy_data.gd:7`
- Modify: `scripts/resources/character_data.gd:8`

- [ ] **Step 1: 修改 effect_config_data.gd 距离/速度类默认值**

逐行修改以下参数（保持文件其他内容不变）：

```
第 5 行: camera_shake_player_hit_intensity: float = 1.5    # 原 3.0
第 7 行: camera_shake_enemy_kill_intensity: float = 1.0    # 原 2.0
第 9 行: camera_shake_wave_start_intensity: float = 2.5    # 原 5.0
第 13 行: knockback_distance: float = 7.5                   # 原 15.0
第 26 行: damage_number_float_distance: float = 15.0        # 原 30.0
第 27 行: damage_number_random_offset_x: float = 5.0        # 原 10.0
第 37 行: death_particle_spread: float = 10.0               # 原 20.0
第 39 行: death_particle_gravity: float = 100.0             # 原 200.0
第 40 行: death_particle_speed_min: float = 25.0            # 原 50.0
第 41 行: death_particle_speed_max: float = 60.0            # 原 120.0
第 47 行: hit_spark_spread_speed: float = 50.0              # 原 100.0
第 54 行: bullet_trail_length: float = 7.5                  # 原 15.0
第 65 行: boomerang_return_distance: float = 7.5            # 原 15.0
第 75 行: laser_flash_size: Vector2 = Vector2(1000, 1000)   # 原 Vector2(2000, 2000)
第 83 行: camera_look_ahead_distance: float = 20.0          # 原 40.0
第 92 行: muzzle_flash_size: Vector2 = Vector2(3, 3)        # 原 Vector2(6, 6)
```

- [ ] **Step 2: 修改 coin.gd 吸附参数**

```gdscript
# 第 6 行
@export var attract_speed: float = 250.0  # 原 500.0

# 第 7 行
@export var attract_range: float = 75.0  # 原 150.0
```

- [ ] **Step 3: 修改 boss_brute.gd 冲锋最小距离**

```gdscript
# 第 15 行
var _min_charge_distance: float = 40.0  # 原 80.0
```

- [ ] **Step 4: 修改 spawn_config_data.gd 生成距离**

```gdscript
# 第 4 行
@export var min_distance_from_player: float = 75.0  # 原 150.0
```

- [ ] **Step 5: 修改 enemy_spawner.gd fallback 距离**

```gdscript
# 第 18 行
var min_distance_from_player: float = 100.0  # 原 200.0
```

- [ ] **Step 6: 修改 game_config.gd PLAYER 常量**

```gdscript
# 第 44 行
"initial_speed": 100.0,  # 原 200.0
```

- [ ] **Step 7: 修改 enemy_data.gd 脚本默认值**

```gdscript
# 第 7 行
@export var speed: float = 50.0  # 原 100.0
```

这确保新增敌人类型使用正确的默认速度。`normal.tres` 若未显式设置 speed 则自动继承此默认值。

- [ ] **Step 8: 修改 character_data.gd 脚本默认值**

```gdscript
# 第 8 行
@export var speed: float = 100.0  # 原 200.0
```

这确保新增角色使用正确的默认速度。

- [ ] **Step 9: Commit**

```bash
git add scripts/resources/effect_config_data.gd scripts/entities/coin.gd scripts/entities/boss_brute.gd scripts/resources/spawn_config_data.gd scripts/systems/enemy_spawner.gd scripts/core/game_config.gd scripts/resources/enemy_data.gd scripts/resources/character_data.gd
git commit -m "fix: 特效/金币/Boss/生成距离/玩家速度/敌人/角色默认值 ×0.5"
```

---

## Chunk 3: .tres 资源文件 + 测试更新

### Task 5: 角色/敌人/武器/塔 .tres 资源文件 ×0.5

**Files:**
- Modify: `resources/characters/dora.tres`, `gorg.tres`, `kaze.tres`, `merlin.tres`, `nemo.tres`
- Modify: `resources/enemies/normal.tres`, `fast.tres`, `tank.tres`, `boss_brute.tres`, `boss_summoner.tres`, `boss_guardian.tres`
- Modify: `resources/weapons/rifle.tres`, `boomerang.tres`, `laser.tres`
- Modify: `resources/towers/shooter.tres`, `slow.tres`

.tres 文件是 Godot 专有的序列化格式。使用 MCP `edit_file` 工具或直接文本编辑修改数值。

- [ ] **Step 1: 修改 5 个角色 speed**

所有角色 .tres 文件中 `speed` 从 `200.0` 改为 `100.0`：
- `resources/characters/dora.tres`
- `resources/characters/gorg.tres`
- `resources/characters/kaze.tres`
- `resources/characters/merlin.tres`
- `resources/characters/nemo.tres`

- [ ] **Step 2: 修改 6 个敌人 speed**

| 文件 | speed 当前 | → 新值 |
|------|-----------|--------|
| `resources/enemies/normal.tres` | 100.0 (需补充) | 50.0 |
| `resources/enemies/fast.tres` | 180.0 | 90.0 |
| `resources/enemies/tank.tres` | 50.0 | 25.0 |
| `resources/enemies/boss_brute.tres` | 60.0 | 30.0 |
| `resources/enemies/boss_summoner.tres` | 50.0 | 25.0 |
| `resources/enemies/boss_guardian.tres` | 40.0 | 20.0 |

注意：`normal.tres` 中若未显式设置 speed，需要添加 `speed = 50.0`。

- [ ] **Step 3: 修改 3 个武器 weapon_range_per_level**

| 文件 | 当前 | → 新值 |
|------|------|--------|
| `resources/weapons/rifle.tres` | `[300, 320, 340, 370, 400]` | `[150, 160, 170, 185, 200]` |
| `resources/weapons/boomerang.tres` | `[200, 220, 240, 260, 300]` | `[100, 110, 120, 130, 150]` |
| `resources/weapons/laser.tres` | `[400, 430, 460, 500, 550]` | `[200, 215, 230, 250, 275]` |

- [ ] **Step 4: 修改 2 个塔 attack_range_per_level**

| 文件 | 当前 | → 新值 |
|------|------|--------|
| `resources/towers/shooter.tres` | `[300, 320, 340, 370, 400]` | `[150, 160, 170, 185, 200]` |
| `resources/towers/slow.tres` | `[200, 220, 240, 260, 300]` | `[100, 110, 120, 130, 150]` |

- [ ] **Step 5: Commit**

```bash
git add resources/characters/ resources/enemies/ resources/weapons/ resources/towers/
git commit -m "fix: 角色/敌人/武器/塔 .tres 资源速度和范围 ×0.5"
```

---

### Task 6: 更新测试断言

**Files:**
- Modify: `tests/unit/test_resource_loading.gd`
- Modify: `tests/integration/test_enemy_spawning.gd:67`

- [ ] **Step 1: 更新 test_resource_loading.gd 断言值**

修改以下断言（行号 → 新值）：

```gdscript
# 第 20 行: rifle weapon_range
assert_almost_eq(w.weapon_range_per_level[0], 150.0, 0.001)  # 原 300.0

# 第 22 行: rifle bullet_speed
assert_eq(w.bullet_speed, 300.0)  # 原 600.0

# 第 30 行: boomerang speed
assert_eq(w.boomerang_speed, 175.0)  # 原 350.0

# 第 31 行: boomerang outbound_distance
assert_eq(w.outbound_distance, 100.0)  # 原 200.0

# 第 40 行: laser beam_range
assert_eq(w.beam_range, 200.0)  # 原 400.0

# 第 54 行: normal enemy speed
assert_eq(e.speed, 50.0)  # 原 100.0

# 第 62 行: fast enemy speed
assert_eq(e.speed, 90.0)  # 原 180.0

# 第 69 行: tank enemy speed
assert_eq(e.speed, 25.0)  # 原 50.0

# 第 86 行: shooter tower range
assert_almost_eq(t.attack_range_per_level[0], 150.0, 0.001)  # 原 300.0

# 第 97 行: slow tower range
assert_almost_eq(t.attack_range_per_level[0], 100.0, 0.001)  # 原 200.0

# 第 131 行: character speed
assert_eq(c.speed, 100.0)  # 原 200.0

# 第 196 行: PLAYER initial_speed
assert_eq(GameConfig.PLAYER["initial_speed"], 100.0)  # 原 200.0
```

- [ ] **Step 2: 更新 test_enemy_spawning.gd 断言**

```gdscript
# 第 67 行: fast enemy speed threshold
assert_gt(fast_enemy.speed, 50.0, "Fast enemy should have high speed")  # 原 100.0
```

- [ ] **Step 3: Commit**

```bash
git add tests/unit/test_resource_loading.gd tests/integration/test_enemy_spawning.gd
git commit -m "test: 更新物理参数 ×0.5 后的测试断言值"
```

---

### Task 7: 运行全部测试验证

- [ ] **Step 1: 运行全部测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 全部通过（314+ 测试），0 失败。

- [ ] **Step 2: 如有失败，修复并重跑**

常见问题：
- 某些测试可能还有其他硬编码数值断言未发现，根据失败信息修改
- `boomerang_return_distance` (7.5px) 若回旋镖行为异常，调至 10.0

- [ ] **Step 3: 最终 Commit**

根据失败信息定位并修复相关文件，然后 commit（添加具体修改的文件而非 `git add -A`）。

---

## 验证清单

完成所有任务后，执行以下端到端验证：

1. **像素字体**: 启动游戏，确认所有 UI 文字无抗锯齿
2. **布置场景**: 进入布置阶段，确认初始视角能清晰看到网格和塔
3. **战斗体验**: 玩一局完整战斗，观察：
   - 子弹/回旋镖飞行速度是否匹配地图比例
   - 金币吸附范围是否合理
   - 敌人移动速度是否协调
   - 塔攻击范围覆盖是否合理
   - Boss 冲锋距离是否合适
4. **测试全通过**: 确认所有测试无失败
