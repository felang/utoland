# Pipoya Tileset Autotile 设计

## 概述

将随机地图生成的渲染层从当前的 luminara 单 tile 模式，替换为 Pipoya RPG Tileset 32x32 (type3) 的 47-tile blob autotile 系统。实现地形边缘的自动平滑过渡。

## 目标

- 地图边界 (BORDER)、障碍墙 (WALL)、水域 (ABYSS) 三种地形实现 autotile 自动过渡
- 草地 (GROUND) 满铺纯色，不做 autotile
- 不改动地图生成逻辑（MapLayout、MapPrefab、generate()、连通性验证）
- 不改动碰撞配置逻辑

## 素材选用

统一使用 Pipoya RPG Tileset 32x32 的 **type3** 变体（`assets/tilesets/Pipoya RPG Tileset 32x32/[A]_type3/`）。

Type3 为 8x6 网格（256x192 px），包含 47 种唯一 blob tile，覆盖所有邻居组合的边角过渡。

| CellType | 素材文件 | 视觉效果 |
|---|---|---|
| GROUND | `[A]Grass1_pipo.png` | 满铺中心纯色 tile |
| BORDER | `[A]Dirt1_pipo.png` | 泥土地势，autotile 过渡 |
| WALL | `[A]Wall-Up1_pipo.png` | 墙壁障碍，autotile 过渡 |
| ABYSS | `[A]Water1_pipo.png` | 水域，autotile 过渡 |

## 技术方案：Bitmask 查找表

不使用 Godot TileSet Terrain API（之前尝试 peering bits 映射有问题），改为在 `apply_to_tilemap()` 中手动计算邻居 bitmask，通过查找表映射到 type3 图的 atlas 坐标。

### Bitmask 位定义

8 个方向各占 1 bit：

```
NW=128  N=1   NE=2
W=64    SELF  E=4
SW=32   S=16  SE=8
```

### Corner Masking 规则

角落位仅在两个相邻边都是同类型时才保留，否则清零：

- NE 生效条件：N 和 E 都是同类型
- SE 生效条件：S 和 E 都是同类型
- SW 生效条件：S 和 W 都是同类型
- NW 生效条件：N 和 W 都是同类型

masking 后从 256 种组合降到 47 种唯一值。

### "同类型" 判定

- 对于 BORDER cell，邻居是 BORDER 则为同类型
- 对于 WALL cell，邻居是 WALL 则为同类型
- 对于 ABYSS cell，邻居是 ABYSS 则为同类型
- **边界外**（超出可玩区）的邻居视为同类型，避免地图边缘出现不自然的过渡 tile

### 查找表

47 条 bitmask → Vector2i(col, row) 映射，对应 type3 图的 8x6 网格坐标。三种地形共用同一套映射逻辑，仅 atlas source id 不同。

具体映射值需在实现时对照实际 Pipoya type3 图片逐一校验（标准 RPG Maker A2 排布有多种变体）。

## 架构

### 新增文件

#### `scripts/systems/terrain_autotiler.gd`

autotile 辅助类（class_name TerrainAutotiler, extends RefCounted）。

职责：给定 MapLayout 和 cell 坐标，返回正确的 atlas 坐标。

```
const BITMASK_TO_ATLAS: Dictionary  # {int: Vector2i}，47 条映射

static func get_atlas_coord(layout: MapLayout, pos: Vector2i, cell_type: int) -> Vector2i
  # 计算 bitmask，查表返回 atlas 坐标

static func _compute_bitmask(layout: MapLayout, pos: Vector2i, cell_type: int) -> int
  # 检查 8 邻居 + corner masking
```

#### `resources/maps/tilesets/pipoya_generated_tileset.tres`

新 TileSet 资源，4 个 TileSetAtlasSource：

| Source ID | 图片 | 用途 |
|---|---|---|
| 0 | Grass1_pipo.png | Ground 满铺 |
| 1 | Dirt1_pipo.png | Border autotile |
| 2 | Wall-Up1_pipo.png | Wall autotile |
| 3 | Water1_pipo.png | Abyss autotile |

每个 source：tile_size = 32x32，atlas 尺寸 = 8 列 x 6 行。

### 改动文件

#### `scripts/systems/map_generator.gd`

`apply_to_tilemap()` 方法改造：

```
Ground layer:
  满铺 Grass1 中心 tile (source=0, atlas=固定坐标)

Terrain layer:
  BORDER → source=1, atlas=TerrainAutotiler.get_atlas_coord(layout, pos, BORDER)
  WALL   → source=2, atlas=TerrainAutotiler.get_atlas_coord(layout, pos, WALL)
  ABYSS  → source=3, atlas=TerrainAutotiler.get_atlas_coord(layout, pos, ABYSS)
```

#### `scenes/levels/maps/generated_map.tscn`

TileSet 引用从 `luminara_terrace_tileset.tres` 改为 `pipoya_generated_tileset.tres`。

### 不改动

- MapLayout、MapPrefab、MapGeneratorConfig — 地图数据结构不变
- generate()、_scatter_prefabs()、_validate_edge_connectivity() — 生成逻辑不变
- main.gd — 调用接口不变
- 碰撞检测逻辑 — 不变

## TileSet 碰撞配置

| Source | 地形 | 碰撞层 | 说明 |
|---|---|---|---|
| 0 (Grass1) | Ground | 无碰撞 | 纯视觉底层 |
| 1 (Dirt1) | Border | Layer 3 (Solid) | 阻挡移动 |
| 2 (Wall-Up1) | Wall | Layer 3 (Solid) + Layer 9 (WallBlock) | 阻挡移动 + 阻挡投射物 |
| 3 (Water1) | Abyss | Layer 3 (Solid) | 阻挡移动，投射物可飞过 |

碰撞形状：每个 tile 统一 32x32 全覆盖矩形。碰撞粒度是 cell 级别，不需要跟随 tile 视觉形状。

## 测试策略

- 单元测试 `TerrainAutotiler`：验证各种邻居组合返回正确的 atlas 坐标
- 单元测试 corner masking：验证角落位在边不满足时被正确清零
- 单元测试边界外判定：验证超出可玩区的邻居视为同类型
- 集成验证：在 Godot 中运行查看渲染效果，确认过渡自然
