# 随机地图生成系统设计

## 概述

将现有手绘 TileMap 地图替换为运行时随机生成的地图系统。地图采用三层分区（边界墙/刷怪区/战术区），通过 Prefab 组合和对称性模板产生多样化布局，并用连通性验证保证可玩性。

## 地图分区

总地图尺寸 45×30 格不变（1440×960px），可玩区域 40×24 格（1280×768px），居中放置，外圈空余格填充装饰背景。

### 可玩区 40×24 的三层划分

```
45 × 30 总网格
┌─────────────────────────────────────────────┐
│           装饰背景区（外圈 2-3 格）            │
│  ┌───────────────────────────────────────┐  │
│  │ 边界墙（1 格）                          │  │
│  │ ┌───────────────────────────────────┐ │  │
│  │ │ 刷怪区（2 格）         S    S      │ │  │
│  │ │ ┌─────────────────────────────┐   │ │  │
│  │ │ │  战术区 3×3 九宫格           │   │ │  │
│  │ │ │  TL │ TC │ TR              │   │ │  │
│  │ │ │  ML │ 中 │ MR              │   │ │  │
│  │ │ │  BL │ BC │ BR              │   │ │  │
│  │ │ └─────────────────────────────┘   │ │  │
│  │ └───────────────────────────────────┘ │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
S = 刷怪点
```

**格子坐标（相对于可玩区左上角）：**

| 分区 | 范围 | 说明 |
|---|---|---|
| 边界墙 | x=0, x=39, y=0, y=23 | 外围 1 格，BORDER 类型 |
| 刷怪区 | x=1-2, x=37-38, y=1-2, y=21-22 | 边界墙内侧 2 格，禁止造塔和生成 Prefab |
| 战术区 | x=3~36, y=3~20 | 中心 34×18 格，九宫格划分 |

**九宫格每块约 11×6 格**（34/3 ≈ 11, 18/3 = 6），中心区保持空地。

## 数据模型

### MapLayout（RefCounted）

生成结果的数据载体，传递给其他系统使用。

```
scripts/resources/map_layout.gd

属性：
- grid: Array[Array]           # 40×24 二维数组，每格存 CellType 枚举
- spawn_points: Array[Vector2i] # 刷怪点格子坐标
- placeable_cells: Array[Vector2i] # 可放塔的格子
- player_spawn: Vector2i       # 玩家初始位置（中心区中点）

枚举 CellType：
- GROUND      # 地面，可通行可放塔
- BORDER      # 边界墙，不可通行
- WALL        # 实体墙（Prefab），阻挡移动和投射物
- ABYSS       # 深渊水域（Prefab），阻挡移动但投射物可飞过
- SPAWN_ZONE  # 刷怪区地面，可通行但禁止放塔

方法：
- get_spawn_points_world() -> Array[Vector2]  # 转换为世界像素坐标
- get_player_spawn_world() -> Vector2
- get_placeable_dict() -> Dictionary           # {Vector2i: true} 快速查询
- is_passable(pos: Vector2i) -> bool           # GROUND/SPAWN_ZONE 为可通行
```

### MapPrefab（Resource）

描述一种地形预制件的形状和属性。

```
scripts/resources/map_prefab.gd

属性：
- id: String                   # 如 "wall_l", "abyss_river"
- cell_type: CellType          # WALL 或 ABYSS
- cells: Array[Vector2i]       # 相对坐标列表（锚点为原点）
- rotatable: bool              # 是否可 90° 步进旋转
- tile_atlas_coords: Vector2i  # TileSet 中对应的 atlas 坐标
```

### 初始 Prefab 集合（6 种）

| ID | 类型 | 形状 | 尺寸 | 可旋转 |
|---|---|---|---|---|
| wall_l | WALL | L 型 | 3×3（5格） | 是 |
| wall_cross | WALL | 十字型 | 3×3（5格） | 否 |
| wall_line | WALL | 直线 | 1×4（4格） | 是 |
| abyss_river | ABYSS | 长条 | 1×6（6格） | 是 |
| abyss_island | ABYSS | 不规则块 | 3×3（约6格） | 是 |
| abyss_pool | ABYSS | 方块 | 2×2（4格） | 否 |

Prefab 数据文件存储在 `resources/maps/prefabs/`。

### 旋转与对称变换

**旋转（90° 步进）：**
- 0°: (x, y) → (x, y)
- 90°: (x, y) → (-y, x)
- 180°: (x, y) → (-x, -y)
- 270°: (x, y) → (y, -x)

**对称变换：**
- 左右镜像：(x, y) → (-x, y)，旋转角度取反
- 180° 中心对称：坐标和旋转都加 180°

## 对称性模板

三种宏观对称模式，随机选择：

### RANDOM（纯随机）

8 个区块各自独立决定放什么。最大随机性。

### MIRROR_X（左右镜像）

对称组：TL↔TR, ML↔MR, BL↔BR。TC、BC 独立。
只需决策 5 个区块，右侧水平翻转左侧的 Prefab 配置。

### ROTATE_180（中心对称）

对称组：TL↔BR, TC↔BC, TR↔BL, ML↔MR。
只需决策 4 个区块，对角做 180° 旋转。

## 生成算法

### MapGenerator（RefCounted）

```
scripts/systems/map_generator.gd

方法：
- generate(config: MapGeneratorConfig, seed: int = -1) -> MapLayout
- apply_to_tilemap(map_scene: Node, layout: MapLayout) -> void
```

