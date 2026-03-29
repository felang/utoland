# 随机地图生成系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将手绘 TileMap 地图替换为运行时随机生成系统，支持三层分区、Prefab 障碍物、对称模板和连通性验证。

**Architecture:** MapGenerator（RefCounted）读取 MapGeneratorConfig 配置，生成 MapLayout 数据（40×24 网格），再由 apply_to_tilemap() 写入 TileMapLayer。EnemySpawner 改为从固定刷怪点生成敌人，DragManager 增加可放置性校验。新增 WallBlock 碰撞层让实体墙阻挡投射物。

**Tech Stack:** Godot 4.6 / GDScript / GUT 测试框架

**Spec:** `docs/superpowers/specs/2026-03-29-random-map-generation-design.md`

---

## File Map

| 文件 | 职责 | 操作 |
|---|---|---|
| `scripts/core/map_layout.gd` | MapLayout 数据类（RefCounted），网格+坐标转换 | 新建 |
| `scripts/resources/map_prefab.gd` | MapPrefab Resource，Prefab 形状定义 | 新建 |
| `scripts/resources/map_generator_config.gd` | MapGeneratorConfig Resource，生成参数 | 新建 |
| `scripts/systems/map_generator.gd` | MapGenerator 核心生成逻辑 | 新建 |
| `tests/unit/test_map_layout.gd` | MapLayout 单元测试 | 新建 |
| `tests/unit/test_map_generator.gd` | MapGenerator 单元测试 | 新建 |
| `scripts/core/game_config.gd` | 更新可玩区常量，加载 Prefab | 修改 |
| `scripts/resources/map_data.gd` | 新增 generator_config 字段 | 修改 |
| `scripts/systems/enemy_spawner.gd` | 改用固定刷怪点 | 修改 |
| `scripts/systems/drag_manager.gd` | 加可放置性校验 | 修改 |
| `scripts/ui/main.gd` | 集成 MapGenerator | 修改 |
| `project.godot` | 新增第 9 碰撞层 WallBlock | 修改 |
| 投射物 `.tscn` 文件 (6个) | collision_mask 加 WallBlock(256) | 修改 |
| `scripts/shared/map_boundary.gd` | 移除 | 删除 |
| `scenes/shared/map_boundary.tscn` | 移除 | 删除 |

---

### Task 1: MapLayout 数据类

**Files:**
- Create: `scripts/core/map_layout.gd`
- Test: `tests/unit/test_map_layout.gd`

- [ ] **Step 1: 创建 MapLayout 类**

```gdscript
# scripts/core/map_layout.gd
class_name MapLayout
extends RefCounted

## 随机地图生成结果的数据载体

enum CellType { GROUND, BORDER, WALL, ABYSS, SPAWN_ZONE }

const PLAYABLE_WIDTH: int = 40
const PLAYABLE_HEIGHT: int = 24
const PLAYABLE_ORIGIN_X: int = 3  # 可玩区在总网格中的起始列
const PLAYABLE_ORIGIN_Y: int = 3  # 可玩区在总网格中的起始行

# 九宫格边界（战术区 x=3~36, y=3~20）
const TACTICAL_MIN_X: int = 3
const TACTICAL_MAX_X: int = 36
const TACTICAL_MIN_Y: int = 3
const TACTICAL_MAX_Y: int = 20

# 九宫格列划分：11 + 12 + 11 = 34
const GRID_COLS: Array[Vector2i] = [
	Vector2i(3, 13),   # 左列
	Vector2i(14, 25),  # 中列
	Vector2i(26, 36),  # 右列
]
# 九宫格行划分：6 + 6 + 6 = 18
const GRID_ROWS: Array[Vector2i] = [
	Vector2i(3, 8),    # 上行
	Vector2i(9, 14),   # 中行
	Vector2i(15, 20),  # 下行
]

var grid: Array = []  # Array[Array[CellType]]，40×24
var spawn_points: Array[Vector2i] = []
var placeable_cells: Array[Vector2i] = []
var player_spawn: Vector2i = Vector2i(19, 11)


func _init() -> void:
	_init_grid()


func _init_grid() -> void:
	grid.resize(PLAYABLE_HEIGHT)
	for y in range(PLAYABLE_HEIGHT):
		var row: Array = []
		row.resize(PLAYABLE_WIDTH)
		row.fill(CellType.GROUND)
		grid[y] = row


func get_cell(pos: Vector2i) -> CellType:
	if pos.x < 0 or pos.x >= PLAYABLE_WIDTH or pos.y < 0 or pos.y >= PLAYABLE_HEIGHT:
		return CellType.BORDER
	return grid[pos.y][pos.x]


func set_cell(pos: Vector2i, cell_type: CellType) -> void:
	if pos.x >= 0 and pos.x < PLAYABLE_WIDTH and pos.y >= 0 and pos.y < PLAYABLE_HEIGHT:
		grid[pos.y][pos.x] = cell_type


func is_passable(pos: Vector2i) -> bool:
	var cell := get_cell(pos)
	return cell == CellType.GROUND or cell == CellType.SPAWN_ZONE


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var world_x := (PLAYABLE_ORIGIN_X + grid_pos.x - GameConfig.MAP_GRID_WIDTH / 2.0) * GameConfig.GRID_SIZE + GameConfig.GRID_SIZE / 2.0
	var world_y := (PLAYABLE_ORIGIN_Y + grid_pos.y - GameConfig.MAP_GRID_HEIGHT / 2.0) * GameConfig.GRID_SIZE + GameConfig.GRID_SIZE / 2.0
	return Vector2(world_x, world_y)


func get_spawn_points_world() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for sp in spawn_points:
		result.append(grid_to_world(sp))
	return result


func get_player_spawn_world() -> Vector2:
	return grid_to_world(player_spawn)


func get_placeable_dict() -> Dictionary:
	var dict := {}
	for cell in placeable_cells:
		dict[cell] = true
	return dict


## 获取九宫格区块的边界（col_index, row_index 各 0-2）
func get_block_bounds(col_index: int, row_index: int) -> Rect2i:
	var col := GRID_COLS[col_index]
	var row := GRID_ROWS[row_index]
	return Rect2i(col.x, row.x, col.y - col.x + 1, row.y - row.x + 1)
```

- [ ] **Step 2: 写测试**

