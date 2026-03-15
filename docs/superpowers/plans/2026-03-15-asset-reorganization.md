# 美术资源文件夹重组 实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `assets/` 目录从扁平结构重组为按实体/类型分类的结构，分离源文件到 `assets_source/`，并更新所有代码引用。

**Architecture:** 文件迁移使用 `git mv` 保留历史。分 4 个独立 Task 按依赖顺序执行：创建目录骨架 → 迁移文件 → 更新引用 → 清理验证。每个 Task 独立提交。

**Tech Stack:** Bash (git mv, mkdir), GDScript 路径引用更新

**Spec:** `docs/superpowers/specs/2026-03-15-asset-reorganization-design.md`

---

## Task 1: 创建目标目录骨架

**Files:**
- Create: `assets_source/characters/{kaze,nemo,dora,gorg,merlin}/`
- Create: `assets_source/{enemies,towers,weapons,effects,ui}/`
- Create: `assets/{enemies,towers,weapons,projectiles,items,effects,ui,bgm}/` 及子目录

- [ ] **Step 1: 创建 assets_source/ 目录结构**

```bash
cd /Users/langtao/utoland
for char in kaze nemo dora gorg merlin; do
  mkdir -p assets_source/characters/$char
done
for dir in enemies towers weapons effects ui; do
  mkdir -p assets_source/$dir
done
```

- [ ] **Step 2: 创建 assets/ 新目录结构**

```bash
cd /Users/langtao/utoland
# 敌人子目录
for enemy in slime bluebat trex; do
  mkdir -p assets/enemies/$enemy
done
# 塔子目录
for tower in pea_shooter stump ice_flower cactus rose mushroom vine dandelion pitcher thorn oak sunflower mint heal_flower bamboo; do
  mkdir -p assets/towers/$tower
done
# 武器子目录
for weapon in rifle boomerang laser shotgun minigun ice_gun rocket lightning blade flamethrower; do
  mkdir -p assets/weapons/$weapon
done
# 弹道、物品、特效、UI、BGM
mkdir -p assets/projectiles
mkdir -p assets/items
mkdir -p assets/effects/{explosions,hit_sparks,skill_effects}
mkdir -p assets/ui/{icons,panels,buttons,fonts}
mkdir -p assets/bgm
```

- [ ] **Step 3: 添加 .gitkeep 占位文件**

所有空目录需要 `.gitkeep`，否则 git 不会跟踪。

```bash
cd /Users/langtao/utoland
# assets_source
for char in kaze nemo dora gorg merlin; do
  touch assets_source/characters/$char/.gitkeep
done
for dir in enemies towers weapons effects ui; do
  touch assets_source/$dir/.gitkeep
done
# assets 新目录（有文件要迁入的暂不加，迁入后自然有内容）
for tower in pea_shooter stump ice_flower cactus rose mushroom vine dandelion pitcher thorn oak sunflower mint heal_flower bamboo; do
  touch assets/towers/$tower/.gitkeep
done
for weapon in rifle boomerang laser shotgun minigun ice_gun rocket lightning blade flamethrower; do
  touch assets/weapons/$weapon/.gitkeep
done
touch assets/effects/explosions/.gitkeep
touch assets/effects/hit_sparks/.gitkeep
touch assets/effects/skill_effects/.gitkeep
touch assets/ui/icons/.gitkeep
touch assets/ui/panels/.gitkeep
touch assets/ui/buttons/.gitkeep
touch assets/ui/fonts/.gitkeep
touch assets/bgm/.gitkeep
```

- [ ] **Step 4: 提交目录骨架**

```bash
git add assets_source/ assets/enemies/ assets/towers/ assets/weapons/ assets/projectiles/ assets/items/ assets/effects/ assets/ui/ assets/bgm/
git commit -m "chore: 创建美术资源重组目录骨架"
```

---

## Task 2: 迁移文件

**Files:**
- Move: `assets/characters/*` → `assets/characters/<name>/` 和 `assets_source/characters/<name>/`
- Move: `assets/sprites/enemies/*` → `assets/enemies/<name>/`
- Move: `assets/sprites/towers/*` → `assets/towers/`
- Move: `assets/sprites/projectiles/*` → `assets/projectiles/`
- Move: `assets/sprites/bullet.png` → `assets/projectiles/`
- Move: `assets/sprites/items/*` → `assets/items/`
- Delete: `assets/sprites/player/` (遗留文件)
- Delete: `assets/sprites/` (清空后)

- [ ] **Step 1: 迁移角色文件（kaze/nemo/dora/merlin — 小写名）**

每个角色：`.png` 和 `.res` → `assets/characters/<name>/`，`.ase` → `assets_source/characters/<name>/`。同时删除旧 `.import` 文件。