### 生成流程

```
1. 初始化网格
   └─ 40×24 全部填 GROUND

2. 铺边界墙
   └─ 外围 1 格设为 BORDER

3. 标记刷怪区
   └─ 边界墙内侧 2 格标记为 SPAWN_ZONE

4. 生成刷怪点
   ├─ 四条边各随机 1-2 个点（在刷怪区范围内）
   ├─ 四角各 0-1 个点（50% 概率）
   └─ 总计 4-12 个刷怪点

5. 选择对称模板
   └─ 随机：RANDOM / MIRROR_X / ROTATE_180

6. 填充战术区九宫格
   ├─ 跳过中心区（保持空地）
   ├─ 根据对称模板确定独立决策的区块
   │   ├─ RANDOM: 8 个区块各自独立
   │   ├─ MIRROR_X: 决策 TL/ML/BL/TC/BC（5个）
   │   └─ ROTATE_180: 决策 TL/TC/TR/ML（4个）
   ├─ 每个区块：
   │   ├─ 30-40% 概率留空
   │   ├─ 否则随机 1-2 个 Prefab
   │   ├─ 随机旋转（0/90/180/270，若 rotatable）
   │   ├─ 区块内随机偏移位置
   │   └─ 检查不越界、不重叠
   └─ 对称区块应用对应变换

7. 连通性验证（防抱死）
   ├─ 从玩家初始位置做 flood fill
   ├─ 检查所有刷怪点是否可达（GROUND 和 SPAWN_ZONE 可通行）
   ├─ 失败 → 回到步骤 5 重试（最多 10 次）
   └─ 10 次失败 → 减少 Prefab 数量再试

8. 计算 placeable_cells
   └─ 战术区内所有 GROUND 格子 → placeable_cells
```

## 碰撞层改动

### 新增碰撞层

| 层 | 名称 | 用途 |
|---|---|---|
| 9 | WallBlock | 实体墙专用，阻挡投射物 |

### 碰撞配置

- 实体墙 tile：collision_layer = Solid(3) + WallBlock(9)
- 深渊水域 tile：collision_layer = Solid(3)
- 投射物：collision_mask 新增 WallBlock(9)，碰到实体墙时销毁
- 现有塔（仅 Solid 层）不受影响，投射物仍飞过塔

## 系统集成

### main.gd 改造

```gdscript
func _load_map():
    # 1. 加载地图模板场景
    var map_scene = load("res://scenes/levels/maps/generated_map.tscn").instantiate()
    add_child(map_scene)

    # 2. 生成地图布局
    var generator = MapGenerator.new()
    var layout = generator.generate(map_config)

    # 3. 填充 TileMap
    generator.apply_to_tilemap(map_scene, layout)

    # 4. 传递生成数据给其他系统
    enemy_spawner.spawn_points = layout.get_spawn_points_world()
    drag_manager.placeable_cells = layout.get_placeable_dict()
    player.position = layout.get_player_spawn_world()

    # 5. 提取容器引用（不变）
    _setup_layers(map_scene)
```

### EnemySpawner 改造

- 移除 `get_random_spawn_position()` 中的边缘随机逻辑
- 新增 `spawn_points: Array[Vector2]`，由 main.gd 从 MapLayout 传入
- 生成敌人时从 spawn_points 随机选一个，加小量随机偏移

### DragManager 改造

- 新增 `placeable_cells: Dictionary`（格子坐标 → bool）
- 由 main.gd 从 MapLayout 传入
- 放塔时校验目标格子是否在 placeable_cells 中

### MapBoundary 移除

边界墙由 tile 碰撞替代，移除 `map_boundary.gd` 和 `map_boundary.tscn`。

## 文件结构

```
新增：
  scripts/systems/map_generator.gd         — MapGenerator（RefCounted）
  scripts/resources/map_layout.gd          — MapLayout 数据类
  scripts/resources/map_prefab.gd          — MapPrefab（Resource）
  resources/maps/prefabs/*.tres            — 6 个 Prefab 数据文件
  scenes/levels/maps/generated_map.tscn    — 通用地图模板（空 TileMapLayer + 容器）
  tests/unit/test_map_generator.gd         — 生成器单元测试

修改：
  scripts/ui/main.gd                       — 集成 MapGenerator
  scripts/systems/enemy_spawner.gd         — 改用固定刷怪点
  scripts/systems/drag_manager.gd          — 加可放置性校验
  scripts/entities/projectiles/projectile.gd — 碰撞 mask 加 WallBlock
  scripts/core/game_config.gd              — 加载 Prefab、更新可玩区常量
  project.godot                            — 新增第 9 碰撞层

移除：
  scripts/shared/map_boundary.gd
  scenes/shared/map_boundary.tscn
```

## 种子系统

`MapGenerator.generate(config, seed)` 接受可选种子参数。相同种子产生相同地图，用于调试和测试的可复现性。seed = -1 时使用随机种子。

## 测试策略

`test_map_generator.gd` 覆盖：

- 网格尺寸正确（40×24）
- 边界墙全覆盖外围 1 格
- 中心区无障碍物
- 刷怪点数量在 4-12 范围内且都在刷怪区
- 连通性：所有刷怪点可达中心玩家位置
- 对称模板正确性（镜像/旋转后 Prefab 位置对称）
- placeable_cells 不包含墙/深渊/刷怪区/边界格子
- 种子可复现性（相同种子 → 相同结果）
