# 宏观模板 + Terrain Autotile 地图生成重构

## 概述

替换当前九宫格+对称模板的随机地图生成方式，改为"宏观模板定义地形骨架 + Prefab 随机填充细节 + Terrain Autotile 自动渲染过渡"。目标是产生有意义的地形结构（走廊、隘口、分区），增强战术选择，并通过自动地形过渡提升视觉效果。

## 模板系统

### 数据结构

**MapTemplate（Resource）：**
```
scripts/resources/map_template.gd

- id: String                          # 如 "central_river", "cross_corridor"
- display_name: String                # 中文显示名
- features: Array[TerrainFeature]     # 1-3 个主干地形元素
```

**TerrainFeature（Resource）：**
```
scripts/resources/terrain_feature.gd

- type: enum { RIVER, WALL_BAND, CORRIDOR, PLAZA }
- shape: enum { LINE, ARC, RECT }
- start: Vector2       # 起点（归一化 0~1，相对战术区 34×18）
- end: Vector2         # 终点（LINE/ARC 用）
- width: int           # 宽度（格数，1-3）
- gaps: Array[float]   # 缺口位置（沿路径的归一化比例 0~1）
- gap_width: int       # 缺口宽度（格数，2-3）
- size: Vector2i       # RECT/PLAZA 用，宽高（格数）
- center: Vector2      # RECT/PLAZA 用，中心点（归一化）
```

**type 说明：**
- `RIVER`：水域带（ABYSS），阻挡移动但投射物可飞过
- `WALL_BAND`：墙带（WALL），完全阻挡移动和投射物
- `CORRIDOR`：走廊，两侧是 WALL，中间是 GROUND（宽度指走廊通道宽度，两侧墙各 1 格）
- `PLAZA`：开阔广场，矩形区域标记为 GROUND 且禁止 Prefab 填充

**shape 说明：**
- `LINE`：从 start 到 end 的直线
- `ARC`：从 start 到 end 的弧线（围绕地图中心弯曲）
- `RECT`：矩形区域（用 center + size）

### 归一化坐标

模板中的坐标使用归一化值 (0~1)，相对于战术区（34×18 格）：
```
实际格子 x = TACTICAL_MIN_X + normalized_x * (TACTICAL_MAX_X - TACTICAL_MIN_X)
实际格子 y = TACTICAL_MIN_Y + normalized_y * (TACTICAL_MAX_Y - TACTICAL_MIN_Y)
```
这样模板不依赖具体的战术区尺寸。

### 初始 8 种模板

| ID | 名称 | 主干元素 | 战术效果 |
|---|---|---|---|
| central_river | 中央横河 | 水平 RIVER 穿过中部(y=0.5)，2 缺口 | 上下分区，隘口防守 |
| vertical_canyon | 纵向峡谷 | 垂直 WALL_BAND + 中间 CORRIDOR | 东西分区，走廊射击通道 |
| cross_corridor | 十字走廊 | 十字形 CORRIDOR（水平+垂直交叉） | 四象限独立，交叉点核心 |
| ring_moat | 环形水道 | 围绕中心的矩形 RIVER（4 缺口） | 中心被水包围，桥是隘口 |
| diagonal_rift | 对角裂谷 | 对角线 WALL_BAND，2 缺口 | 斜向分区，不对称防守 |
| twin_rivers | 双河并行 | 两条平行水平 RIVER(y=0.33,0.67)，各 2 缺口 | 三横带，分层到达 |
| central_fortress | 中央堡垒 | 中心区周围矩形 WALL_BAND，4 入口 | 堡垒防守，入口放塔 |
| open_plazas | 广场散布 | 2-3 个 PLAZA + 密集 Prefab | 引导聚集，广场边缘放塔 |

## 生成流程

替换当前的对称模板+九宫格填充逻辑：