```gdscript
# tests/unit/test_map_layout.gd
extends GutTest

## MapLayout 单元测试

var layout: MapLayout


func before_each():
	layout = MapLayout.new()


func test_grid_dimensions():
	assert_eq(layout.grid.size(), 24, "网格高度应为 24")
	assert_eq(layout.grid[0].size(), 40, "网格宽度应为 40")


func test_initial_cells_are_ground():
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		for x in range(MapLayout.PLAYABLE_WIDTH):
			assert_eq(layout.get_cell(Vector2i(x, y)), MapLayout.CellType.GROUND)


func test_set_and_get_cell():
	layout.set_cell(Vector2i(5, 5), MapLayout.CellType.WALL)
	assert_eq(layout.get_cell(Vector2i(5, 5)), MapLayout.CellType.WALL)


func test_out_of_bounds_returns_border():
	assert_eq(layout.get_cell(Vector2i(-1, 0)), MapLayout.CellType.BORDER)
	assert_eq(layout.get_cell(Vector2i(40, 0)), MapLayout.CellType.BORDER)


func test_is_passable():
	assert_true(layout.is_passable(Vector2i(5, 5)), "GROUND 应可通行")
	layout.set_cell(Vector2i(5, 5), MapLayout.CellType.SPAWN_ZONE)
	assert_true(layout.is_passable(Vector2i(5, 5)), "SPAWN_ZONE 应可通行")
	layout.set_cell(Vector2i(5, 5), MapLayout.CellType.WALL)
	assert_false(layout.is_passable(Vector2i(5, 5)), "WALL 不可通行")
	layout.set_cell(Vector2i(5, 5), MapLayout.CellType.ABYSS)
	assert_false(layout.is_passable(Vector2i(5, 5)), "ABYSS 不可通行")


func test_grid_to_world_center():
	# grid(19, 11) ≈ 地图中心
	var world_pos := layout.grid_to_world(Vector2i(19, 11))
	# (3 + 19 - 22.5) * 32 + 16 = -0.5 * 32 + 16 = 0
	# (3 + 11 - 15.0) * 32 + 16 = -1.0 * 32 + 16 = -16
	assert_almost_eq(world_pos.x, 0.0, 1.0, "中心 x 应接近 0")
	assert_almost_eq(world_pos.y, -16.0, 1.0, "中心 y 应接近 -16")


func test_get_placeable_dict():
	layout.placeable_cells = [Vector2i(5, 5), Vector2i(10, 10)]
	var dict := layout.get_placeable_dict()
	assert_true(dict.has(Vector2i(5, 5)))
	assert_true(dict.has(Vector2i(10, 10)))
	assert_false(dict.has(Vector2i(0, 0)))


func test_get_block_bounds():
	# 左上角区块
	var bounds := layout.get_block_bounds(0, 0)
	assert_eq(bounds.position, Vector2i(3, 3))
	assert_eq(bounds.size, Vector2i(11, 6))
	# 中心区块
	var center := layout.get_block_bounds(1, 1)
	assert_eq(center.position, Vector2i(14, 9))
	assert_eq(center.size, Vector2i(12, 6))
```

- [ ] **Step 3: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_map_layout.gd -gexit`
Expected: All tests PASS

- [ ] **Step 4: 提交**

```bash
git add scripts/core/map_layout.gd tests/unit/test_map_layout.gd
git commit -m "feat: 添加 MapLayout 数据类和单元测试"
```

---

### Task 2: MapPrefab 和 MapGeneratorConfig Resource

**Files:**
- Create: `scripts/resources/map_prefab.gd`
- Create: `scripts/resources/map_generator_config.gd`

- [ ] **Step 1: 创建 MapPrefab Resource**

```gdscript
# scripts/resources/map_prefab.gd
class_name MapPrefab
extends Resource

## 地形预制件定义

@export var id: String = ""
@export var cell_type: MapLayout.CellType = MapLayout.CellType.WALL
@export var cells: Array[Vector2i] = []  # 相对坐标（锚点为原点）
@export var rotatable: bool = true
@export var tile_atlas_coords: Vector2i = Vector2i.ZERO


