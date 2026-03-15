# 美术资源文件夹重组设计

**日期**: 2026-03-15
**状态**: 已批准

## 背景

项目即将进入大量美术资源导入阶段，当前 `assets/` 目录结构存在以下问题：

1. `sprites/` 目录混杂了敌人、玩家、弹道、塔、物品等不同类型素材
2. 角色 `.ase` 源文件和导出 `.png` 混放
3. 缺少 `bgm/`、`effects/`、`ui/`、`weapons/` 等目录
4. 实体素材没有按个体分子目录，不便扩展

## 设计原则

- **混合分类**：实体类素材按实体分（characters/enemies/towers/weapons），通用素材按类型分（ui/effects/tilesets）
- **源文件分离**：Aseprite 等源文件放 `assets_source/`，导出的最终资源放 `assets/`
- **每个实体一个子目录**：便于后续添加 icon、动画、多级精灵等

## 目标结构

### `assets/`（导出的最终资源）

```
assets/
├── characters/                # 角色素材
│   ├── kaze/
│   │   ├── portrait.png
│   │   ├── sprite.png
│   │   └── sprite.res         # SpriteFrames 运行时资源
│   ├── nemo/
│   ├── dora/
│   ├── gorg/                  # 注意：原文件名 Gorg 大写，统一改小写
│   └── merlin/
├── enemies/                   # 敌人素材（从 sprites/enemies/ 迁移）
│   ├── slime/
│   │   └── sprite.png
│   ├── bluebat/
│   │   └── sprite.png
│   ├── trex/
│   │   ├── sprite.png
│   │   └── sprite_large.png
│   └── (未来新敌人...)
├── towers/                    # 塔素材（从 sprites/towers/ 迁移）
│   ├── tileset_towers.png     # 共享图集，暂保留整图直到拆分为独立精灵
│   ├── pea_shooter/           # 未来独立精灵放各子目录
│   └── (15种塔各一个子目录)
├── weapons/                   # 武器素材（新建）
│   ├── rifle/
│   ├── boomerang/
│   └── (10种武器各一个子目录)
├── projectiles/               # 弹道素材（从 sprites/projectiles/ 迁移）
│   ├── bullet.png
│   ├── kunai.png
│   └── shuriken.png
├── effects/                   # 特效动画（新建）
│   ├── explosions/
│   ├── hit_sparks/
│   └── skill_effects/
├── ui/                        # UI 素材（新建）
│   ├── icons/
│   ├── panels/
│   ├── buttons/
│   └── fonts/
├── maps/                      # 地图背景
│   └── forest.png
├── tilesets/                  # Tileset 图片
│   ├── forest.png
│   └── gentle-forest.png
├── items/                     # 通用物品（从 sprites/items/ 迁移）
│   └── gold_coin.png
├── sfx/                       # 音效
├── bgm/                       # 背景音乐（新建）
└── themes/                    # UI 主题
    └── default_theme.tres
```

### `assets_source/`（源文件，镜像 `assets/` 实体结构）

```
assets_source/
├── characters/
│   ├── kaze/
│   │   ├── portrait.ase
│   │   └── sprite.ase
│   ├── nemo/
│   ├── dora/
│   ├── gorg/
│   └── merlin/
├── enemies/
├── towers/
├── weapons/
├── effects/
└── ui/
```

## 迁移映射

### 角色（5个，以 kaze 为例，其余 nemo/dora/merlin 同理）

| 原路径 | 新路径 |
|--------|--------|
| `assets/characters/kaze-portrait.png` | `assets/characters/kaze/portrait.png` |
| `assets/characters/kaze-sprite.png` | `assets/characters/kaze/sprite.png` |
| `assets/characters/kaze-sprite.res` | `assets/characters/kaze/sprite.res` |
| `assets/characters/kaze-portrait.ase` | `assets_source/characters/kaze/portrait.ase` |
| `assets/characters/kaze-sprite.ase` | `assets_source/characters/kaze/sprite.ase` |

