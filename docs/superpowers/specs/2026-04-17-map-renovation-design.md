# #4 地图改造设计

## 概述

将现有随机 Prefab 散布地图系统替换为**固定骨架 + 内部细节随机**的区域化地图生成。测试地图包含 4 个有策略意图的区域（中央废墟、东北狭道、西侧开阔地、南部碎石区）和 4 个方向刷新点，刷新点按波次渐进激活。

视觉暂用纯色方块，后续再接 tileset 美术。

## 决策记录

| 决策 | 结论 |
|------|------|
| 生成方式 | 固定骨架 + 内部细节随机 |
| 与现有代码关系 | 全部重写（删除旧 MapGenerator/MapLayout/TerrainAutotiler/Prefab 系统） |
| 刷新点激活 | 自动规则(2→3→4) + WaveData 可选覆盖 |
| 视觉 | 简单纯色方块，后续再接美术 |
| 区域布局 | 按设计文档方位 |
| 地形阻挡 | 统一只挡移动，不挡投射物 |

## 1. 网格与地形类型

- **网格**：40×24 格（1280×768 像素），边界外 1 格 OBSTACLE 围墙
- **CellType 枚举**：
  - `GROUND = 0` — 可通行（玩家、敌人、塔均可）
  - `OBSTACLE = 1` — 阻挡移动（不挡投射物）
- **碰撞**：OBSTACLE 格子生成 StaticBody2D + RectangleShape2D(32×32)，碰撞层 3（Solid）
- **塔放置**：只能放在 GROUND 格子上，MapLayout 提供 `is_placeable(grid_pos) -> bool`

## 2. 区域骨架布局

4 个区域在 40×24 网格上的布局（坐标为 grid 左上角 x,y，原点 0,0 在可玩区左上角）：

```
     0    5   10   15   20   25   30   35  39
  0  +-------------------------------------+
     |            N刷新点(20,0)             |
  3  |          +----------+               |
     |          | 东北狭道  |               |
  6  |          | (12,2)   |               |
     |          | 8x6      |               |
  8  |          +----------+               |
     |                                     |
 10  |  W刷新点  +----------+    E刷新点    |
     |  (0,12)  | 中央废墟  |    (39,12)   |
 12  |          | (15,9)   |               |
     |          | 10x6     |               |
 15  |          +----------+               |
     |                                     |
 17  |        +----------------+           |
     |        |  南部碎石区     |           |
 19  |        |  (10,17)      |           |
     |        |  20x6         |           |
 23  |        +----------------+           |
     |            S刷新点(20,23)            |
 24  +-------------------------------------+
```

### 各区域定义

| 区域 | 左上角 | 尺寸 | 骨架特征 | 随机填充 |
|------|--------|------|---------|---------|
| 中央废墟 | (15,9) | 10×6 | 外圈矮墙，南口+东口各留 2 格开口 | 内部随机 1-2 个小障碍块 |
| 东北狭道 | (12,2) | 8×6 | 上下两排长墙形成 2 格宽通道 | 通道两侧小空地随机 0-1 个障碍 |
| 西侧开阔地 | 左半区域 | — | 无骨架，大片空地 | 不放障碍 |
| 南部碎石区 | (10,17) | 20×6 | 无固定墙体 | 随机散布 8-15 个 1×1 小碎石 |

### 刷新点（网格坐标，紧贴边界）

- N: (20, 0)
- S: (20, 23)
- E: (39, 12)
- W: (0, 12)

### 玩家出生点

中央废墟中心 (19, 12)

## 3. Resource 定义

### ZoneData（`scripts/resources/zone_data.gd`）

```gdscript
class_name ZoneData
extends Resource

@export var id: String                    # "central_ruins", "ne_corridor", "south_rubble"
@export var origin: Vector2i              # 区域左上角网格坐标
@export var size: Vector2i                # 区域尺寸（格）
@export var fixed_walls: Array[Vector2i]  # 骨架固定障碍（相对于 origin 的偏移）
@export var fill_count: Vector2i          # 随机填充障碍数量范围 (min, max)
@export var fill_margin: int = 1          # 填充时距固定墙的最小间距
```

- `fixed_walls` 是手工坐标列表（相对偏移），描述骨架墙体形状
- `fill_count` 控制每局随机变化幅度：中央废墟 (1,2)，东北狭道 (0,1)，南部碎石 (8,15)
- 西侧开阔地不需要 ZoneData

### MapBlueprint（`scripts/resources/map_blueprint.gd`）

```gdscript
class_name MapBlueprint
extends Resource

@export var id: String                      # "test_map"
@export var grid_width: int = 40
@export var grid_height: int = 24
@export var zones: Array[ZoneData]          # 3 个区域
@export var spawn_points: Dictionary        # {"north": Vector2i, "south": ..., "east": ..., "west": ...}
@export var player_spawn: Vector2i          # (19, 12)
```

### MapData 改造

```gdscript
# 删除
@export var generator_config: MapGeneratorConfig

# 新增
@export var blueprint: MapBlueprint  # 有值=程序化生成，null=走 map_scene 手绘
```

## 4. MapGenerator 生成流程

**类**：RefCounted，`scripts/systems/map_generator.gd`（全新重写）

```
func generate(blueprint: MapBlueprint) -> MapLayout
```

**步骤**：