## 返回旋转后的 cells（rotation_steps: 0=0°, 1=90°, 2=180°, 3=270°）
func get_rotated_cells(rotation_steps: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(_rotate_cell(cell, rotation_steps))
	return result


## 返回水平翻转后的 cells
func get_mirrored_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(Vector2i(-cell.x, cell.y))
	return result


func _rotate_cell(cell: Vector2i, steps: int) -> Vector2i:
	var c := cell
	for i in range(steps % 4):
		c = Vector2i(-c.y, c.x)
	return c
```

- [ ] **Step 2: 创建 MapGeneratorConfig Resource**

```gdscript
# scripts/resources/map_generator_config.gd
class_name MapGeneratorConfig
extends Resource

## 随机地图生成参数配置

@export var prefabs: Array[MapPrefab] = []
@export var empty_chance: float = 0.35  # 每个区块留空概率
@export var min_prefabs_per_block: int = 1
@export var max_prefabs_per_block: int = 2
@export var spawns_per_edge: Vector2i = Vector2i(1, 2)  # 每条边刷怪点数量(min, max)
@export var corner_spawn_chance: float = 0.5
@export var min_spawn_spacing: int = 4  # 同边刷怪点最小间距
@export var symmetry_weights: Array[float] = [0.33, 0.34, 0.33]  # RANDOM/MIRROR_X/ROTATE_180
@export var ground_tile: Vector2i = Vector2i.ZERO
@export var border_tile: Vector2i = Vector2i.ZERO
@export var wall_tile: Vector2i = Vector2i.ZERO
@export var abyss_tile: Vector2i = Vector2i.ZERO
@export var decoration_tiles: Array[Vector2i] = []
@export var tileset_source_id: int = 0
```

- [ ] **Step 3: 提交**

```bash
git add scripts/resources/map_prefab.gd scripts/resources/map_generator_config.gd
git commit -m "feat: 添加 MapPrefab 和 MapGeneratorConfig Resource 类"
```

---

### Task 3: MapGenerator 核心逻辑 — 网格初始化和刷怪点

**Files:**
- Create: `scripts/systems/map_generator.gd`
- Test: `tests/unit/test_map_generator.gd`

- [ ] **Step 1: 创建 MapGenerator 框架 + 步骤 1-4（网格初始化到刷怪点）**

```gdscript
# scripts/systems/map_generator.gd
class_name MapGenerator
extends RefCounted

## 随机地图生成器

enum SymmetryMode { RANDOM, MIRROR_X, ROTATE_180 }

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func generate(config: MapGeneratorConfig, seed: int = -1) -> MapLayout:
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()

	var layout := MapLayout.new()

	_fill_borders(layout)
	_fill_spawn_zone(layout)
	_generate_spawn_points(layout, config)

	var success := _try_generate_terrain(layout, config)
	if not success:
		# 保底：清除所有 Prefab，返回空旷地图
		_clear_terrain(layout)

	_compute_placeable_cells(layout)
	return layout


func _fill_borders(layout: MapLayout) -> void:
	for x in range(MapLayout.PLAYABLE_WIDTH):
		layout.set_cell(Vector2i(x, 0), MapLayout.CellType.BORDER)
		layout.set_cell(Vector2i(x, MapLayout.PLAYABLE_HEIGHT - 1), MapLayout.CellType.BORDER)
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		layout.set_cell(Vector2i(0, y), MapLayout.CellType.BORDER)
		layout.set_cell(Vector2i(MapLayout.PLAYABLE_WIDTH - 1, y), MapLayout.CellType.BORDER)


func _fill_spawn_zone(layout: MapLayout) -> void:
	for x in range(1, MapLayout.PLAYABLE_WIDTH - 1):
		for y in range(1, 3):
			layout.set_cell(Vector2i(x, y), MapLayout.CellType.SPAWN_ZONE)
		for y in range(MapLayout.PLAYABLE_HEIGHT - 3, MapLayout.PLAYABLE_HEIGHT - 1):
			layout.set_cell(Vector2i(x, y), MapLayout.CellType.SPAWN_ZONE)
	for y in range(1, MapLayout.PLAYABLE_HEIGHT - 1):
		for x in range(1, 3):
			layout.set_cell(Vector2i(x, y), MapLayout.CellType.SPAWN_ZONE)
		for x in range(MapLayout.PLAYABLE_WIDTH - 3, MapLayout.PLAYABLE_WIDTH - 1):
			layout.set_cell(Vector2i(x, y), MapLayout.CellType.SPAWN_ZONE)


func _generate_spawn_points(layout: MapLayout, config: MapGeneratorConfig) -> void:
	# 四条边各生成 1-2 个刷怪点
	var edges := [
		{"axis": "x", "range": Vector2i(3, 36), "fixed_axis": "y", "fixed_values": [1, 2]},      # 上边
		{"axis": "x", "range": Vector2i(3, 36), "fixed_axis": "y", "fixed_values": [21, 22]},     # 下边
		{"axis": "y", "range": Vector2i(3, 20), "fixed_axis": "x", "fixed_values": [1, 2]},       # 左边
		{"axis": "y", "range": Vector2i(3, 20), "fixed_axis": "x", "fixed_values": [37, 38]},     # 右边
	]

	for edge in edges:
		var count := _rng.randi_range(config.spawns_per_edge.x, config.spawns_per_edge.y)
		var positions: Array[int] = []
		for i in range(count):
			var pos := _pick_spawn_pos_on_edge(edge["range"] as Vector2i, positions, config.min_spawn_spacing)
			if pos >= 0:
				positions.append(pos)
				var fixed_val: int = (edge["fixed_values"] as Array)[_rng.randi_range(0, 1)]
				var spawn_pos: Vector2i
				if edge["axis"] == "x":
					spawn_pos = Vector2i(pos, fixed_val)
				else:
					spawn_pos = Vector2i(fixed_val, pos)
				layout.spawn_points.append(spawn_pos)

	# 四角各 0-1 个
	var corners := [
		Vector2i(1, 1), Vector2i(38, 1),
		Vector2i(1, 22), Vector2i(38, 22),
	]
	for corner in corners:
		if _rng.randf() < config.corner_spawn_chance:
			layout.spawn_points.append(corner)


func _pick_spawn_pos_on_edge(pos_range: Vector2i, existing: Array[int], min_spacing: int) -> int:
	for attempt in range(20):
		var pos := _rng.randi_range(pos_range.x, pos_range.y)
		var valid := true
		for ex in existing:
			if abs(pos - ex) < min_spacing:
				valid = false
				break
		if valid:
			return pos
	return -1


func _try_generate_terrain(_layout: MapLayout, _config: MapGeneratorConfig) -> bool:
	# 占位，Task 4 实现
	return true


func _clear_terrain(layout: MapLayout) -> void:
	for y in range(MapLayout.TACTICAL_MIN_Y, MapLayout.TACTICAL_MAX_Y + 1):
		for x in range(MapLayout.TACTICAL_MIN_X, MapLayout.TACTICAL_MAX_X + 1):
			if layout.get_cell(Vector2i(x, y)) in [MapLayout.CellType.WALL, MapLayout.CellType.ABYSS]:
				layout.set_cell(Vector2i(x, y), MapLayout.CellType.GROUND)


func _compute_placeable_cells(layout: MapLayout) -> void:
	layout.placeable_cells.clear()
	for y in range(MapLayout.TACTICAL_MIN_Y, MapLayout.TACTICAL_MAX_Y + 1):
		for x in range(MapLayout.TACTICAL_MIN_X, MapLayout.TACTICAL_MAX_X + 1):
			if layout.get_cell(Vector2i(x, y)) == MapLayout.CellType.GROUND:
				layout.placeable_cells.append(Vector2i(x, y))
```

- [ ] **Step 2: 写测试（网格初始化 + 刷怪点）**

```gdscript
# tests/unit/test_map_generator.gd
extends GutTest

## MapGenerator 单元测试

var generator: MapGenerator
var config: MapGeneratorConfig


func before_each():
	generator = MapGenerator.new()
	config = MapGeneratorConfig.new()


func test_borders_filled():
	var layout := generator.generate(config, 42)
	# 四条边应全是 BORDER
	for x in range(MapLayout.PLAYABLE_WIDTH):
		assert_eq(layout.get_cell(Vector2i(x, 0)), MapLayout.CellType.BORDER, "上边界 x=%d" % x)
		assert_eq(layout.get_cell(Vector2i(x, 23)), MapLayout.CellType.BORDER, "下边界 x=%d" % x)
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		assert_eq(layout.get_cell(Vector2i(0, y)), MapLayout.CellType.BORDER, "左边界 y=%d" % y)
		assert_eq(layout.get_cell(Vector2i(39, y)), MapLayout.CellType.BORDER, "右边界 y=%d" % y)


func test_spawn_zone_filled():
	var layout := generator.generate(config, 42)
	# 上方刷怪区 y=1,2
	for x in range(1, 39):
		for y in [1, 2]:
			assert_eq(layout.get_cell(Vector2i(x, y)), MapLayout.CellType.SPAWN_ZONE, "刷怪区 (%d,%d)" % [x, y])


func test_spawn_points_count():
	var layout := generator.generate(config, 42)
	assert_gt(layout.spawn_points.size(), 3, "至少 4 个刷怪点")
	assert_lt(layout.spawn_points.size(), 13, "最多 12 个刷怪点")


func test_spawn_points_in_spawn_zone():
	var layout := generator.generate(config, 42)
	for sp in layout.spawn_points:
		assert_eq(layout.get_cell(sp), MapLayout.CellType.SPAWN_ZONE, "刷怪点 %s 应在刷怪区" % sp)


func test_center_block_is_clear():
	var layout := generator.generate(config, 42)
	# 中心区 x=14~25, y=9~14
	for y in range(9, 15):
		for x in range(14, 26):
			assert_eq(layout.get_cell(Vector2i(x, y)), MapLayout.CellType.GROUND, "中心区 (%d,%d) 应为空地" % [x, y])


func test_seed_reproducibility():
	var layout1 := generator.generate(config, 123)
	var layout2 := generator.generate(config, 123)
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		for x in range(MapLayout.PLAYABLE_WIDTH):
			assert_eq(layout1.get_cell(Vector2i(x, y)), layout2.get_cell(Vector2i(x, y)),
				"相同种子应产生相同地图 (%d,%d)" % [x, y])


func test_placeable_cells_valid():
	var layout := generator.generate(config, 42)
	assert_gt(layout.placeable_cells.size(), 0, "应有可放置格子")
	for cell in layout.placeable_cells:
		assert_eq(layout.get_cell(cell), MapLayout.CellType.GROUND, "可放置格子应为 GROUND")
		assert_true(cell.x >= MapLayout.TACTICAL_MIN_X and cell.x <= MapLayout.TACTICAL_MAX_X, "可放置格子应在战术区 x 范围")
		assert_true(cell.y >= MapLayout.TACTICAL_MIN_Y and cell.y <= MapLayout.TACTICAL_MAX_Y, "可放置格子应在战术区 y 范围")
```

- [ ] **Step 3: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_map_generator.gd -gexit`
Expected: All tests PASS

- [ ] **Step 4: 提交**

```bash
git add scripts/systems/map_generator.gd tests/unit/test_map_generator.gd
git commit -m "feat: MapGenerator 核心框架（网格初始化+刷怪点生成）"
```

---

### Task 4: MapGenerator — 对称模板和 Prefab 填充

**Files:**
- Modify: `scripts/systems/map_generator.gd`
- Modify: `tests/unit/test_map_generator.gd`

- [ ] **Step 1: 实现 _try_generate_terrain（对称+Prefab+连通性验证）**

替换 `_try_generate_terrain` 占位方法，添加以下方法到 `map_generator.gd`：

```gdscript
func _try_generate_terrain(layout: MapLayout, config: MapGeneratorConfig) -> bool:
	if config.prefabs.is_empty():
		return true

	# 尝试标准密度
	for attempt in range(10):
		_clear_terrain(layout)
		var symmetry := _pick_symmetry(config)
		_fill_tactical_zone(layout, config, symmetry, config.max_prefabs_per_block)
		if _validate_connectivity(layout):
			return true

	# 降低密度重试
	for attempt in range(5):
		_clear_terrain(layout)
		var symmetry := _pick_symmetry(config)
		_fill_tactical_zone(layout, config, symmetry, 1)
		if _validate_connectivity(layout):
			return true

	# 保底
	return false


func _pick_symmetry(config: MapGeneratorConfig) -> SymmetryMode:
	var roll := _rng.randf()
	var cumulative := 0.0
	for i in range(config.symmetry_weights.size()):
		cumulative += config.symmetry_weights[i]
		if roll <= cumulative:
			return i  # SymmetryMode 枚举值即 int
	return SymmetryMode.RANDOM


## 区块索引映射（col, row）→ 名称：(0,0)=TL, (1,0)=TC, (2,0)=TR, (0,1)=ML, (1,1)=中心, (2,1)=MR, (0,2)=BL, (1,2)=BC, (2,2)=BR
func _fill_tactical_zone(layout: MapLayout, config: MapGeneratorConfig, symmetry: SymmetryMode, max_per_block: int) -> void:
	# 根据对称模式确定主区块和镜像关系
	var block_assignments: Dictionary = {}  # Vector2i(col,row) → {prefabs, rotations, offsets}

	var primary_blocks: Array[Vector2i] = _get_primary_blocks(symmetry)

	for block_pos in primary_blocks:
		if _rng.randf() < config.empty_chance:
			continue

		var count := _rng.randi_range(config.min_prefabs_per_block, min(max_per_block, config.max_prefabs_per_block))
		var placements := _generate_block_placements(layout, config, block_pos, count)
		block_assignments[block_pos] = placements

		# 应用到网格
		_apply_placements(layout, placements)

		# 生成对称区块
		var mirror_pos := _get_mirror_block(block_pos, symmetry)
		if mirror_pos != Vector2i(-1, -1) and mirror_pos != block_pos:
			var mirrored := _mirror_placements(layout, placements, block_pos, mirror_pos, symmetry)
			_apply_placements(layout, mirrored)


func _get_primary_blocks(symmetry: SymmetryMode) -> Array[Vector2i]:
	match symmetry:
		SymmetryMode.RANDOM:
			# 所有 8 个非中心区块
			return [
				Vector2i(0,0), Vector2i(1,0), Vector2i(2,0),
				Vector2i(0,1), Vector2i(2,1),
				Vector2i(0,2), Vector2i(1,2), Vector2i(2,2),
			]
		SymmetryMode.MIRROR_X:
			# 左侧 + 上下中间
			return [
				Vector2i(0,0), Vector2i(0,1), Vector2i(0,2),
				Vector2i(1,0), Vector2i(1,2),
			]
		SymmetryMode.ROTATE_180:
			# 左上半 + 中上
			return [
				Vector2i(0,0), Vector2i(1,0), Vector2i(2,0),
				Vector2i(0,1),
			]
	return []


func _get_mirror_block(block_pos: Vector2i, symmetry: SymmetryMode) -> Vector2i:
	match symmetry:
		SymmetryMode.MIRROR_X:
			if block_pos.x == 0:
				return Vector2i(2, block_pos.y)
			return Vector2i(-1, -1)  # TC/BC 无镜像
		SymmetryMode.ROTATE_180:
			return Vector2i(2 - block_pos.x, 2 - block_pos.y)
	return Vector2i(-1, -1)


func _generate_block_placements(layout: MapLayout, config: MapGeneratorConfig, block_pos: Vector2i, count: int) -> Array[Dictionary]:
	var bounds := layout.get_block_bounds(block_pos.x, block_pos.y)
	var placements: Array[Dictionary] = []

	for i in range(count):
		var prefab: MapPrefab = config.prefabs[_rng.randi_range(0, config.prefabs.size() - 1)]
		var rotation := 0
		if prefab.rotatable:
			rotation = _rng.randi_range(0, 3)

		var cells := prefab.get_rotated_cells(rotation)
		var placed := _try_place_in_bounds(layout, cells, bounds, prefab.cell_type)
		if placed.size() > 0:
			placements.append({
				"prefab": prefab,
				"rotation": rotation,
				"cells": placed,
				"anchor": placed[0],
			})

	return placements


func _try_place_in_bounds(layout: MapLayout, cells: Array[Vector2i], bounds: Rect2i, cell_type: MapLayout.CellType) -> Array[Vector2i]:
	for attempt in range(15):
		var offset := Vector2i(
			_rng.randi_range(bounds.position.x, bounds.position.x + bounds.size.x - 1),
			_rng.randi_range(bounds.position.y, bounds.position.y + bounds.size.y - 1),
		)
		var placed: Array[Vector2i] = []
		var valid := true
		for cell in cells:
			var pos := offset + cell
			if pos.x < bounds.position.x or pos.x > bounds.position.x + bounds.size.x - 1:
				valid = false
				break
			if pos.y < bounds.position.y or pos.y > bounds.position.y + bounds.size.y - 1:
				valid = false
				break
			if layout.get_cell(pos) != MapLayout.CellType.GROUND:
				valid = false
				break
			placed.append(pos)
		if valid:
			return placed
	return []


func _apply_placements(layout: MapLayout, placements: Array[Dictionary]) -> void:
	for placement in placements:
		var prefab: MapPrefab = placement["prefab"]
		for cell in placement["cells"] as Array[Vector2i]:
			layout.set_cell(cell, prefab.cell_type)


func _mirror_placements(layout: MapLayout, placements: Array[Dictionary], src_block: Vector2i, dst_block: Vector2i, symmetry: SymmetryMode) -> Array[Dictionary]:
	var src_bounds := layout.get_block_bounds(src_block.x, src_block.y)
	var dst_bounds := layout.get_block_bounds(dst_block.x, dst_block.y)
	var result: Array[Dictionary] = []

	for placement in placements:
		var mirrored_cells: Array[Vector2i] = []
		var valid := true
		for cell in placement["cells"] as Array[Vector2i]:
			var new_pos: Vector2i
			match symmetry:
				SymmetryMode.MIRROR_X:
					# 水平翻转：相对于源区块中心翻转到目标区块
					var rel_x := cell.x - src_bounds.position.x
					var rel_y := cell.y - src_bounds.position.y
					new_pos = Vector2i(dst_bounds.position.x + dst_bounds.size.x - 1 - rel_x, dst_bounds.position.y + rel_y)
				SymmetryMode.ROTATE_180:
					# 180° 旋转
					var rel_x := cell.x - src_bounds.position.x
					var rel_y := cell.y - src_bounds.position.y
					new_pos = Vector2i(dst_bounds.position.x + dst_bounds.size.x - 1 - rel_x, dst_bounds.position.y + dst_bounds.size.y - 1 - rel_y)

			if layout.get_cell(new_pos) != MapLayout.CellType.GROUND:
				valid = false
				break
			mirrored_cells.append(new_pos)

		if valid:
			result.append({
				"prefab": placement["prefab"],
				"rotation": placement["rotation"],
				"cells": mirrored_cells,
				"anchor": mirrored_cells[0] if mirrored_cells.size() > 0 else Vector2i.ZERO,
			})

	return result


## Flood fill 连通性验证
func _validate_connectivity(layout: MapLayout) -> bool:
	if layout.spawn_points.is_empty():
		return true

	var visited := {}
	var queue: Array[Vector2i] = [layout.player_spawn]
	visited[layout.player_spawn] = true
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while queue.size() > 0:
		var current := queue.pop_front() as Vector2i
		for dir in directions:
			var next := current + dir
			if visited.has(next):
				continue
			if layout.is_passable(next):
				visited[next] = true
				queue.append(next)

	for sp in layout.spawn_points:
		if not visited.has(sp):
			return false
	return true
```

- [ ] **Step 2: 添加对称和连通性测试**

追加到 `tests/unit/test_map_generator.gd`：

```gdscript
func _make_config_with_prefabs() -> MapGeneratorConfig:
	var cfg := MapGeneratorConfig.new()
	# 创建一个简单的 2×1 墙壁 prefab
	var wall := MapPrefab.new()
	wall.id = "wall_test"
	wall.cell_type = MapLayout.CellType.WALL
	wall.cells = [Vector2i(0, 0), Vector2i(1, 0)]
	wall.rotatable = true
	cfg.prefabs = [wall]
	cfg.empty_chance = 0.0  # 强制每块都放
	return cfg


func test_connectivity_all_spawn_points_reachable():
	var cfg := _make_config_with_prefabs()
	var layout := generator.generate(cfg, 42)
	# 生成器保证连通性，所以所有刷怪点应可达
	var visited := {}
	var queue: Array[Vector2i] = [layout.player_spawn]
	visited[layout.player_spawn] = true
	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	while queue.size() > 0:
		var current := queue.pop_front()
		for dir in dirs:
			var next: Vector2i = current + dir
			if visited.has(next):
				continue
			if layout.is_passable(next):
				visited[next] = true
				queue.append(next)
	for sp in layout.spawn_points:
		assert_true(visited.has(sp), "刷怪点 %s 应可达玩家位置" % sp)


func test_mirror_x_symmetry():
	var cfg := _make_config_with_prefabs()
	cfg.symmetry_weights = [0.0, 1.0, 0.0]  # 强制 MIRROR_X
	var layout := generator.generate(cfg, 42)
	# 检查左上和右上区块的 WALL 数量应相等
	var left_walls := 0
	var right_walls := 0
	var left_bounds := layout.get_block_bounds(0, 0)
	var right_bounds := layout.get_block_bounds(2, 0)
	for y in range(left_bounds.position.y, left_bounds.position.y + left_bounds.size.y):
		for x in range(left_bounds.position.x, left_bounds.position.x + left_bounds.size.x):
			if layout.get_cell(Vector2i(x, y)) == MapLayout.CellType.WALL:
				left_walls += 1
	for y in range(right_bounds.position.y, right_bounds.position.y + right_bounds.size.y):
		for x in range(right_bounds.position.x, right_bounds.position.x + right_bounds.size.x):
			if layout.get_cell(Vector2i(x, y)) == MapLayout.CellType.WALL:
				right_walls += 1
	assert_eq(left_walls, right_walls, "MIRROR_X 对称：左上和右上墙数量应相等")


func test_rotate_180_symmetry():
	var cfg := _make_config_with_prefabs()
	cfg.symmetry_weights = [0.0, 0.0, 1.0]  # 强制 ROTATE_180
	var layout := generator.generate(cfg, 42)
	# TL 和 BR 区块的 WALL 数量应相等
	var tl_walls := 0
	var br_walls := 0
	var tl_bounds := layout.get_block_bounds(0, 0)
	var br_bounds := layout.get_block_bounds(2, 2)
	for y in range(tl_bounds.position.y, tl_bounds.position.y + tl_bounds.size.y):
		for x in range(tl_bounds.position.x, tl_bounds.position.x + tl_bounds.size.x):
			if layout.get_cell(Vector2i(x, y)) == MapLayout.CellType.WALL:
				tl_walls += 1
	for y in range(br_bounds.position.y, br_bounds.position.y + br_bounds.size.y):
		for x in range(br_bounds.position.x, br_bounds.position.x + br_bounds.size.x):
			if layout.get_cell(Vector2i(x, y)) == MapLayout.CellType.WALL:
				br_walls += 1
	assert_eq(tl_walls, br_walls, "ROTATE_180 对称：TL 和 BR 墙数量应相等")


func test_fallback_to_empty_map():
	# 用巨大 Prefab 填满，触发连通性失败保底
	var cfg := MapGeneratorConfig.new()
	var big_wall := MapPrefab.new()
	big_wall.id = "huge_wall"
	big_wall.cell_type = MapLayout.CellType.WALL
	# 创建一个 10×5 的巨墙
	var cells: Array[Vector2i] = []
	for y in range(5):
		for x in range(10):
			cells.append(Vector2i(x, y))
	big_wall.cells = cells
	big_wall.rotatable = false
	cfg.prefabs = [big_wall]
	cfg.empty_chance = 0.0
	cfg.max_prefabs_per_block = 2

	var layout := generator.generate(cfg, 42)
	# 无论如何都应返回有效地图，连通性应保证
	assert_not_null(layout)
	assert_gt(layout.spawn_points.size(), 0, "应有刷怪点")
```

- [ ] **Step 3: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_map_generator.gd -gexit`
Expected: All tests PASS

- [ ] **Step 4: 提交**

```bash
git add scripts/systems/map_generator.gd tests/unit/test_map_generator.gd
git commit -m "feat: MapGenerator 对称模板填充和连通性验证"
```

---

### Task 5: GameConfig 常量更新 + 碰撞层 + MapData 字段

**Files:**
- Modify: `scripts/core/game_config.gd:22-23`
- Modify: `scripts/resources/map_data.gd`
- Modify: `project.godot:104-113`

- [ ] **Step 1: 更新 GameConfig 可玩区常量**

在 `scripts/core/game_config.gd` 中：

```
Line 22: const PLAY_AREA_GRID_WIDTH = 41  →  const PLAY_AREA_GRID_WIDTH = 40
Line 23: const PLAY_AREA_GRID_HEIGHT = 28  →  const PLAY_AREA_GRID_HEIGHT = 24
```

新增常量（在 PLAY_AREA 常量下方）：

```gdscript
const PLAYABLE_ORIGIN_X: int = 3
const PLAYABLE_ORIGIN_Y: int = 3
```

- [ ] **Step 2: MapData 新增 generator_config 字段**

在 `scripts/resources/map_data.gd` 末尾追加：

```gdscript
@export var generator_config: MapGeneratorConfig = null  # null 表示手绘地图
```

- [ ] **Step 3: project.godot 新增第 9 碰撞层**

在 `project.godot` 的 `[layer_names]` section 追加：

```
2d_physics/layer_9="WallBlock"
```

- [ ] **Step 4: 运行现有测试确认不破坏**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 现有测试不应因常量变更而大面积失败（可能有个别尺寸相关测试需要更新）

- [ ] **Step 5: 修复因常量变更导致的测试失败**

检查 `test_game_config_dimensions.gd`、`test_ui_scene_dimensions.gd` 等尺寸相关测试，将断言中的 41→40、28→24、656→640、448→384。

- [ ] **Step 6: 提交**

```bash
git add scripts/core/game_config.gd scripts/resources/map_data.gd project.godot tests/
git commit -m "chore: 更新可玩区常量(40×24)、新增 WallBlock 碰撞层和 MapData.generator_config"
```

---

### Task 6: 投射物碰撞 mask 更新

**Files:**
- Modify: `scenes/entities/projectiles/arrow.tscn`
- Modify: `scenes/entities/projectiles/shuriken.tscn`
- Modify: `scenes/entities/projectiles/pea_bullet.tscn`
- Modify: `scenes/entities/projectiles/ice_bullet.tscn`
- Modify: `scenes/entities/projectiles/bullet_projectile.tscn`
- Modify: `scenes/entities/projectiles/shuriken_projectile.tscn`
- Modify: `scripts/entities/projectiles/projectile.gd`

- [ ] **Step 1: 更新所有投射物 .tscn 的 collision_mask**

所有投射物的 Hitbox 节点：`collision_mask` 从 `128`（EnemyHurt 层 8）改为 `384`（128 + 256，即 EnemyHurt + WallBlock）。

在每个 `.tscn` 文件中找到 `collision_mask = 128` 替换为 `collision_mask = 384`。

- [ ] **Step 2: projectile.gd 添加墙壁碰撞处理**

在 `scripts/entities/projectiles/projectile.gd` 的碰撞处理中，添加对 body（StaticBody2D/TileMap）的检测。投射物的 Hitbox 是 Area2D，需要添加 `body_entered` 信号连接来检测 TileMapLayer 碰撞：

```gdscript
# 在 setup() 中添加 body_entered 连接
if hitbox:
	if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)

