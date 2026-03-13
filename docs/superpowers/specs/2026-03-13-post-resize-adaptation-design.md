# 尺寸调整后适配方案设计

## 背景

项目之前将整体游戏基准尺寸和实体尺寸缩小约一半（视口 640x360，网格 16px，实体 16px 标准），但以下三个方面未同步调整：
1. UI 字体仍为 Godot 默认矢量字体，不符合像素游戏风格
2. 布置场景初始缩放 37.5% 太远，看不清网格和塔
3. 物理参数（速度、范围、距离）仍为旧值，相对于缩小后的地图显得过大

## 方案概述

### 1. UI 像素字体 — 项目级 Theme 方案

创建全局 Theme 资源，配置默认字体渲染为像素风格，在 project.godot 中设为默认 Theme。

**实现细节：**
- 创建自定义 FontFile 资源 `assets/themes/pixel_font.tres`，基于 Godot 内置默认字体，配置渲染属性：
  - `antialiasing = FONT_ANTIALIASING_NONE`
  - `hinting = FONT_HINTING_NONE`
  - `subpixel_positioning = SUBPIXEL_POSITIONING_DISABLED`
- 创建 `assets/themes/default_theme.tres`（Theme 资源），将上述 FontFile 设为 `default_font`
- 在 `project.godot` 中设置 `gui/theme/custom = "res://assets/themes/default_theme.tres"`
- 所有现有 UI 自动继承，无需逐个修改

> **注意**: Godot Theme 不直接暴露字体渲染属性，需先创建 FontFile 资源配置渲染参数，再赋给 Theme 的 default_font。

**需修改的文件：**
- `project.godot` — 添加 custom theme 路径
- 新建 `assets/themes/default_theme.tres` — Theme 资源

### 2. 布置场景初始缩放 — 0.375 → 0.75

**实现细节：**
- 修改 `scripts/ui/placement.gd` 中 `PLACEMENT_ZOOM_INIT` 从 `Vector2(0.375, 0.375)` 改为 `Vector2(0.75, 0.75)`
- `CAMERA_PAN_SPEED` 从 600.0 改为 300.0（缩放后平移速度也需同步缩小）

**需修改的文件：**
- `scripts/ui/placement.gd` — PLACEMENT_ZOOM_INIT, CAMERA_PAN_SPEED

### 3. 物理参数统一 ×0.5

所有距离/速度/范围参数乘以 0.5。时间、比率、颜色、数量等不变。

#### 3.1 需要缩放的参数（×0.5）

**角色速度** (`resources/characters/*.tres`)：
| 参数 | 当前 | → 新值 |
|------|------|--------|
| speed (所有5角色) | 200.0 | 100.0 |

**GameConfig PLAYER 常量** (`scripts/core/game_config.gd`)：
| 参数 | 当前 | → 新值 |
|------|------|--------|
| initial_speed | 200.0 | 100.0 |

**敌人速度** (`resources/enemies/*.tres`)：
| 敌人 | 参数 | 当前 | → 新值 |
|------|------|------|--------|
| normal | speed (默认值) | 100.0 | 50.0 |
| fast | speed | 180.0 | 90.0 |
| tank | speed | 50.0 | 25.0 |
| boss_brute | speed | 60.0 | 30.0 |
| boss_summoner | speed | 50.0 | 25.0 |
| boss_guardian | speed | 40.0 | 20.0 |

**Boss 距离参数** (`scripts/entities/boss_brute.gd`)：
| 参数 | 当前 | → 新值 |
|------|------|--------|
| _min_charge_distance | 80.0 | 40.0 |

**敌人生成距离** (`scripts/resources/spawn_config_data.gd` + `scripts/systems/enemy_spawner.gd`)：
| 参数 | 当前 | → 新值 |
|------|------|--------|
| SpawnConfigData.min_distance_from_player | 150.0 | 75.0 |
| enemy_spawner.gd fallback min_distance_from_player | 200.0 | 100.0 |

**武器 .tres 文件** (`resources/weapons/*.tres`)：

> **注意**: bullet_speed、knockback_force、boomerang_speed、outbound_distance 等参数在 .tres 文件中未显式设置，使用 weapon_data.gd 的脚本默认值。只需修改 weapon_data.gd 默认值即可。.tres 文件只需修改 weapon_range_per_level。

| 武器 | 参数 | 当前 | → 新值 |
|------|------|------|--------|
| rifle | weapon_range_per_level | [300,320,340,370,400] | [150,160,170,185,200] |
| boomerang | weapon_range_per_level | [200,220,240,260,300] | [100,110,120,130,150] |
| laser | weapon_range_per_level | [400,430,460,500,550] | [200,215,230,250,275] |

**投射物脚本默认值** (`scripts/entities/projectiles/*.gd`)：
| 参数 | 当前 | → 新值 |
|------|------|--------|
| BulletProjectile.speed | 600.0 | 300.0 |
| BoomerangProjectile.speed | 350.0 | 175.0 |
| BoomerangProjectile.outbound_distance | 200.0 | 100.0 |
| LaserProjectile.beam_range | 400.0 | 200.0 |

**塔攻击范围** (`resources/towers/*.tres`)：
| 塔 | 参数 | 当前 | → 新值 |
|----|------|------|--------|
| shooter | attack_range_per_level | [300,320,340,370,400] | [150,160,170,185,200] |
| slow | attack_range_per_level | [200,220,240,260,300] | [100,110,120,130,150] |

**金币吸附** (`scripts/entities/coin.gd`)：
| 参数 | 当前 | → 新值 |
|------|------|--------|
| attract_range | 150.0 | 75.0 |
| attract_speed | 500.0 | 250.0 |

