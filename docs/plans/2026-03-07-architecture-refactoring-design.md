# 架构重构设计文档

日期：2026-03-07

## 目标

对 utoland 项目进行架构重构，解决当前代码中的耦合、硬编码、结构混乱等问题。

## 重构范围

1. **全局事件总线** — 解耦跨系统直接调用
2. **自定义资源体系** — GameConfig 字典 → Resource 类 + .tres 文件
3. **文件夹结构整理** — 统一目录规范
4. **消除硬编码值** — 散落的魔法数字迁入资源
5. **SpriteFrames 资源化** — 动态创建 → 预生成 .tres
6. **GameConfig 位置整理** — 根目录 → scripts/core/

---

## Phase 1: 事件总线 + 解耦

### EventBus Autoload (`scripts/core/event_bus.gd`)

集中定义所有跨系统信号：

```gdscript
extends Node

# 波次系统
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal game_won()
signal game_lost()

# 战斗事件
signal enemy_killed(enemy_type: String, position: Vector2)
signal player_damaged(damage: int, current_hp: int)
signal player_died()

# 经济事件
signal coins_changed(amount: int, total: int)
signal coin_collected(value: int, position: Vector2)

# 视觉反馈
signal camera_shake_requested(intensity: float, duration: float)

# 塔防事件
signal tower_placed(tower_type: String, position: Vector2)
signal tower_destroyed(tower_type: String, position: Vector2)
```

### 解耦改动

| 现状 | 改为 |
|------|------|
| `player.die()` 直接 emit `wave_manager.game_lost` | `player.die()` emit `EventBus.player_died()` |
| `wave_manager` 直接访问 player camera 节点 | emit `EventBus.camera_shake_requested`，camera_shake 自行连接 |
| `enemy_spawner` 直接调 `wave_manager.get_current_wave_config()` | wave_manager emit `EventBus.wave_started` 时携带配置，或 spawner 读 GameData |
| WaveManager 自身定义 4 个信号 | 迁移到 EventBus |

### 原则

- 实体内部信号（button.pressed、body_entered）保持不变
- 只有跨系统通信走 EventBus

---

## Phase 2: 自定义资源体系

### Resource 类定义 (`scripts/resources/`)

| 类名 | 文件 | 对应 GameConfig |
|------|------|----------------|
| WeaponData | weapon_data.gd | WEAPONS |
| EnemyData | enemy_data.gd | ENEMIES |
| TowerData | tower_data.gd | TOWERS |
| WaveData | wave_data.gd | WAVES |
| CharacterData | character_data.gd | CHARACTERS |
| MapData | map_data.gd | MAPS |
| ShopItemData | shop_item_data.gd | SHOP |
| EffectConfigData | effect_config_data.gd | EFFECTS |
| SpriteConfigData | sprite_config_data.gd | SPRITES |
| ProjectileData | projectile_data.gd | 散落的硬编码值 |

### .tres 资源文件 (`resources/`)

```
resources/
├── weapons/          rifle.tres, shotgun.tres, boomerang.tres, laser.tres
├── enemies/          normal.tres, fast.tres, tank.tres
├── towers/           shooter.tres, wall.tres, slow.tres
├── waves/            wave_01.tres ... wave_10.tres
├── characters/       knight.tres, hunter.tres, monk.tres
├── maps/             grass_field.tres
├── effects/          default_effects.tres
└── sprites/          预生成的 SpriteFrames .tres
```

### GameConfig 重构

从"数值字典中心"变为"资源注册表"：

```gdscript
extends Node

var weapons: Dictionary = {}    # {id: WeaponData}
var enemies: Dictionary = {}    # {type: EnemyData}
var towers: Dictionary = {}     # {type: TowerData}
# ...

func _ready() -> void:
    _load_resources("res://resources/weapons/", weapons)
    _load_resources("res://resources/enemies/", enemies)
    # ...
```

### 实体改动

- SceneFactory 创建实体时传入 Resource（`create_bullet(weapon_data)` 而非让实体自己读配置）
- 实体 `_ready()` 中 `GameConfig.WEAPONS["rifle"]["damage"]` → `weapon_data.damage`
- 硬编码值全部迁入对应 Resource

### SpriteFrames 资源化

- SpriteLoader 预生成 SpriteFrames 为 .tres 文件存入 `resources/sprites/`
- 运行时直接 load .tres 替代动态构建

---

## Phase 3: 文件夹结构整理

### 目标结构

```
res://
├── resources/                    # .tres 资源文件（Phase 2 已创建）
├── scenes/
│   ├── entities/                 # player, bullet, coin, enemies/, towers/
│   ├── ui/                       # start_menu, hud, shop, result, selections
│   ├── levels/                   # main, placement
│   └── shared/                   # map_boundary
├── scripts/
│   ├── core/                     # event_bus, game_config, game_data, scene_factory, sprite_loader
│   ├── resources/                # Resource 类定义
│   ├── entities/                 # player, enemy, bullet, coin, towers/
│   ├── systems/                  # wave_manager, enemy_spawner, shop_manager, effects_manager, camera_shake
│   └── ui/                       # main, start_menu, 各 UI 脚本
├── assets/                       # 原始素材（不动）
├── tests/                        # 测试（更新路径引用）
├── docs/                         # 文档
└── addons/                       # 插件（不动）
```

### 迁移清单

1. `game_config.gd` 根目录 → `scripts/core/`
2. `scenes/player.tscn` 等实体场景 → `scenes/entities/`
3. `scenes/main.tscn`, `scenes/placement.tscn` → `scenes/levels/`
4. `scenes/map_boundary.tscn` → `scenes/shared/`
5. `scenes/character_selection.tscn`, `scenes/weapon_select.tscn`, `scenes/map_select.tscn` → `scenes/ui/`
6. 更新所有 .tscn 中的 `[ext_resource]` 路径
7. 更新 project.godot Autoload 路径
8. 更新测试中的 preload/load 路径

---

## 风险管理

- **每个 Phase 在独立 feature 分支**上进行，完成后合并到 develop
- **每步改动后跑全量测试**（115 个测试），确保不破坏功能
- 路径迁移使用 Godot 的资源引用更新机制，手动验证 .tscn 文件
- Phase 3 路径迁移是风险最高的部分，需要逐文件检查引用

## 当前已知的硬编码值

| 文件 | 位置 | 值 | 应迁入 |
|------|------|-----|--------|
| bullet.gd:3 | speed | 400.0 | WeaponData.bullet_speed |
| bullet.gd:11 | TRAIL_MAX_POINTS | 4 | ProjectileData.trail_length |
| boomerang.gd:75 | return distance | 15.0 | ProjectileData.return_distance |
| coin.gd:45 | attract_speed | 800.0 | GameConfig 或 Resource |
| coin.gd:21,26 | attract range/speed | 100/150/500 | Resource |
| enemy_spawner.gd:12 | min_distance | 200.0 | spawn 配置 Resource |
| effects_manager.gd | z_index | 100/50 | EffectConfigData |
| effects_manager.gd:91 | particle speed | 50-120 | EffectConfigData |
| player.gd:190 | laser query limit | 20 | WeaponData |
| player.gd:182 | collision_mask | 2 | WeaponData |
| player.gd:215 | flash size | 2000x2000 | EffectConfigData |
| sprite_loader.gd:108 | hysteresis | 0.7/1.4 | SpriteConfigData |