1. **初始化网格**：grid_width × grid_height 全部填 GROUND
2. **画边界**：四周 1 格设为 OBSTACLE
3. **画骨架**：遍历 `blueprint.zones`，将每个 ZoneData 的 `fixed_walls`（加 origin 偏移）写入网格
4. **随机填充**：遍历每个 zone，在区域内随机放置 `fill_count` 范围内的 OBSTACLE
   - 不能堵住 zone 的开口
   - 距 `fixed_walls` 至少 `fill_margin` 格
   - 不能放在玩家出生点周围 3×3 范围
5. **连通性验证**：从 `player_spawn` BFS，确认能到达全部 4 个 `spawn_points`。不通时移除最后放置的随机障碍重试（最多 3 次），全部失败退化为只保留骨架
6. **输出 MapLayout**

### MapLayout（`scripts/core/map_layout.gd`，全新重写）

```gdscript
class_name MapLayout
extends RefCounted

enum CellType { GROUND, OBSTACLE }

var grid: Array                   # 二维数组，值为 CellType
var spawn_points: Dictionary      # {"north": Vector2i, ...}
var player_spawn: Vector2i
var grid_width: int
var grid_height: int

func is_ground(pos: Vector2i) -> bool
func is_placeable(pos: Vector2i) -> bool  # GROUND 且不在刷新点/出生点上
func grid_to_world(pos: Vector2i) -> Vector2
func world_to_grid(pos: Vector2) -> Vector2i
```

**坐标系约定**：地图中心为世界原点 (0,0)。grid(0,0) 是可玩区左上角，对应世界坐标 `(-grid_width/2 * 32 + 16, -grid_height/2 * 32 + 16)` = `(-624, -368)`。`grid_to_world(x,y)` = `((x - grid_width/2) * 32 + 16, (y - grid_height/2) * 32 + 16)`。

## 5. MapRenderer 渲染

**类**：RefCounted，`scripts/systems/map_renderer.gd`（全新）

```
func render(layout: MapLayout, tilemap: TileMapLayer) -> void
func create_colliders(layout: MapLayout, parent: Node2D) -> void
```

### 视觉

用极简 TileSet（2 个纯色 tile）：
- GROUND：绿色 `#4a7c3f`
- OBSTACLE：深灰 `#555555`

刷新点位置用 Sprite2D 红色标记叠在 GROUND 上（调试用）。

### 碰撞生成

`create_colliders()` 遍历 OBSTACLE 格子，合并相邻格子为大矩形，生成少量 StaticBody2D + RectangleShape2D，碰撞层 = 3（Solid），添加到 `Colliders` 节点。

### 场景结构

地图场景（`generated_map.tscn`，重建）：

```
MapRoot (Node2D)
├── Ground (TileMapLayer)         — MapRenderer 画方块
├── SpawnMarkers (Node2D)         — 4 个刷新点标记
├── Colliders (Node2D)            — 生成的 StaticBody2D
├── PickupLayer (Node2D, z=0)
├── EntityLayer (Node2D, z=1, y_sort)
└── ProjectileLayer (Node2D, z=2)
```

## 6. 刷新点激活与 EnemySpawner 集成

### 激活规则（默认自动）

| 波次 | 激活数量 | 选择逻辑 |
|------|---------|---------|
| 1-5 | 2 个 | 随机选 2 个方向 |
| 6-12 | 3 个 | 随机选 3 个方向 |
| 13-20 | 4 个 | 全部激活 |

### WaveData 新增字段

```gdscript
@export var active_spawn_directions: Array[String] = []  # 空=走自动规则，非空=覆盖
```

### EnemySpawner 改造

- 删除 `_legacy_random_position()` 和 `map_min/max_x/y` 字段
- 新增 `all_spawn_points: Dictionary`（从 MapLayout 注入，key=方向名，value=世界坐标）
- 新增 `active_directions: Array[String]`（每波开始时由 WaveManager 设置）
- `get_random_spawn_position()`：从 `active_directions` 随机选方向，取世界坐标 + ±16px 随机偏移

### WaveManager 改造

- `start_next_wave()` 时计算默认激活方向，检查 WaveData 覆盖
- 将激活方向传给 EnemySpawner

### main.gd 集成

`_load_map()` 生成 MapLayout 后，将 `layout.spawn_points`（世界坐标转换后）传给 EnemySpawner 的 `all_spawn_points`。

## 7. 删除清单

| 文件 | 说明 |
|------|------|
| `scripts/systems/map_generator.gd` | 旧生成器 |
| `scripts/core/map_layout.gd` | 旧数据结构 |
| `scripts/systems/terrain_autotiler.gd` | Pipoya autotile |
| `resources/maps/default_generator_config.tres` | 旧生成配置 |
| `resources/maps/prefabs/*.tres` | 8 个 Prefab |
| `scripts/resources/map_generator_config.gd` | 旧配置 Resource 类 |
| `scripts/resources/map_prefab.gd` | 旧 Prefab Resource 类 |
| `resources/maps/tilesets/pipoya_*.tres` | Pipoya tileset |
| `scenes/levels/maps/generated_map.tscn` | 旧生成地图场景 |

**保留**：`forest.tscn` + `luminara_*.tres`（手绘地图备用）

## 8. 测试计划

- **MapLayout 单元测试**：`is_ground`/`is_placeable`/坐标转换
- **MapGenerator 单元测试**：骨架正确性、填充数量范围、连通性验证、边界保护
- **刷新点激活测试**：自动规则正确性、WaveData 覆盖
- **EnemySpawner 测试**：从指定刷新点生成、偏移范围
- **集成测试**：完整流程（generate → render → spawn enemies）