```bash
cd /Users/langtao/utoland
for char in kaze nemo dora merlin; do
  # 运行时资源 → assets/characters/<name>/
  git mv "assets/characters/${char}-portrait.png" "assets/characters/${char}/portrait.png"
  git mv "assets/characters/${char}-sprite.png" "assets/characters/${char}/sprite.png"
  git mv "assets/characters/${char}-sprite.res" "assets/characters/${char}/sprite.res"
  # 源文件 → assets_source/characters/<name>/
  git mv "assets/characters/${char}-portrait.ase" "assets_source/characters/${char}/portrait.ase"
  git mv "assets/characters/${char}-sprite.ase" "assets_source/characters/${char}/sprite.ase"
  # 删除旧 .import 文件（新的会由 Godot 重新生成）
  rm -f "assets/characters/${char}-portrait.png.import"
  rm -f "assets/characters/${char}-sprite.png.import"
  rm -f "assets/characters/${char}-portrait.ase.import"
  rm -f "assets/characters/${char}-sprite.ase.import"
  # portrait.res 也放到 assets/（运行时用）
  if [ -f "assets/characters/${char}-portrait.res" ]; then
    git mv "assets/characters/${char}-portrait.res" "assets/characters/${char}/portrait.res"
  fi
done
```

- [ ] **Step 2: 迁移 Gorg（大写改小写）**

```bash
cd /Users/langtao/utoland
# 运行时资源
git mv "assets/characters/Gorg-portrait.png" "assets/characters/gorg/portrait.png"
git mv "assets/characters/Gorg-sprite.png" "assets/characters/gorg/sprite.png"
git mv "assets/characters/Gorg-sprite.res" "assets/characters/gorg/sprite.res"
# 源文件
git mv "assets/characters/Gorg-portrait.ase" "assets_source/characters/gorg/portrait.ase"
git mv "assets/characters/Gorg-sprite.ase" "assets_source/characters/gorg/sprite.ase"
# 删除旧 .import
rm -f "assets/characters/Gorg-portrait.png.import"
rm -f "assets/characters/Gorg-sprite.png.import"
rm -f "assets/characters/Gorg-portrait.ase.import"
rm -f "assets/characters/Gorg-sprite.ase.import"
# portrait.res
if [ -f "assets/characters/Gorg-portrait.res" ]; then
  git mv "assets/characters/Gorg-portrait.res" "assets/characters/gorg/portrait.res"
fi
```

- [ ] **Step 3: 迁移敌人精灵**

```bash
cd /Users/langtao/utoland
git mv assets/sprites/enemies/slime.png assets/enemies/slime/sprite.png
git mv assets/sprites/enemies/bluebat.png assets/enemies/bluebat/sprite.png
git mv assets/sprites/enemies/trex.png assets/enemies/trex/sprite.png
git mv assets/sprites/enemies/trex_large.png assets/enemies/trex/sprite_large.png
# 删除旧 .import
rm -f assets/sprites/enemies/*.import
```

- [ ] **Step 4: 迁移塔图集**

```bash
cd /Users/langtao/utoland
git mv assets/sprites/towers/tileset_towers.png assets/towers/tileset_towers.png
rm -f assets/sprites/towers/*.import
```

- [ ] **Step 5: 迁移弹道精灵**

```bash
cd /Users/langtao/utoland
git mv assets/sprites/projectiles/kunai.png assets/projectiles/kunai.png
git mv assets/sprites/projectiles/shuriken.png assets/projectiles/shuriken.png
git mv assets/sprites/bullet.png assets/projectiles/bullet.png
rm -f assets/sprites/projectiles/*.import
rm -f assets/sprites/bullet.png.import
```

- [ ] **Step 6: 迁移物品精灵**

```bash
cd /Users/langtao/utoland
git mv assets/sprites/items/gold_coin.png assets/items/gold_coin.png
rm -f assets/sprites/items/*.import
```

