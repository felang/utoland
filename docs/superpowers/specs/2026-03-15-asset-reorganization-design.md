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
│   │   └── sprite.png
│   ├── nemo/
│   ├── dora/
│   ├── gorg/
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
│   ├── pea_shooter/
│   │   ├── sprite.png         # 或 tileset 裁切后的独立精灵
│   │   └── icon.png
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

| 原路径 | 新路径 |
|--------|--------|
| `assets/characters/kaze-portrait.png` | `assets/characters/kaze/portrait.png` |
| `assets/characters/kaze-sprite.png` | `assets/characters/kaze/sprite.png` |
| `assets/characters/kaze-portrait.ase` | `assets_source/characters/kaze/portrait.ase` |
| `assets/characters/kaze-sprite.ase` | `assets_source/characters/kaze/sprite.ase` |
| `assets/characters/kaze-portrait.res` | `assets_source/characters/kaze/portrait.res` |
| `assets/characters/kaze-sprite.res` | `assets_source/characters/kaze/sprite.res` |
| `assets/sprites/enemies/slime.png` | `assets/enemies/slime/sprite.png` |
| `assets/sprites/enemies/bluebat.png` | `assets/enemies/bluebat/sprite.png` |
| `assets/sprites/enemies/trex.png` | `assets/enemies/trex/sprite.png` |
| `assets/sprites/enemies/trex_large.png` | `assets/enemies/trex/sprite_large.png` |
| `assets/sprites/player/*.png` | `assets/characters/<对应角色>/sprite_*.png` |
| `assets/sprites/towers/tileset_towers.png` | `assets/towers/tileset_towers.png`（暂保留整图） |
| `assets/sprites/projectiles/kunai.png` | `assets/projectiles/kunai.png` |
| `assets/sprites/projectiles/shuriken.png` | `assets/projectiles/shuriken.png` |
| `assets/sprites/bullet.png` | `assets/projectiles/bullet.png` |
| `assets/sprites/items/gold_coin.png` | `assets/items/gold_coin.png` |
| `assets/maps/` | 不变 |
| `assets/tilesets/` | 不变 |
| `assets/sfx/` | 不变 |
| `assets/themes/` | 不变 |

## 需要更新引用的文件

迁移后以下位置的资源路径需要更新：

1. **场景文件 (.tscn)** — 引用精灵纹理的节点
2. **脚本 (.gd)** — `preload()` / `load()` 调用
3. **SpriteLoader** (`scripts/core/sprite_loader.gd`) — 精灵加载路径映射
4. **Resource 文件 (.tres)** — 引用图片的配置
5. **Godot 导入文件 (.import)** — 会自动重新生成

## 新建空目录

以下目录在迁移时创建（放 `.gitkeep` 占位）：

- `assets/weapons/`（及 10 种武器子目录）
- `assets/effects/explosions/`、`assets/effects/hit_sparks/`、`assets/effects/skill_effects/`
- `assets/ui/icons/`、`assets/ui/panels/`、`assets/ui/buttons/`、`assets/ui/fonts/`
- `assets/bgm/`
- `assets_source/`（及镜像子目录）

## 不变的部分

- `scenes/` 目录结构不动
- `scripts/` 目录结构不动
- `resources/` 目录结构不动（.tres 内的路径引用需更新）
- `assets/sfx/`、`assets/maps/`、`assets/tilesets/`、`assets/themes/` 位置不变

## 风险

- **引用断裂**：迁移后所有引用旧路径的文件都需要更新，遗漏会导致运行时资源加载失败
- **Godot 缓存**：`.godot/imported/` 缓存可能需要清理重建
- **Git 历史**：使用 `git mv` 保留文件历史追踪

## 缓解措施

- 迁移后全局搜索旧路径确认无遗漏
- 在 Godot 编辑器中打开项目验证资源加载
- 分步迁移：先移文件 → 更新引用 → 验证 → 提交