> **Gorg 特殊处理**：原文件名为大写 `Gorg-*`，迁移时统一改小写 `gorg/`。
> 需同步更新 `resources/characters/gorg.tres` 中的 `sprite_frames_path` 和 `portrait_path`。

### .res 文件说明

`.res` 文件是 Godot 运行时 SpriteFrames 资源，被 `CharacterData.tres` 的 `sprite_frames_path` 引用，属于**运行时资源**，放在 `assets/`（不是 `assets_source/`）。`.ase` 源文件放 `assets_source/`。

### 遗留玩家精灵（删除）

`assets/sprites/player/` 下的 `hunter_idle.png`、`hunter_walk.png`、`knight_idle.png` 等文件无任何 `.gd`/`.tscn`/`.tres` 引用，已被角色 `.res` SpriteFrames 取代。**迁移时直接删除**。

### 敌人

| 原路径 | 新路径 |
|--------|--------|
| `assets/sprites/enemies/slime.png` | `assets/enemies/slime/sprite.png` |
| `assets/sprites/enemies/bluebat.png` | `assets/enemies/bluebat/sprite.png` |
| `assets/sprites/enemies/trex.png` | `assets/enemies/trex/sprite.png` |
| `assets/sprites/enemies/trex_large.png` | `assets/enemies/trex/sprite_large.png` |

### 塔

| 原路径 | 新路径 |
|--------|--------|
| `assets/sprites/towers/tileset_towers.png` | `assets/towers/tileset_towers.png` |

> 共享图集暂保留整图。未来拆分为独立精灵时，放入各塔子目录。

### 弹道

| 原路径 | 新路径 |
|--------|--------|
| `assets/sprites/projectiles/kunai.png` | `assets/projectiles/kunai.png` |
| `assets/sprites/projectiles/shuriken.png` | `assets/projectiles/shuriken.png` |
| `assets/sprites/bullet.png` | `assets/projectiles/bullet.png` |

### 物品

| 原路径 | 新路径 |
|--------|--------|
| `assets/sprites/items/gold_coin.png` | `assets/items/gold_coin.png` |

### 不变

| 目录 | 说明 |
|------|------|
| `assets/maps/` | 地图背景，不变 |
| `assets/tilesets/` | Tileset 图片，不变 |
| `assets/sfx/` | 音效，不变 |
| `assets/themes/` | UI 主题，不变 |

## 需要更新引用的文件（具体清单）

### `scripts/core/game_config.gd`（10 处）

| 旧路径 | 新路径 |
|--------|--------|
| `res://assets/sprites/enemies/slime.png` | `res://assets/enemies/slime/sprite.png` |
| `res://assets/sprites/enemies/bluebat.png` | `res://assets/enemies/bluebat/sprite.png` |
| `res://assets/sprites/enemies/trex_large.png` | `res://assets/enemies/trex/sprite_large.png` |
| `res://assets/sprites/enemies/trex.png` | `res://assets/enemies/trex/sprite.png` |
| `res://assets/sprites/towers/tileset_towers.png` | `res://assets/towers/tileset_towers.png` |
| `res://assets/sprites/projectiles/kunai.png` | `res://assets/projectiles/kunai.png` |
| `res://assets/sprites/projectiles/shuriken.png` | `res://assets/projectiles/shuriken.png` |
| `res://assets/sprites/items/gold_coin.png` | `res://assets/items/gold_coin.png` |

### 塔场景 `.tscn`（9 个文件）

以下场景引用 `res://assets/sprites/towers/tileset_towers.png`，需改为 `res://assets/towers/tileset_towers.png`：

- `scenes/entities/towers/tower_pea_shooter.tscn`
- `scenes/entities/towers/tower_stump.tscn`
- `scenes/entities/towers/tower_ice_flower.tscn`
- `scenes/entities/towers/tower_cactus.tscn`
- `scenes/entities/towers/tower_rose.tscn`
- `scenes/entities/towers/tower_mushroom.tscn`
- `scenes/entities/towers/tower_vine.tscn`
- `scenes/entities/towers/tower_dandelion.tscn`
- `scenes/entities/towers/tower_pitcher.tscn`

### 其他场景