- [ ] **Step 7: 删除遗留 player 精灵和清空 sprites/**

```bash
cd /Users/langtao/utoland
# 删除无引用的遗留文件
git rm -rf assets/sprites/player/
# 删除剩余的 .gitkeep/.gdkeep 和空目录
git rm -rf assets/sprites/
```

- [ ] **Step 8: 删除 characters/ 下残留的 .import 和 .DS_Store**

```bash
cd /Users/langtao/utoland
rm -f assets/characters/.DS_Store
# 确认 characters/ 下只剩子目录
ls assets/characters/
```

- [ ] **Step 9: 提交文件迁移**

```bash
git add -A assets/ assets_source/
git commit -m "refactor: 迁移美术资源到按实体分类的目录结构"
```

---

## Task 3: 更新引用路径

**Files:**
- Modify: `scripts/core/game_config.gd` (10 处路径)
- Modify: `scenes/entities/towers/tower_*.tscn` (9 个文件)
- Modify: `scenes/entities/coin.tscn` (1 处)
- Modify: `resources/characters/*.tres` (5 个文件，每个 2 处)

- [ ] **Step 1: 更新 game_config.gd 敌人精灵路径**

在 `scripts/core/game_config.gd` 中替换：

| 旧值 | 新值 |
|------|------|
| `res://assets/sprites/enemies/slime.png` | `res://assets/enemies/slime/sprite.png` |
| `res://assets/sprites/enemies/bluebat.png` | `res://assets/enemies/bluebat/sprite.png` |
| `res://assets/sprites/enemies/trex_large.png` | `res://assets/enemies/trex/sprite_large.png` |
| `res://assets/sprites/enemies/trex.png` | `res://assets/enemies/trex/sprite.png` |

> **注意**：先替换 `trex_large.png` 再替换 `trex.png`，避免部分匹配。

- [ ] **Step 2: 更新 game_config.gd 塔/弹道/物品路径**

| 旧值 | 新值 |
|------|------|
| `res://assets/sprites/towers/tileset_towers.png` | `res://assets/towers/tileset_towers.png` |
| `res://assets/sprites/projectiles/kunai.png` | `res://assets/projectiles/kunai.png` |
| `res://assets/sprites/projectiles/shuriken.png` | `res://assets/projectiles/shuriken.png` |
| `res://assets/sprites/items/gold_coin.png` | `res://assets/items/gold_coin.png` |

- [ ] **Step 3: 更新 9 个塔场景的 tileset 路径**

在以下 `.tscn` 文件中，将 `res://assets/sprites/towers/tileset_towers.png` 替换为 `res://assets/towers/tileset_towers.png`：

- `scenes/entities/towers/tower_pea_shooter.tscn`
- `scenes/entities/towers/tower_stump.tscn`
- `scenes/entities/towers/tower_ice_flower.tscn`
- `scenes/entities/towers/tower_cactus.tscn`
- `scenes/entities/towers/tower_rose.tscn`
- `scenes/entities/towers/tower_mushroom.tscn`
- `scenes/entities/towers/tower_vine.tscn`
- `scenes/entities/towers/tower_dandelion.tscn`
- `scenes/entities/towers/tower_pitcher.tscn`

- [ ] **Step 4: 更新 coin.tscn 的金币精灵路径**

在 `scenes/entities/coin.tscn` 中将 `res://assets/sprites/items/gold_coin.png` 替换为 `res://assets/items/gold_coin.png`。

- [ ] **Step 5: 更新 5 个角色 .tres 的路径**

每个文件更新 `sprite_frames_path` 和 `portrait_path`：

| 文件 | sprite_frames_path | portrait_path |
|------|--------------------|---------------|
| `resources/characters/kaze.tres` | `res://assets/characters/kaze/sprite.res` | `res://assets/characters/kaze/portrait.png` |
| `resources/characters/nemo.tres` | `res://assets/characters/nemo/sprite.res` | `res://assets/characters/nemo/portrait.png` |
| `resources/characters/dora.tres` | `res://assets/characters/dora/sprite.res` | `res://assets/characters/dora/portrait.png` |
| `resources/characters/gorg.tres` | `res://assets/characters/gorg/sprite.res` | `res://assets/characters/gorg/portrait.png` |
| `resources/characters/merlin.tres` | `res://assets/characters/merlin/sprite.res` | `res://assets/characters/merlin/portrait.png` |

- [ ] **Step 6: 提交引用更新**

```bash
git add scripts/core/game_config.gd scenes/entities/towers/*.tscn scenes/entities/coin.tscn resources/characters/*.tres
git commit -m "refactor: 更新所有代码引用到新的资源目录路径"
```

---

## Task 4: 清理与验证

- [ ] **Step 1: 全局搜索旧路径**

```bash
cd /Users/langtao/utoland
grep -r "assets/sprites" --include="*.gd" --include="*.tscn" --include="*.tres"
```

预期：零命中。如有残留，回到 Task 3 补充修复。

- [ ] **Step 2: 搜索 Gorg 大写残留**

```bash
grep -r "Gorg" --include="*.gd" --include="*.tscn" --include="*.tres"
```

预期：仅在 display_name 等文本中出现，路径中不应出现大写 `Gorg`。

- [ ] **Step 3: 清理 Godot 导入缓存**

```bash
cd /Users/langtao/utoland
rm -rf .godot/imported/
```

然后在 Godot 编辑器中打开项目，让编辑器重新生成导入缓存和 `.import` 文件。

- [ ] **Step 4: 运行测试套件**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

预期：所有测试通过，无回归。

- [ ] **Step 5: 在编辑器中验证**

手动在 Godot 编辑器中：
1. 检查 Output 面板无资源加载错误
2. 运行游戏，验证角色精灵、敌人精灵、塔精灵、弹道精灵、金币精灵均正常显示
3. 进入商店阶段，确认塔/武器图标正常

- [ ] **Step 6: 提交清理（如有变更）**

```bash
git add -A
git commit -m "chore: 清理旧 .import 文件和缓存残留"
```

- [ ] **Step 7: 验证最终目录结构**

```bash
find assets/ -type d | sort
find assets_source/ -type d | sort
```

确认结构与设计文档一致。