**特效距离参数** (`scripts/resources/effect_config_data.gd` 默认值)：
| 参数 | 当前 | → 新值 |
|------|------|--------|
| knockback_distance | 15.0 | 7.5 |
| damage_number_float_distance | 30.0 | 15.0 |
| damage_number_random_offset_x | 10.0 | 5.0 |
| death_particle_spread | 20.0 | 10.0 |
| death_particle_gravity | 200.0 | 100.0 |
| death_particle_speed_min | 50.0 | 25.0 |
| death_particle_speed_max | 120.0 | 60.0 |
| hit_spark_spread_speed | 100.0 | 50.0 |
| bullet_trail_length | 15.0 | 7.5 |
| boomerang_return_distance | 15.0 | 7.5 |
| camera_look_ahead_distance | 40.0 | 20.0 |
| camera_shake_player_hit_intensity | 3.0 | 1.5 |
| camera_shake_enemy_kill_intensity | 2.0 | 1.0 |
| camera_shake_wave_start_intensity | 5.0 | 2.5 |
| laser_flash_size | Vector2(2000,2000) | Vector2(1000,1000) |
| muzzle_flash_size | Vector2(6,6) | Vector2(3,3) |

**WeaponData 默认值** (`scripts/resources/weapon_data.gd`)：
| 参数 | 当前 | → 新值 |
|------|------|--------|
| bullet_speed | 600.0 | 300.0 |
| boomerang_speed | 350.0 | 175.0 |
| boomerang_outbound_distance | 200.0 | 100.0 |
| knockback_force | 80.0 | 40.0 |
| beam_range | 400.0 | 200.0 |

#### 3.2 不需要缩放的参数

以下参数类型保持不变：
- **时间/持续时间**: fire_rate, knockback_duration, beam_duration, 所有 _duration 参数
- **比率/倍数**: slow_ratio, return_speed_mult, FORCE_ATTRACT_SPEED_MULT, charge_speed_mult
- **颜色**: 所有 Color 参数
- **数量/计数**: particle_count, trail_max_points, bullet_count
- **透明度/Z轴**: alpha 值, z_index
- **角速度**: boomerang_rotation_speed (720.0°/s)
- **相机平滑**: camera_smoothing_speed, camera_dead_zone
- **宽度类视觉参数**: bullet_trail_width, boomerang_trail_width, laser_beam_width, beam_width（像素级宽度，不缩）
- **laser_beam_hitbox_height** (8.0): 待测试评估，若碰撞检测过大则缩至 4.0
- **HP/伤害**: 数值平衡不变
- **金币/价格**: 经济系统不变
- **boomerang_max_lifetime**: 时间参数，保持 5.0s

## 需修改的文件完整列表

| 文件 | 修改内容 |
|------|---------|
| `project.godot` | 添加 custom theme 路径 |
| 新建 `assets/themes/default_theme.tres` | 全局 Theme 资源 |
| `scripts/ui/placement.gd` | PLACEMENT_ZOOM_INIT, CAMERA_PAN_SPEED |
| `scripts/core/game_config.gd` | PLAYER.initial_speed |
| `scripts/resources/weapon_data.gd` | bullet_speed, boomerang_speed, outbound_distance, knockback_force, beam_range 默认值 |
| `scripts/resources/effect_config_data.gd` | 所有距离/速度类默认值 |
| `scripts/entities/coin.gd` | attract_range, attract_speed |
| `scripts/entities/projectiles/bullet_projectile.gd` | speed 默认值 |
| `scripts/entities/projectiles/boomerang_projectile.gd` | speed, outbound_distance 默认值 |
| `resources/characters/dora.tres` | speed |
| `resources/characters/gorg.tres` | speed |
| `resources/characters/kaze.tres` | speed |
| `resources/characters/merlin.tres` | speed |
| `resources/characters/nemo.tres` | speed |
| `resources/enemies/normal.tres` | speed (需补充) |
| `resources/enemies/fast.tres` | speed |
| `resources/enemies/tank.tres` | speed |
| `resources/enemies/boss_brute.tres` | speed |
| `resources/enemies/boss_summoner.tres` | speed |
| `resources/enemies/boss_guardian.tres` | speed |
| `scripts/entities/boss_brute.gd` | _min_charge_distance |
| `scripts/resources/spawn_config_data.gd` | min_distance_from_player 默认值 |
| `scripts/systems/enemy_spawner.gd` | min_distance_from_player fallback 值 |
| `scripts/entities/projectiles/laser_projectile.gd` | beam_range 默认值 |
| `resources/weapons/rifle.tres` | weapon_range_per_level |
| `resources/weapons/boomerang.tres` | weapon_range_per_level |
| `resources/weapons/laser.tres` | weapon_range_per_level |
| `resources/towers/shooter.tres` | attack_range_per_level |
| `resources/towers/slow.tres` | attack_range_per_level |
| `tests/unit/test_resource_loading.gd` | 更新所有断言值（speed、range、bullet_speed 等约 11 处） |

## 验证方案

1. **像素字体**：启动游戏，检查所有 UI 文字是否呈现像素风格（无抗锯齿平滑）
2. **布置场景**：进入布置阶段，确认初始视角能清晰看到网格线和已放置的塔
3. **物理参数**：
   - 运行战斗，观察子弹/回旋镖飞行速度是否匹配缩小后的地图比例
   - 确认金币吸附范围合理
   - 确认敌人移动速度与地图比例协调
   - 确认塔的攻击范围覆盖合理区域
4. **更新测试断言**：`tests/unit/test_resource_loading.gd` 中约 11 处数值断言需同步更新为新值
5. **运行测试**：执行全部测试确保无回归
   ```bash
   /Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
   ```
6. **待评估**: boomerang_return_distance (7.5px) 在半尺寸下可能过小，测试时若回旋镖视觉上穿过玩家才消失，可调至 10.0