- `scenes/entities/coin.tscn` — `res://assets/sprites/items/gold_coin.png` → `res://assets/items/gold_coin.png`

### 角色 Resource（5 个 .tres 文件）

`resources/characters/` 下 5 个文件的 `sprite_frames_path` 和 `portrait_path` 需更新：

| 文件 | 字段 | 旧值 | 新值 |
|------|------|------|------|
| `kaze.tres` | sprite_frames_path | `res://assets/characters/kaze-sprite.res` | `res://assets/characters/kaze/sprite.res` |
| `kaze.tres` | portrait_path | `res://assets/characters/kaze-portrait.png` | `res://assets/characters/kaze/portrait.png` |
| `nemo.tres` | sprite_frames_path | `res://assets/characters/nemo-sprite.res` | `res://assets/characters/nemo/sprite.res` |
| `nemo.tres` | portrait_path | `res://assets/characters/nemo-portrait.png` | `res://assets/characters/nemo/portrait.png` |
| `dora.tres` | sprite_frames_path | `res://assets/characters/dora-sprite.res` | `res://assets/characters/dora/sprite.res` |
| `dora.tres` | portrait_path | `res://assets/characters/dora-portrait.png` | `res://assets/characters/dora/portrait.png` |
| `gorg.tres` | sprite_frames_path | `res://assets/characters/Gorg-sprite.res` | `res://assets/characters/gorg/sprite.res` |
| `gorg.tres` | portrait_path | `res://assets/characters/Gorg-portrait.png` | `res://assets/characters/gorg/portrait.png` |
| `merlin.tres` | sprite_frames_path | `res://assets/characters/merlin-sprite.res` | `res://assets/characters/merlin/sprite.res` |
| `merlin.tres` | portrait_path | `res://assets/characters/merlin-portrait.png` | `res://assets/characters/merlin/portrait.png` |

## .import 文件处理

每个 PNG/ASE 文件都有对应的 `.import` 文件。迁移步骤：

1. 移动资源文件时，**删除旧的 `.import` 文件**（它们引用旧路径）
2. 迁移完成后清理 `.godot/imported/` 缓存
3. 在 Godot 编辑器中打开项目，编辑器会自动为新路径生成 `.import` 文件

## 新建空目录

以下目录在迁移时创建（放 `.gitkeep` 占位）：

- `assets/weapons/`（及 10 种武器子目录：rifle/boomerang/laser/shotgun/minigun/ice_gun/rocket/lightning/blade/flamethrower）
- `assets/towers/`（15 种塔子目录，即使暂时只有共享图集）
- `assets/effects/explosions/`、`assets/effects/hit_sparks/`、`assets/effects/skill_effects/`
- `assets/ui/icons/`、`assets/ui/panels/`、`assets/ui/buttons/`、`assets/ui/fonts/`
- `assets/bgm/`
- `assets_source/characters/`（5 角色子目录）
- `assets_source/enemies/`、`assets_source/towers/`、`assets_source/weapons/`、`assets_source/effects/`、`assets_source/ui/`

## sprites/ 目录处理

迁移完成后 `assets/sprites/` 目录应为空，直接删除。

## 不变的部分

- `scenes/` 目录结构不动
- `scripts/` 目录结构不动
- `resources/` 目录结构不动（.tres 内的路径引用需更新）
- `assets/sfx/`、`assets/maps/`、`assets/tilesets/`、`assets/themes/` 位置不变

## 风险

- **引用断裂**：迁移后所有引用旧路径的文件都需要更新，遗漏会导致运行时资源加载失败
- **Godot 缓存**：`.godot/imported/` 缓存需要清理重建
- **Git 历史**：使用 `git mv` 保留文件历史追踪

## 验证清单

迁移完成后执行：

1. 全局搜索 `assets/sprites` 确认零命中：`grep -r "assets/sprites" --include="*.gd" --include="*.tscn" --include="*.tres"`
2. 在 Godot 编辑器中打开项目，检查 Output 面板无资源加载错误
3. 运行测试套件确认无回归
4. 手动启动游戏验证角色精灵、敌人精灵、塔精灵、弹道精灵均正常显示