# 新方法
func _on_hitbox_body_entered(_body: Node2D) -> void:
	# 碰到实体墙（WallBlock 层的 StaticBody2D/TileMap），销毁投射物
	request_destroy()
```

- [ ] **Step 3: 提交**

```bash
git add scenes/entities/projectiles/ scripts/entities/projectiles/projectile.gd
git commit -m "feat: 投射物碰撞 mask 新增 WallBlock 层，碰墙销毁"
```

---

### Task 7: EnemySpawner 改用固定刷怪点

**Files:**
- Modify: `scripts/systems/enemy_spawner.gd:134-144`
- Modify: `tests/unit/test_enemy_spawner.gd`

- [ ] **Step 1: 重写 EnemySpawner 的刷怪位置逻辑**

在 `scripts/systems/enemy_spawner.gd` 中：

1. 新增属性：
```gdscript
var spawn_points: Array[Vector2] = []  # 由 main.gd 从 MapLayout 传入
```

2. 重写 `get_random_spawn_position()`：
```gdscript
func get_random_spawn_position() -> Vector2:
	if spawn_points.is_empty():
		# 兼容模式：无刷怪点时使用旧逻辑
		return _legacy_random_position()

	var base_pos := spawn_points[randi() % spawn_points.size()]
	# 加小量随机偏移（±16px，半格）
	var offset := Vector2(randf_range(-16, 16), randf_range(-16, 16))
	return base_pos + offset