```
1. 初始化网格 40×24 全 GROUND（不变）

2. 铺边界墙 BORDER（不变）

3. 标记刷怪区 SPAWN_ZONE（不变）

4. 生成刷怪点（不变）

5. 随机选模板
   └─ 从 config.templates 中随机选一个 MapTemplate

6. 渲染模板主干地形
   ├─ 遍历 template.features
   ├─ 根据 type+shape 计算实际格子坐标
   ├─ RIVER → 设为 ABYSS，缺口位置保持 GROUND
   ├─ WALL_BAND → 设为 WALL，缺口位置保持 GROUND
   ├─ CORRIDOR → 两侧设为 WALL，中间保持 GROUND
   └─ PLAZA → 标记为禁止 Prefab 区域（仍为 GROUND）

7. Prefab 随机散布（替换九宫格逻辑）
   ├─ 确定可放置区域（战术区内 GROUND 且非中心安全区、非 PLAZA）
   ├─ 根据 config 确定总 Prefab 数量（如 8-15 个）
   ├─ 逐个随机选 Prefab、随机旋转
   ├─ 在可放置区域中随机找位置放下
   └─ 检查不重叠、不越界

8. 连通性验证（不变）
   ├─ flood fill 从玩家位置检查所有刷怪点可达
   ├─ 失败 → 重新执行步骤 7（保留模板主干）
   ├─ 多次失败 → 减少 Prefab 数量重试
   └─ 仍失败 → 换模板重试

9. 计算 placeable_cells（不变）
```

### 与当前实现的主要差异

| 方面 | 当前 | 新方案 |
|---|---|---|
| 宏观结构 | 对称模板（RANDOM/MIRROR_X/ROTATE_180） | 预设模板骨架（8 种） |
| 障碍填充 | 九宫格分块，每块 1-3 个 Prefab | 战术区全域随机散布 |
| 地形类型 | 小型独立 Prefab（3-10 格） | 大型主干地形 + 小型 Prefab |
| 视觉 | 单 tile 渲染 | Terrain Autotile 自动过渡 |

## Terrain Autotile 集成

### 素材

使用 Pipoya RPG Tileset 32x32 的 `[A]_type3` 目录素材：
- `[A]Grass1_pipo.png` — 草地（GROUND/SPAWN_ZONE）：256×192，8×6 格
- `[A]Water1_pipo.png` — 水域（ABYSS）：2048×192（含动画帧，取前 256×192）
- `[A]Wall-Up1_pipo.png` — 墙壁（WALL）：256×192，8×6 格
- `[A]Dirt1_pipo.png` — 泥地（BORDER）：256×192，8×6 格

type3 的 256×192（8×6 格）布局是 Godot 4.x Terrain 3×3 bitmask 的标准格式，包含 47 种自动地形组合。

### TileSet 配置

创建 `resources/maps/tilesets/pipoya_tileset.tres`：

1. **Tile Size**：32×32
2. **Atlas Sources**：4 个（Grass、Water、Wall、Dirt），各自导入对应 png
3. **Terrain Set 0**（Match Corners and Sides / 3×3 bitmask）：
   - Terrain 0: Grass（地面）
   - Terrain 1: Water（水域）
   - Terrain 2: Wall（墙壁）
   - Terrain 3: Dirt（边界/泥地）
4. **Physics Layer 0**：collision_layer=4(Solid), collision_mask=3
5. **Physics Layer 1**：collision_layer=256(WallBlock), collision_mask=0
6. **Physics 配置**：
   - Water tile：physics layer 0 全格碰撞
   - Wall tile：physics layer 0 + layer 1 全格碰撞
   - Dirt/Border tile：physics layer 0 全格碰撞
   - Grass tile：无碰撞

### TileSet 配置自动化

通过 EditorScript 或 MCP execute_editor_script 自动完成 TileSet 创建和 terrain peering bits 标记。type3 的 8×6 布局有固定的 peering bit 映射表，可程序化配置。

### apply_to_tilemap 改造

