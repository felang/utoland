# 网格单位迁移设计：16px → 32px

## 背景

美术资源规格改动，需要使用 32px 网格单位、1440×960 地图。当前 16px 精灵素材暂不更换，通过 scale 2x 显示。

## 核心参数变更

| 参数 | 旧值 | 新值 | 说明 |
|------|------|------|------|
| PPU / GRID_SIZE | 16 | 32 | ×2 |
| 视口 | 640×360 | 960×540 | 1080p 的 2x 整数缩放 |
| 地图像素 | 544×416 | 1440×960 | 新地图尺寸 |
| 地图格数 | 34×26 | 45×30 | 1440/32, 960/32 |
| 精灵基础尺寸 | 16px | 16px (scale 2x) | 暂不更换素材 |

## 修改清单

### 1. project.godot — 视口设置

```
viewport/width: 640 → 960
viewport/height: 360 → 540
```

### 2. GameConfig (`scripts/core/game_config.gd`) — 核心常量

| 常量 | 旧值 | 新值 |
|------|------|------|
| BASE_VIEWPORT_WIDTH | 640 | 960 |
| BASE_VIEWPORT_HEIGHT | 360 | 540 |
| PPU | 16 | 32 |
| GRID_SIZE | 16 | 32 |
| MAP_GRID_WIDTH | 34 | 45 |
| MAP_GRID_HEIGHT | 26 | 30 |
| MAP_PIXEL_WIDTH | 544 (34×16) | 1440 (45×32) |
| MAP_PIXEL_HEIGHT | 416 (26×16) | 960 (30×32) |
| MAP_HALF_WIDTH | 272.0 | 720.0 |
| MAP_HALF_HEIGHT | 208.0 | 480.0 |
| ENTITY_SIZE_STANDARD | 16 | 32 |
| ENTITY_SIZE_TANK | 32 | 64 |
| BULLET_SIZE | 3 | 6 |
| COIN_RADIUS | 3 | 6 |
| PLAYER.initial_speed | 100.0 | 200.0 |

注意：`SPRITES` 字典中的 `frame_size`（如 `Vector2(16, 16)`）是源素材像素尺寸，**不要改**。`SpriteAnimator._apply_scale()` 会用 `target_size / sprite_size` 自动计算缩放，`ENTITY_SIZE_STANDARD` 改为 32 后，16px 素材自动 scale 2x。

### 3. 角色资源 (`resources/characters/*.tres`) — 速度 ×2

| 角色 | 旧 speed | 新 speed |
|------|---------|---------|
| dora | 100.0 | 200.0 |
| kaze | 130.0 | 260.0 |
| gorg | (查实际值) | ×2 |
| merlin | (查实际值) | ×2 |
| nemo | (查实际值) | ×2 |

### 4. 武器资源 (`resources/weapons/*.tres`) — 空间值 ×2

**bow.tres:**
| 字段 | 旧值 | 新值 |
|------|------|------|
| attack_range_per_level | [150, 170, 200] | [300, 340, 400] |
| pivot_offset | 15.0 | 30.0 |

**sword.tres:**
| 字段 | 旧值 | 新值 |
|------|------|------|
| attack_range_per_level | [50, 50, 50] | [100, 100, 100] |
| pivot_offset | 10.0 | 20.0 |

**shuriken.tres:**
| 字段 | 旧值 | 新值 |
|------|------|------|
| attack_range_per_level | [100, 120, 150] | [200, 240, 300] |
| pivot_offset | 20.0 | 40.0 |

### 5. 塔资源 (`resources/towers/*.tres`) — 射程 ×2

**pea_shooter.tres:**
| 字段 | 旧值 | 新值 |
|------|------|------|
| attack_range_per_level | [150, 170, 200] | [300, 340, 400] |

**ice_flower.tres:**
| 字段 | 旧值 | 新值 |
|------|------|------|
| attack_range_per_level | [100, 120, 150] | [200, 240, 300] |

**sunflower.tres:** 无空间值，不需要改。

### 6. 敌人资源 (`resources/enemies/*.tres`) — 速度 ×2

| 敌人 | 旧 speed | 新 speed |
|------|---------|---------|
| normal | 50.0 | 100.0 |
| fast | 90.0 | 180.0 |
| tank | 25.0 | 50.0 |
| boss_brute | 30.0 | 60.0 |
| boss_summoner | 25.0 | 50.0 |
| boss_guardian | 20.0 | 40.0 |

### 7. 投射物资源 (`resources/projectiles/*.tres`) — 速度 ×2