func _legacy_random_position() -> Vector2:
	# 原有的随机位置逻辑（为手绘地图兼容保留）
	var spawn_pos := Vector2.ZERO
	var attempts := 0
	var max_attempts: int = GameConfig.spawn.max_spawn_attempts if GameConfig.spawn else 10
	while attempts < max_attempts:
		spawn_pos.x = randf_range(map_min_x, map_max_x)
		spawn_pos.y = randf_range(map_min_y, map_max_y)
		if player and player.global_position.distance_to(spawn_pos) >= min_distance_from_player:
			break
		attempts += 1
	return spawn_pos
```

- [ ] **Step 2: 更新测试**

在 `tests/unit/test_enemy_spawner.gd` 中添加：

```gdscript
func test_spawn_from_fixed_points():
	var points: Array[Vector2] = [Vector2(100, 200), Vector2(-100, -200)]
	enemy_spawner.spawn_points = points
	var pos := enemy_spawner.get_random_spawn_position()
	# 应在某个刷怪点附近（±16px）
	var near_any := false
	for p in points:
		if pos.distance_to(p) <= 23.0:  # sqrt(16^2 + 16^2) ≈ 22.6
			near_any = true
			break
	assert_true(near_any, "生成位置应在刷怪点附近")
```

- [ ] **Step 3: 运行测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_enemy_spawner.gd -gexit`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add scripts/systems/enemy_spawner.gd tests/unit/test_enemy_spawner.gd
git commit -m "feat: EnemySpawner 改用固定刷怪点生成敌人"
```

---

### Task 8: DragManager 可放置性校验

**Files:**
- Modify: `scripts/systems/drag_manager.gd:298-308`
- Modify: `tests/unit/test_drag_manager.gd`

- [ ] **Step 1: 添加 placeable_cells 校验**

在 `scripts/systems/drag_manager.gd` 中：

1. 新增属性：
```gdscript
var placeable_cells: Dictionary = {}  # {Vector2i: true}，由 main.gd 传入
```

2. 修改 `_is_grid_available()` 方法（约 line 302-308），在现有塔碰撞检查前加入：
```gdscript
func _is_grid_available(grid_pos: Vector2i) -> bool:
	# 新增：可放置性校验（如果有 placeable_cells 数据）
	if not placeable_cells.is_empty():
		if not placeable_cells.has(grid_pos):
			return false
	# 原有的塔碰撞检查（deployed_towers 是 Dictionary，key=deploy_id）
	for deploy_id in InventoryManager.deployed_towers:
		var tower_info: Dictionary = InventoryManager.deployed_towers[deploy_id]
		if tower_info.get("grid_pos") == grid_pos:
			return false
	return true