```gdscript
# 当前：逐格 set_cell() 设置单一 tile
# 改为：按 CellType 收集坐标，批量 set_cells_terrain_connect()

func apply_to_tilemap(map_scene: Node, layout: MapLayout, config: MapGeneratorConfig) -> void:
    var ground_layer: TileMapLayer = map_scene.get_node("Ground")
    var terrain_layer: TileMapLayer = map_scene.get_node("Terrain")

    # 收集各类型格子坐标（转换为 TileMap 坐标系）
    var grass_cells: Array[Vector2i] = []
    var water_cells: Array[Vector2i] = []
    var wall_cells: Array[Vector2i] = []
    var border_cells: Array[Vector2i] = []

    for gy in range(MapLayout.PLAYABLE_HEIGHT):
        for gx in range(MapLayout.PLAYABLE_WIDTH):
            var tile_pos := Vector2i(MapLayout.PLAYABLE_ORIGIN_X + gx, MapLayout.PLAYABLE_ORIGIN_Y + gy)
            match layout.get_cell(Vector2i(gx, gy)):
                MapLayout.CellType.GROUND, MapLayout.CellType.SPAWN_ZONE:
                    grass_cells.append(tile_pos)
                MapLayout.CellType.ABYSS:
                    water_cells.append(tile_pos)
                MapLayout.CellType.WALL:
                    wall_cells.append(tile_pos)
                MapLayout.CellType.BORDER:
                    border_cells.append(tile_pos)

    # 用 terrain API 批量设置，引擎自动选择过渡 tile
    var terrain_set := 0
    ground_layer.set_cells_terrain_connect(grass_cells, terrain_set, config.grass_terrain_id)
    ground_layer.set_cells_terrain_connect(border_cells, terrain_set, config.border_terrain_id)
    terrain_layer.set_cells_terrain_connect(water_cells, terrain_set, config.water_terrain_id)
    terrain_layer.set_cells_terrain_connect(wall_cells, terrain_set, config.wall_terrain_id)
```

### MapGeneratorConfig 字段更新

```
新增字段：
- templates: Array[MapTemplate]        # 可用模板池
- total_prefab_count: Vector2i = Vector2i(8, 15)  # Prefab 总数范围(min, max)
- grass_terrain_id: int = 0
- water_terrain_id: int = 1
- wall_terrain_id: int = 2
- border_terrain_id: int = 3

移除字段：
- symmetry_weights（不再使用对称模板）
- ground_tile / border_tile / wall_tile / abyss_tile（改用 terrain ID）

保留字段：
- prefabs, empty_chance, spawns_per_edge, corner_spawn_chance, min_spawn_spacing
- tileset_source_id（可能仍需用于 decoration 等非 terrain tile）
```

## 文件结构

```
新增：
  scripts/resources/map_template.gd          — MapTemplate Resource
  scripts/resources/terrain_feature.gd       — TerrainFeature Resource
  resources/maps/templates/*.tres            — 8 个模板数据文件
  resources/maps/tilesets/pipoya_tileset.tres — Pipoya TileSet（含 Terrain 配置）
  scripts/tools/setup_pipoya_tileset.gd      — EditorScript：自动配置 TileSet

修改：
  scripts/systems/map_generator.gd           — 模板渲染 + Prefab 散布（替换九宫格+对称）
  scripts/resources/map_generator_config.gd  — 新增 templates/terrain_id 字段，移除旧字段
  scenes/levels/maps/generated_map.tscn      — TileSet 换成 pipoya_tileset
  resources/maps/default_generator_config.tres — 更新配置

移除/废弃：
  map_generator.gd 中的对称模板相关方法：
    _pick_symmetry, _fill_tactical_zone, _get_primary_blocks,
    _get_mirror_block, _generate_block_placements, _try_place_in_bounds,
    _apply_placements, _mirror_placements
```

## 测试策略

在 `test_map_generator.gd` 中更新/新增：

- 模板渲染正确性：主干地形出现在预期位置
- 缺口连通性：河流/墙带的缺口保持 GROUND
- Prefab 不侵入主干地形和 PLAZA
- 中心安全区仍为空地
- 连通性验证通过（所有刷怪点可达）
- 模板切换：不同模板产生不同的地形分布
- placeable_cells 不包含 WALL/ABYSS/BORDER/SPAWN_ZONE

移除对称相关测试（test_mirror_x_symmetry, test_rotate_180_symmetry）。