| 投射物 | 旧 speed | 新 speed |
|--------|---------|---------|
| arrow | 300.0 | 600.0 |
| pea_bullet | 800.0 | 1600.0 |
| shuriken | 175.0 | 350.0 |
| ice_bullet | 800.0 | 1600.0 |

### 8. 近战配置 (`resources/projectiles/sword_melee.tres`) — 空间值 ×2

| 字段 | 旧值 | 新值 |
|------|------|------|
| hit_radius | 14.0 | 28.0 |
| knockback_force | 80.0 | 160.0 |
| hit_angle | 90.0 | 90.0 (不变) |

### 9. 生成配置 (`resources/spawn/default_spawn.tres` / `spawn_config_data.gd`)

| 字段 | 旧值 | 新值 |
|------|------|------|
| min_distance_from_player | 75.0 | 150.0 |

`enemy_spawner.gd` 中的 fallback 默认值 `100.0` → `200.0`。

### 10. 脚本硬编码空间值 — ×2

**exp_orb.gd** (注：实际为 @export var，非 const)：
| 字段 | 旧值 | 新值 |
|------|------|------|
| attract_range | 30.0 | 60.0 |
| attract_speed | 200.0 | 400.0 |

`reset_for_pool()` 中的硬编码重置值也需同步更新。

**coin.gd** (注：实际为 @export var，非 const)：
| 字段 | 旧值 | 新值 |
|------|------|------|
| attract_range | 75.0 | 150.0 |
| attract_speed | 250.0 | 500.0 |

`reset_for_pool()` 中的硬编码重置值也需同步更新。

**map_boundary.gd:**
| 常量 | 旧值 | 新值 |
|------|------|------|
| WALL_THICKNESS | 16.0 | 32.0 |

map_boundary.gd 中的墙体位置/尺寸从 GameConfig 计算得出，修改 GameConfig 常量后自动适配。

**main.gd:**
| 常量 | 旧值 | 新值 |
|------|------|------|
| SHOP_CAMERA_POS | Vector2(-98, 0) | Vector2(-196, 0) |
| SHOP_ZOOM | 0.82 | ~0.56 |
| Battle camera limits | ±272, ±208 | ±720, ±480 |
| _get_clamped_camera_pos() 中硬编码 640.0/360.0 | 640.0, 360.0 | 改用 GameConfig.BASE_VIEWPORT_WIDTH/HEIGHT |

SHOP_ZOOM 需重算：旧值 `0.82 < 360/416 = 0.865` 可显示全地图高度。新地图 `540/960 = 0.5625`，SHOP_ZOOM 应设为 ~0.56 以显示全地图高度。

**enemy.gd:**
| 常量 | 旧值 | 新值 |
|------|------|------|
| COIN_SCATTER_RANGE | 20.0 | 40.0 |
| EXP_SCATTER_RANGE | 20.0 | 40.0 |

**boss_brute.gd:**
| 字段 | 旧值 | 新值 |
|------|------|------|
| _min_charge_distance | 40.0 | 80.0 |

**drag_manager.gd:**
网格转换公式使用 GameConfig.GRID_SIZE / MAP_HALF_WIDTH / MAP_HALF_HEIGHT，修改 GameConfig 后自动适配。确认没有硬编码数字即可。

### 11. 特效系统 — 空间值 ×2

**EffectsManager (`scripts/systems/effects_manager.gd`):**
| 常量 | 旧值 | 新值 |
|------|------|------|
| HIT_SPARK_SIZE | Vector2(2, 2) | Vector2(4, 4) |
| DEATH_PARTICLE_SIZE | Vector2(3, 3) | Vector2(6, 6) |
| spawn_enhanced_death flash_rect | Vector2(12, 12) | Vector2(24, 24) |
| sprite_shake 默认 amount | 2.0 | 4.0 |

**EffectConfigData (`scripts/resources/effect_config_data.gd`) — 空间默认值 ×2:**
| 字段 | 旧值 | 新值 |
|------|------|------|
| knockback_distance | 7.5 | 15.0 |
| damage_number_float_distance | 15.0 | 30.0 |
| damage_number_random_offset_x | 5.0 | 10.0 |
| death_particle_speed_min | 25.0 | 50.0 |
| death_particle_speed_max | 60.0 | 120.0 |
| hit_spark_spread_speed | 50.0 | 100.0 |
| bullet_trail_length | 7.5 | 15.0 |
| bullet_trail_width | 2.0 | 4.0 |
| shuriken_return_distance | 7.5 | 15.0 |
| shuriken_trail_width | 3.0 | 6.0 |
| camera_look_ahead_distance | 20.0 | 40.0 |
| muzzle_flash_size | Vector2(3, 3) | Vector2(6, 6) |
| laser_beam_width | 3.0 | 6.0 |
| laser_beam_hitbox_height | 8.0 | 16.0 |