```

- [ ] **Step 2: 更新测试**

在 `tests/unit/test_drag_manager.gd` 中添加：

```gdscript
func test_placeable_cells_blocks_invalid_pos():
	drag_manager.placeable_cells = {Vector2i(5, 5): true, Vector2i(6, 6): true}
	assert_true(drag_manager._is_grid_available(Vector2i(5, 5)), "在 placeable_cells 中的位置应可用")
	assert_false(drag_manager._is_grid_available(Vector2i(10, 10)), "不在 placeable_cells 中的位置应不可用")


func test_empty_placeable_cells_allows_all():
	drag_manager.placeable_cells = {}
	assert_true(drag_manager._is_grid_available(Vector2i(10, 10)), "空 placeable_cells 应允许所有位置")
```

- [ ] **Step 3: 运行测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_drag_manager.gd -gexit`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add scripts/systems/drag_manager.gd tests/unit/test_drag_manager.gd
git commit -m "feat: DragManager 新增可放置性校验"
```

---

### Task 9: MapGenerator.apply_to_tilemap + 地图模板场景

**Files:**
- Modify: `scripts/systems/map_generator.gd`
- Create: `scenes/levels/maps/generated_map.tscn`（需通过 Godot MCP 创建）

- [ ] **Step 1: 实现 apply_to_tilemap**

在 `scripts/systems/map_generator.gd` 中添加：

```gdscript
func apply_to_tilemap(map_scene: Node, layout: MapLayout, config: MapGeneratorConfig) -> void:
	var ground_layer: TileMapLayer = map_scene.get_node("Ground")
	var terrain_layer: TileMapLayer = map_scene.get_node("Terrain")
	var background_layer: TileMapLayer = map_scene.get_node_or_null("Background")

	assert(ground_layer != null, "地图模板缺少 Ground 节点")
	assert(terrain_layer != null, "地图模板缺少 Terrain 节点")

	var src_id := config.tileset_source_id

	# 铺设地面和边界（在总网格坐标系中操作）
	for gy in range(MapLayout.PLAYABLE_HEIGHT):
		for gx in range(MapLayout.PLAYABLE_WIDTH):
			var tile_x := MapLayout.PLAYABLE_ORIGIN_X + gx
			var tile_y := MapLayout.PLAYABLE_ORIGIN_Y + gy
			var cell := layout.get_cell(Vector2i(gx, gy))
			match cell:
				MapLayout.CellType.GROUND, MapLayout.CellType.SPAWN_ZONE:
					ground_layer.set_cell(Vector2i(tile_x, tile_y), src_id, config.ground_tile)
				MapLayout.CellType.BORDER:
					ground_layer.set_cell(Vector2i(tile_x, tile_y), src_id, config.border_tile)
				MapLayout.CellType.WALL:
					ground_layer.set_cell(Vector2i(tile_x, tile_y), src_id, config.ground_tile)
					terrain_layer.set_cell(Vector2i(tile_x, tile_y), src_id, config.wall_tile)
				MapLayout.CellType.ABYSS:
					terrain_layer.set_cell(Vector2i(tile_x, tile_y), src_id, config.abyss_tile)

	# 装饰背景区
	if background_layer and config.decoration_tiles.size() > 0:
		for y in range(GameConfig.MAP_GRID_HEIGHT):
			for x in range(GameConfig.MAP_GRID_WIDTH):
				var in_playable := (x >= MapLayout.PLAYABLE_ORIGIN_X
					and x < MapLayout.PLAYABLE_ORIGIN_X + MapLayout.PLAYABLE_WIDTH
					and y >= MapLayout.PLAYABLE_ORIGIN_Y
					and y < MapLayout.PLAYABLE_ORIGIN_Y + MapLayout.PLAYABLE_HEIGHT)
				if not in_playable:
					var tile := config.decoration_tiles[_rng.randi_range(0, config.decoration_tiles.size() - 1)]
					background_layer.set_cell(Vector2i(x, y), src_id, tile)
