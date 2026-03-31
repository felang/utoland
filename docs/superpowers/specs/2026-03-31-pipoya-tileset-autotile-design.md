# Pipoya Tileset Autotile 设计

## 概述

将随机地图生成的渲染层从当前的 luminara 单 tile 模式，替换为 Pipoya RPG Tileset 32x32 (type3) 的 47-tile blob autotile 系统。实现地形边缘的自动平滑过渡。

## 目标

- 地图边界 (BORDER)、障碍墙 (WALL)、水域 (ABYSS) 三种地形实现 autotile 自动过渡
- 草地 (GROUND/SPAWN_ZONE) 满铺纯色，不做 autotile
- 不改动地图生成逻辑（MapLayout、MapPrefab、generate()、连通性验证）
- 不改动碰撞配置逻辑

## 素材选用

统一使用 Pipoya RPG Tileset 32x32 的 **type3** 变体（`assets/tilesets/Pipoya RPG Tileset 32x32/[A]_type3/`）。

Type3 为 8x6 网格（256x192 px），48 个 tile 中包含 **47 种唯一 blob 配置**（1 个重复），覆盖所有邻居组合的边角过渡。

| CellType | 素材文件 | 视觉效果 |
|---|---|---|
| GROUND / SPAWN_ZONE | `[A]Grass1_pipo.png` | 满铺中心纯色 tile |
| BORDER | `[A]Dirt1_pipo.png` | 泥土地势，autotile 过渡 |
| WALL | `[A]Wall-Up1_pipo.png` | 墙壁障碍，autotile 过渡 |
| ABYSS | `[A]Water1_pipo.png` | 水域，autotile 过渡 |

### 与现有 `pipoya_tileset.tres` 的关系

已有的 `resources/maps/tilesets/pipoya_tileset.tres` 是之前尝试用 Godot Terrain API 配置的版本（引用 `assets/tilesets/pipoya/` 下的复制文件，含 peering bits 配置）。本方案**不复用该文件**，新建 `pipoya_generated_tileset.tres` 直接引用 type3 原始素材，不配置 terrain peering bits。旧文件保留不删除，但不被引用。

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

### CellType 判定规则

**"同类型" 判定**（用于 bitmask 计算）：
- 对于 BORDER cell，邻居是 BORDER 则为同类型
- 对于 WALL cell，邻居是 WALL 则为同类型
- 对于 ABYSS cell，邻居是 ABYSS 则为同类型
- GROUND 和 SPAWN_ZONE 都视为"非障碍"，对 bitmask 计算而言等同处理

**边界外邻居判定**：
- `MapLayout.get_cell()` 对超出可玩区的坐标返回 `BORDER`
- 这对 BORDER cell 的 bitmask 计算是正确的（边界外 = 同类型 BORDER）
- WALL 和 ABYSS 由于 `_is_valid_prefab_pos()` 的 2 格缓冲约束，永远不会出现在可玩区边缘，因此不需要特殊处理边界外邻居

**渲染分类**（用于 `apply_to_tilemap()`）：
- GROUND、SPAWN_ZONE → Ground layer 铺 Grass1 草地
- BORDER、WALL、ABYSS → Ground layer 铺 Grass1 + Terrain layer 叠加对应 autotile

### 查找表

47 条 bitmask → Vector2i(col, row) 映射，对应 type3 图的 8x6 网格坐标。三种地形共用同一套映射逻辑，仅 atlas source id 不同。

锚点示例（实现时需对照实际 Pipoya type3 图片逐一校验全部 47 条）：

| bitmask | 含义 | type3 坐标 (col, row) |
|---|---|---|
| 0 | 孤立块（无邻居） | (0, 0) |
| 255 | 满填充（8 邻居全同类型） | (7, 0) |
| 4 | 仅右邻居 | (1, 0) |
| 64 | 仅左邻居 | (3, 0) |
| 1 | 仅上邻居 | (0, 3) |
| 16 | 仅下邻居 | (0, 1) |

## 架构

### 新增文件

#### `scripts/systems/terrain_autotiler.gd`

autotile 辅助类（class_name TerrainAutotiler, extends RefCounted）。

职责：给定 MapLayout 和 cell 坐标，返回正确的 atlas 坐标。

```
const BITMASK_TO_ATLAS: Dictionary  # {int: Vector2i}，47 条映射

static func get_atlas_coord(layout: MapLayout, pos: Vector2i, cell_type: int) -> Vector2i
  # 计算 bitmask，查表返回 atlas 坐标
  # 未命中查找表时 fallback 到孤立块 (0, 0)

static func _compute_bitmask(layout: MapLayout, pos: Vector2i, cell_type: int) -> int
  # 检查 8 邻居 + corner masking
  # 使用 MapLayout.get_cell() 获取邻居类型（边界外自动返回 BORDER）
```

#### `resources/maps/tilesets/pipoya_generated_tileset.tres`

新 TileSet 资源，4 个 TileSetAtlasSource：

| Source ID | 图片 | 用途 |
|---|---|---|
| 0 | `[A]Grass1_pipo.png` | Ground 满铺 |
| 1 | `[A]Dirt1_pipo.png` | Border autotile |
| 2 | `[A]Wall-Up1_pipo.png` | Wall autotile |
| 3 | `[A]Water1_pipo.png` | Abyss autotile |

每个 source：tile_size = 32x32，atlas 尺寸 = 8 列 x 6 行。

Grass1 中心满铺 tile 坐标：`Vector2i(5, 1)`（type3 网格中完全被地形覆盖的中心 tile，需对照实际图片确认）。

### 改动文件

#### `scripts/systems/map_generator.gd`

`apply_to_tilemap()` 方法改造：

```
Ground layer:
  满铺 Grass1 中心 tile (source=0, atlas=Vector2i(5, 1))
  覆盖所有 cell（GROUND、SPAWN_ZONE、BORDER、WALL、ABYSS 都铺草地底层）

Terrain layer:
  BORDER → source=1, atlas=TerrainAutotiler.get_atlas_coord(layout, pos, BORDER)
  WALL   → source=2, atlas=TerrainAutotiler.get_atlas_coord(layout, pos, WALL)
  ABYSS  → source=3, atlas=TerrainAutotiler.get_atlas_coord(layout, pos, ABYSS)
  GROUND/SPAWN_ZONE → 不设置 Terrain layer tile
```

#### `scenes/levels/maps/generated_map.tscn`

TileSet 引用从 `luminara_terrace_tileset.tres` 改为 `pipoya_generated_tileset.tres`。

### Background 层和可玩区外区域

当前 `apply_to_tilemap()` 仅填充 40x24 可玩区内的 tile。可玩区外（45x30 地图的外圈 3 格）不填充，与当前行为一致。如需填充可作为后续优化。

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

碰撞形状：每个 source 的**所有 47 个 tile** 统一配置 32x32 全覆盖矩形。碰撞粒度是 cell 级别，所有非 Ground 的 cell 都完全阻挡，不需要跟随 tile 视觉形状。

## 测试策略

- 单元测试 `TerrainAutotiler._compute_bitmask()`：验证各种邻居组合返回正确的 bitmask 值
- 单元测试 corner masking：验证角落位在边不满足时被正确清零
- 单元测试 `get_atlas_coord()`：验证 bitmask 查表返回正确坐标，未命中时 fallback
- 单元测试 SPAWN_ZONE 处理：验证 SPAWN_ZONE 在渲染和 bitmask 计算中与 GROUND 等同
- 集成验证：在 Godot 中运行查看渲染效果，确认过渡自然