**enemy.gd 中 sprite_shake 调用：**
硬编码 `2.0` → `4.0`。

### 12. 场景文件 (.tscn) — 碰撞体 ×2

**player.tscn:**
| 组件 | 旧值 | 新值 |
|------|------|------|
| Body CollisionShape | RectangleShape2D(16, 16) | RectangleShape2D(32, 32) |
| Hurtbox CircleShape2D | radius 6.5 | radius 13.0 |
| ColorRect (临时视觉) | 16×16 | 32×32 (或 scale 2x) |

**map_boundary.tscn:**
墙体位置和碰撞体尺寸由 map_boundary.gd `_ready()` 动态设置（需确认）。若是 .tscn 写死则需更新。

**敌人场景 (enemies/*.tscn):**
碰撞体 ×2。精灵由 SpriteAnimator 动态创建，`ENTITY_SIZE_STANDARD` 改后自动 scale 2x。

**塔场景 (towers/*.tscn):**
碰撞体 ×2，精灵节点 scale = Vector2(2, 2)。

**投射物场景 (projectiles/*.tscn):**
碰撞体 ×2，精灵节点 scale = Vector2(2, 2)。

### 13. UI — 视口 1.5x 调整

**ui_constants.gd** — 按 ×1.5 调整：

| 常量 | 旧值 | 新值 |
|------|------|------|
| UI_BUTTON_SIZE | (160, 36) | (240, 54) |
| UI_BUTTON_SMALL_SIZE | (120, 32) | (180, 48) |
| UI_MAP_CARD_SIZE | (240, 140) | (360, 210) |
| UI_RESULT_PANEL_SIZE | (320, 220) | (480, 330) |
| UI_SHOP_PANEL_SIZE | (560, 300) | (840, 450) |
| UI_CARD_GAP | 20 | 30 |
| HUD_BAR_WIDTH | 80 | 120 |
| HUD_HP_BAR_HEIGHT | 10 | 15 |
| HUD_XP_BAR_HEIGHT | 8 | 12 |
| FONT_SIZE_TITLE | 32 | 48 |
| FONT_SIZE_SUBTITLE | 24 | 36 |
| FONT_SIZE_BODY | 18 | 27 |
| FONT_SIZE_SMALL | 14 | 21 |
| FONT_SIZE_TINY | 12 | 18 |
| MARGIN_SCREEN | 12 | 18 |
| MARGIN_PANEL | 16 | 24 |
| GAP_ITEMS | 12 | 18 |
| GAP_SECTIONS | 20 | 30 |

**shop_overlay.gd 硬编码 UI 值：**
| 字段 | 旧值 | 新值 |
|------|------|------|
| CARD_ICON_SIZE | Vector2(16, 16) | Vector2(24, 24) |
| recycle_area minimum height | 40 | 60 |
| 硬编码字体大小 9 | 9 | 14 |

### 14. Boss 特有空间值

**boss_brute.tres:**
- charge_speed_multiplier: 4.0 — 不变（倍率，speed 已 ×2，冲刺速度自动 ×2）
- charge_damage_multiplier: 2.0 — 不变（倍率）

**boss_brute.gd:**
- `_min_charge_distance`: 40.0 → 80.0（见第 10 节）

## 不需要修改的内容

- 伤害数值（HP、damage、damage_reduction）
- 经济数值（金币、价格、经验值）
- 时间相关数值（fire_rate、cooldown、wave_time_limit、generate_interval）
- 减速比例（slow_ratio、slow_duration）
- 游戏逻辑（合成、波次流程、信号系统）
- 动画帧率
- 场景切换流程
- FORCE_ATTRACT_SPEED_MULTIPLIER（倍率，不变）
- `SPRITES` 字典中的 `frame_size`（源素材像素尺寸，不变）
- 塔 sprite 的 tileset region_rect（源素材像素位置，不变）

## 验证要点

1. 玩家移动速度在新地图上体感是否合理
2. 相机跟随和 SHOP_ZOOM 在大地图上的表现
3. 商店 UI 在 960×540 视口下的布局
4. 塔放置网格对齐是否正确（32px 格子）
5. 敌人生成位置（边界外生成 + min_distance_from_player）
6. 特效尺寸（伤害数字、击中火花、死亡粒子）
7. 精灵缩放（16px 素材在 32px 格子中的显示）
8. 碰撞体大小与视觉匹配