```

- [ ] **Step 2: 创建 generated_map.tscn 模板场景**

通过 Godot MCP 或手动创建场景，结构如下：

```
GeneratedMap (Node2D)
├── Background (TileMapLayer, z_index=-1)
├── Ground (TileMapLayer, z_index=-1)
├── Terrain (TileMapLayer, z_index=0)
├── PickupLayer (Node2D, z_index=0)
├── EntityLayer (Node2D, z_index=1, y_sort_enabled=true)
├── ProjectileLayer (Node2D, z_index=2)
```

所有 TileMapLayer 共用同一个 TileSet 资源（需要包含 ground/border/wall/abyss tile 及对应的 physics layer 配置）。

- [ ] **Step 3: 提交**

```bash
git add scripts/systems/map_generator.gd scenes/levels/maps/generated_map.tscn
git commit -m "feat: MapGenerator.apply_to_tilemap 和地图模板场景"
```

---

### Task 10: main.gd 集成 MapGenerator

**Files:**
- Modify: `scripts/ui/main.gd:89-107`

- [ ] **Step 1: 改造 _load_map()**

重写 `scripts/ui/main.gd` 的 `_load_map()` 方法（line 89-107）：

```gdscript
func _load_map() -> void:
	var map_data: MapData = GameConfig.maps.get(PlayerState.selected_map)
	if map_data == null or map_data.map_scene.is_empty():
		push_warning("地图场景未配置，跳过加载: " + PlayerState.selected_map)
		return
	if not ResourceLoader.exists(map_data.map_scene):
		push_warning("地图场景文件不存在: " + map_data.map_scene)
		return

	var map_instance = load(map_data.map_scene).instantiate()
	add_child(map_instance)
	move_child(map_instance, 0)

	# 随机地图生成
	if map_data.generator_config != null:
		var generator := MapGenerator.new()
		var layout := generator.generate(map_data.generator_config)
		generator.apply_to_tilemap(map_instance, layout, map_data.generator_config)

		# 传递生成数据
		if enemy_spawner:
			enemy_spawner.spawn_points = layout.get_spawn_points_world()
		if drag_manager:
			drag_manager.placeable_cells = layout.get_placeable_dict()
		_player_spawn_pos = layout.get_player_spawn_world()
	else:
		_player_spawn_pos = Vector2.ZERO  # 手绘地图默认中心

	# 从地图场景中获取分层容器（不变）
	_entity_layer = map_instance.get_node("EntityLayer")
	_projectile_layer = map_instance.get_node("ProjectileLayer")
	_pickup_layer = map_instance.get_node("PickupLayer")
	assert(_entity_layer != null, "地图缺少 EntityLayer 节点")
	assert(_projectile_layer != null, "地图缺少 ProjectileLayer 节点")
	assert(_pickup_layer != null, "地图缺少 PickupLayer 节点")
