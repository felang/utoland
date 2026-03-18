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

### 3. 武器资源 (`resources/weapons/*.tres`) — 空间值 ×2

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

### 4. 塔资源 (`resources/towers/*.tres`) — 射程 ×2

**pea_shooter.tres:**
| 字段 | 旧值 | 新值 |
|------|------|------|
| attack_range_per_level | [150, 170, 200] | [300, 340, 400] |

**ice_flower.tres:**
| 字段 | 旧值 | 新值 |
|------|------|------|
| attack_range_per_level | [100, 120, 150] | [200, 240, 300] |

**sunflower.tres:** 无空间值，不需要改。

### 5. 敌人资源 (`resources/enemies/*.tres`) — 速度 ×2

| 敌人 | 旧 speed | 新 speed |
|------|---------|---------|
| normal | 50.0 | 100.0 |
| fast | 90.0 | 180.0 |
| tank | 25.0 | 50.0 |
| boss_brute | 30.0 | 60.0 |
| boss_summoner | 25.0 | 50.0 |
| boss_guardian | 20.0 | 40.0 |

### 6. 投射物资源 (`resources/projectiles/*.tres`) — 速度 ×2

| 投射物 | 旧 speed | 新 speed |
|--------|---------|---------|
| arrow | 300.0 | 600.0 |
| pea_bullet | 800.0 | 1600.0 |
| shuriken | 175.0 | 350.0 |
| ice_bullet | 800.0 | 1600.0 |

### 7. 近战配置 (`resources/projectiles/sword_melee.tres`) — 空间值 ×2

| 字段 | 旧值 | 新值 |
|------|------|------|
| hit_radius | 14.0 | 28.0 |
| knockback_force | 80.0 | 160.0 |
| hit_angle | 90.0 | 90.0 (不变) |

### 8. 脚本硬编码空间值 — ×2

**exp_orb.gd:**
| 常量 | 旧值 | 新值 |
|------|------|------|
| ATTRACT_RANGE | 30.0 | 60.0 |
| ATTRACT_SPEED | 200.0 | 400.0 |

**coin.gd:**
| 常量 | 旧值 | 新值 |
|------|------|------|
| ATTRACT_RANGE | 75.0 | 150.0 |
| ATTRACT_SPEED | 250.0 | 500.0 |

**map_boundary.gd:**
| 常量 | 旧值 | 新值 |
|------|------|------|
| WALL_THICKNESS | 16.0 | 32.0 |

map_boundary.gd 中的墙体位置/尺寸从 GameConfig 计算得出，修改 GameConfig 常量后自动适配。

**main.gd:**
| 常量 | 旧值 | 新值 |
|------|------|------|
| SHOP_CAMERA_POS | Vector2(-98, 0) | Vector2(-196, 0) |
| Battle camera limits | ±272, ±208 | ±720, ±480 |

SHOP_ZOOM 保持 0.82 不变（相对缩放比例）。

**drag_manager.gd:**
网格转换公式使用 GameConfig.GRID_SIZE / MAP_HALF_WIDTH / MAP_HALF_HEIGHT，修改 GameConfig 后自动适配。确认没有硬编码数字即可。

### 9. 场景文件 (.tscn) — 碰撞体 ×2

**player.tscn:**
| 组件 | 旧值 | 新值 |
|------|------|------|
| Body CollisionShape | RectangleShape2D(16, 16) | RectangleShape2D(32, 32) |
| Hurtbox CircleShape2D | radius 6.5 | radius 13.0 |
| ColorRect (临时视觉) | 16×16 | 32×32 (或 scale 2x) |

**map_boundary.tscn:**
墙体位置和碰撞体尺寸需要重新计算（由 map_boundary.gd _ready() 动态设置的话不需要改 .tscn）。确认是脚本动态设置还是 .tscn 写死。

**敌人场景 (enemies/*.tscn):**
碰撞体 ×2，精灵节点 scale = Vector2(2, 2)。

**塔场景 (towers/*.tscn):**
碰撞体 ×2，精灵节点 scale = Vector2(2, 2)。

**投射物场景 (projectiles/*.tscn):**
碰撞体 ×2，精灵节点 scale = Vector2(2, 2)。

### 10. 精灵显示 — 16px 素材 scale 2x

所有使用 16px 素材的实体需要在场景中设置 sprite scale = Vector2(2, 2)：
- 角色精灵
- 敌人精灵（通过 SpriteAnimator 创建，需检查是否支持 scale 参数）
- 塔精灵
- 武器精灵
- 投射物精灵
- 金币、经验球精灵

如果 SpriteAnimator 或 SpriteLoader 中有基于 frame_size 的缩放逻辑，需要更新 `sprite_pixel_size` 或缩放因子。

### 11. UI 常量 (`ui_constants.gd`) — 按 1.5x 调整

视口从 640×360 → 960×540（1.5 倍），UI 元素按 1.5 倍等比放大：

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

注意：字体大小取整到合理值，像素风字体可能需要整数倍。

### 12. Boss 特有空间值

**boss_brute.tres:**
- charge_speed_multiplier: 4.0 — 不变（倍率）
- charge_damage_multiplier: 2.0 — 不变（倍率）

Boss 的冲刺速度 = speed × charge_speed_multiplier，speed 已 ×2，冲刺速度自动 ×2。

## 不需要修改的内容

- 伤害数值（HP、damage、damage_reduction）
- 经济数值（金币、价格、经验值）
- 时间相关数值（fire_rate、cooldown、wave_time_limit、generate_interval）
- 减速比例（slow_ratio、slow_duration）
- 游戏逻辑（合成、波次流程、信号系统）
- 动画帧率
- 场景切换流程
- FORCE_ATTRACT_SPEED_MULTIPLIER（倍率，不变）

## 验证要点

1. 玩家在新地图上移动速度是否合理（需检查 player.gd 移动速度是否也需 ×2）
2. 相机跟随在大地图上的表现
3. 商店 UI 在 960×540 视口下的布局
4. 塔放置网格对齐是否正确
5. 敌人生成位置（EnemySpawner 的生成范围是否依赖地图尺寸）
6. 特效尺寸（EffectsManager 中的伤害数字、击中火花等）