```

注意：需要在 main.gd 中新增 `var _player_spawn_pos: Vector2` 变量，并在玩家初始化时使用它设置位置。

- [ ] **Step 2: 提交**

```bash
git add scripts/ui/main.gd
git commit -m "feat: main.gd 集成 MapGenerator 随机地图生成"
```

---

### Task 11: 移除 MapBoundary + 修复 forest.tscn 边界

**Files:**
- Delete: `scripts/shared/map_boundary.gd`
- Delete: `scenes/shared/map_boundary.tscn`
- Modify: `scenes/levels/maps/forest.tscn`（移除 MapBoundary 引用，添加 BORDER tile 碰撞）

注意：forest.tscn（手绘地图）目前依赖 MapBoundary 做边界碰撞。移除后需要给 forest.tscn 的 Border TileMapLayer 配置 Solid(3) 碰撞层，或者改为也使用 generator_config（推荐后者，如果 forest 也转为随机生成则无需额外处理）。

- [ ] **Step 1: 给 forest.tscn 的 Border TileMapLayer 添加 Solid 碰撞**

forest.tscn 已有 Border TileMapLayer，需要确保其 tile 在 TileSet 中配置了 physics layer 0（Solid 层 3）。在 TileSet 编辑器中为边界 tile 添加碰撞形状。

- [ ] **Step 2: 从 forest.tscn 移除 MapBoundary 节点引用**

在 `scenes/levels/maps/forest.tscn` 中删除 MapBoundary 实例节点。

- [ ] **Step 3: 删除 MapBoundary 文件**

```bash
git rm scripts/shared/map_boundary.gd scenes/shared/map_boundary.tscn
```

- [ ] **Step 4: 搜索其他引用确保无遗漏**

搜索 `map_boundary` 或 `MapBoundary` 的引用，确保没有其他文件依赖它。

- [ ] **Step 5: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: All PASS

- [ ] **Step 6: 提交**

```bash
git add -A
git commit -m "chore: 移除 MapBoundary，forest.tscn 改用 tile 碰撞做边界"
```

---

### Task 12: Prefab 数据文件 + 默认生成配置

**Files:**
- Create: `resources/maps/prefabs/wall_l.tres`
- Create: `resources/maps/prefabs/wall_cross.tres`
- Create: `resources/maps/prefabs/wall_line.tres`
- Create: `resources/maps/prefabs/abyss_river.tres`
- Create: `resources/maps/prefabs/abyss_island.tres`
- Create: `resources/maps/prefabs/abyss_pool.tres`
- Create: `resources/maps/default_generator_config.tres`

- [ ] **Step 1: 创建 6 个 Prefab .tres 文件**

每个 Prefab 定义 cells 形状：

**wall_l.tres** — L 型墙壁：
```
cells: [(0,0), (1,0), (0,1), (0,2), (1,2)]  # 5 格 L 型
cell_type: WALL
rotatable: true
```

**wall_cross.tres** — 十字型墙壁：
```
cells: [(0,-1), (-1,0), (0,0), (1,0), (0,1)]  # 5 格十字
cell_type: WALL
rotatable: false
```

**wall_line.tres** — 直线墙壁：
```
cells: [(0,0), (0,1), (0,2), (0,3)]  # 4 格直线
cell_type: WALL
rotatable: true
```

**abyss_river.tres** — 河流：
```
cells: [(0,0), (0,1), (0,2), (0,3), (0,4), (0,5)]  # 6 格长条
cell_type: ABYSS
rotatable: true
```

**abyss_island.tres** — 孤岛：
```
cells: [(0,0), (1,0), (-1,1), (0,1), (1,1), (0,2)]  # 6 格不规则
cell_type: ABYSS
rotatable: true
```

**abyss_pool.tres** — 水池：
```
cells: [(0,0), (1,0), (0,1), (1,1)]  # 4 格方块
cell_type: ABYSS
rotatable: false
```

- [ ] **Step 2: 创建 default_generator_config.tres**

配置各项参数，`prefabs` 数组引用上述 6 个 Prefab。`tile_atlas_coords` 需要根据实际 TileSet 填入（暂时用占位值，待用户提供素材后更新）。

- [ ] **Step 3: 提交**

```bash
git add resources/maps/prefabs/ resources/maps/default_generator_config.tres
git commit -m "feat: 添加 6 个 Prefab 数据文件和默认生成配置"
```

---

### Task 13: GameConfig 加载 Prefab + MapData 配置

**Files:**
- Modify: `scripts/core/game_config.gd`
- Modify: `resources/maps/forest.tres`（或新建一个随机地图的 MapData）

- [ ] **Step 1: GameConfig 中加载 prefab 资源**

在 `scripts/core/game_config.gd` 中新增 prefab 加载（参照现有 `_load_resources_from_dir` 模式）：

```gdscript
var prefabs: Dictionary = {}  # {id: MapPrefab}

# 在 _ready() 中调用
_load_resources_from_dir("res://resources/maps/prefabs/", prefabs)
```

- [ ] **Step 2: 更新 MapData 配置**

为随机地图创建新的 MapData .tres 或更新现有的，将 `map_scene` 指向 `generated_map.tscn`，`generator_config` 指向 `default_generator_config.tres`。

- [ ] **Step 3: 提交**

```bash
git add scripts/core/game_config.gd resources/maps/
git commit -m "feat: GameConfig 加载 Prefab，配置随机地图 MapData"
```

---

### Task 14: 全量集成测试

**Files:**
- Test: `tests/unit/test_map_generator.gd`（补充）
- Test: `tests/unit/test_map_layout.gd`（补充）

- [ ] **Step 1: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: All PASS

- [ ] **Step 2: 修复任何失败的测试**

如有因可玩区常量变更（41→40, 28→24）导致的测试失败，更新对应断言值。

- [ ] **Step 3: 在 Godot 编辑器中运行游戏验证**

通过 MCP 工具 `play_scene` 运行主场景，检查：
- 地图正常生成和渲染
- 玩家在中心区
- 敌人从刷怪点生成
- 塔只能放在战术区地面上
- 投射物碰到实体墙销毁
- 深渊区域阻挡移动但投射物飞过

- [ ] **Step 4: 提交最终修复**

```bash
git add -A
git commit -m "test: 全量集成测试通过，修复常量变更相关断言"
```
