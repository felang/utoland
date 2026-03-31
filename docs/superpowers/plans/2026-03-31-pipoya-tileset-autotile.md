# Pipoya Tileset Autotile 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 Pipoya RPG Tileset type3 的 47-tile blob autotile 替换当前 luminara 单 tile 渲染，实现地形边缘自动平滑过渡。

**Architecture:** 新建 TerrainAutotiler 辅助类处理 8-bit bitmask 计算和查找表映射。改造 MapGenerator.apply_to_tilemap() 调用 autotiler 获取正确的 atlas 坐标。新建 TileSet 资源引用 Pipoya type3 图片。

**Tech Stack:** Godot 4.6 GDScript, TileMapLayer, TileSet, GUT 测试框架

**Spec:** `docs/superpowers/specs/2026-03-31-pipoya-tileset-autotile-design.md`

---

## 文件结构

| 操作 | 文件路径 | 职责 |
|---|---|---|
| 新建 | `scripts/systems/terrain_autotiler.gd` | Bitmask 计算 + 查找表映射 |
| 新建 | `tests/unit/test_terrain_autotiler.gd` | TerrainAutotiler 单元测试 |
| 新建 | `resources/maps/tilesets/pipoya_generated_tileset.tres` | Pipoya type3 TileSet 资源 |
| 改动 | `scripts/systems/map_generator.gd` | apply_to_tilemap() 改用 autotiler |
| 改动 | `scenes/levels/maps/generated_map.tscn` | TileSet 引用换为 pipoya |

---

### Task 1: TerrainAutotiler — bitmask 计算

**Files:**
- Create: `scripts/systems/terrain_autotiler.gd`
- Create: `tests/unit/test_terrain_autotiler.gd`

- [ ] **Step 1: 写 bitmask 计算的失败测试**

```gdscript
# tests/unit/test_terrain_autotiler.gd
extends GutTest

## TerrainAutotiler 单元测试


func _make_layout_with_cell(pos: Vector2i, cell_type: int) -> MapLayout:
	## 创建一个全 GROUND 的 layout，在指定位置设置指定类型
	var layout := MapLayout.new()
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		for x in range(MapLayout.PLAYABLE_WIDTH):
			layout.set_cell(Vector2i(x, y), MapLayout.CellType.GROUND)
	layout.set_cell(pos, cell_type as MapLayout.CellType)
	return layout


func _make_layout_filled(cell_type: int) -> MapLayout:
	## 创建一个全部填充指定类型的 layout
	var layout := MapLayout.new()
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		for x in range(MapLayout.PLAYABLE_WIDTH):
			layout.set_cell(Vector2i(x, y), cell_type as MapLayout.CellType)
	return layout


func test_isolated_cell_bitmask_is_zero():
	## 孤立 WALL cell 四周全是 GROUND，bitmask 应为 0
	var layout := _make_layout_with_cell(Vector2i(10, 10), MapLayout.CellType.WALL)
	var bitmask := TerrainAutotiler.compute_bitmask(layout, Vector2i(10, 10), MapLayout.CellType.WALL)
	assert_eq(bitmask, 0, "孤立 cell bitmask 应为 0")


func test_fully_surrounded_bitmask_is_255():
	## 全部填充同类型，中心 cell 的 bitmask 应为 255
	var layout := _make_layout_filled(MapLayout.CellType.WALL)
	var bitmask := TerrainAutotiler.compute_bitmask(layout, Vector2i(10, 10), MapLayout.CellType.WALL)
	assert_eq(bitmask, 255, "全包围 bitmask 应为 255")


func test_north_neighbor_only():
	## 仅北方有同类型邻居
	var layout := _make_layout_with_cell(Vector2i(10, 10), MapLayout.CellType.WALL)
	layout.set_cell(Vector2i(10, 9), MapLayout.CellType.WALL)
	var bitmask := TerrainAutotiler.compute_bitmask(layout, Vector2i(10, 10), MapLayout.CellType.WALL)
	assert_eq(bitmask, 1, "仅 N 邻居 bitmask 应为 1")


func test_east_neighbor_only():
	var layout := _make_layout_with_cell(Vector2i(10, 10), MapLayout.CellType.WALL)
	layout.set_cell(Vector2i(11, 10), MapLayout.CellType.WALL)
	var bitmask := TerrainAutotiler.compute_bitmask(layout, Vector2i(10, 10), MapLayout.CellType.WALL)
	assert_eq(bitmask, 4, "仅 E 邻居 bitmask 应为 4")


func test_corner_masking_ne_without_both_edges():
	## NE 角落有同类型，但 N 或 E 缺失时 NE 应被 mask 掉
	var layout := _make_layout_with_cell(Vector2i(10, 10), MapLayout.CellType.WALL)
	layout.set_cell(Vector2i(11, 9), MapLayout.CellType.WALL)  # NE
	layout.set_cell(Vector2i(10, 9), MapLayout.CellType.WALL)  # N
	# E 缺失，NE 应被 mask 掉
	var bitmask := TerrainAutotiler.compute_bitmask(layout, Vector2i(10, 10), MapLayout.CellType.WALL)
	assert_eq(bitmask, 1, "NE 被 mask，只剩 N=1")


func test_corner_masking_ne_with_both_edges():
	## NE 角落有同类型，且 N 和 E 都有时，NE 应保留
	var layout := _make_layout_with_cell(Vector2i(10, 10), MapLayout.CellType.WALL)
	layout.set_cell(Vector2i(10, 9), MapLayout.CellType.WALL)  # N
	layout.set_cell(Vector2i(11, 9), MapLayout.CellType.WALL)  # NE
	layout.set_cell(Vector2i(11, 10), MapLayout.CellType.WALL) # E
	var bitmask := TerrainAutotiler.compute_bitmask(layout, Vector2i(10, 10), MapLayout.CellType.WALL)
	assert_eq(bitmask, 1 + 2 + 4, "N+NE+E = 7")


func test_spawn_zone_treated_as_non_same_type():
	## SPAWN_ZONE 不是 WALL 的同类型
	var layout := _make_layout_with_cell(Vector2i(10, 10), MapLayout.CellType.WALL)
	layout.set_cell(Vector2i(10, 9), MapLayout.CellType.SPAWN_ZONE)
	var bitmask := TerrainAutotiler.compute_bitmask(layout, Vector2i(10, 10), MapLayout.CellType.WALL)
	assert_eq(bitmask, 0, "SPAWN_ZONE 不是 WALL 的同类型")


func test_abyss_bitmask_independent_from_wall():
	## ABYSS 和 WALL 互不视为同类型
	var layout := _make_layout_with_cell(Vector2i(10, 10), MapLayout.CellType.ABYSS)
	layout.set_cell(Vector2i(10, 9), MapLayout.CellType.WALL)   # N 是 WALL
	layout.set_cell(Vector2i(10, 11), MapLayout.CellType.ABYSS) # S 是 ABYSS
	var bitmask := TerrainAutotiler.compute_bitmask(layout, Vector2i(10, 10), MapLayout.CellType.ABYSS)
	assert_eq(bitmask, 16, "WALL 邻居不算 ABYSS 同类型，只有 S=16")


func test_border_at_edge_sees_border_outside():
	## 可玩区边缘的 BORDER cell，边界外 get_cell 返回 BORDER（同类型）
	var layout := MapLayout.new()
	# 默认 _fill 后 (0,0) 是 GROUND，手动设为 BORDER
	layout.set_cell(Vector2i(0, 0), MapLayout.CellType.BORDER)
	layout.set_cell(Vector2i(1, 0), MapLayout.CellType.BORDER)
	layout.set_cell(Vector2i(0, 1), MapLayout.CellType.BORDER)
	var bitmask := TerrainAutotiler.compute_bitmask(layout, Vector2i(0, 0), MapLayout.CellType.BORDER)
	# 边界外的 N(-1), W(-1), NW(-1,-1) 都返回 BORDER（同类型）
	# 实际邻居：N=BORDER(外), NE=BORDER(外,但E=BORDER所以NE保留?), E=BORDER(1,0), SE=?, S=BORDER(0,1), SW=?, W=BORDER(外), NW=BORDER(外)
	# N=1, E=4, S=16, W=64 都是 BORDER（同类型）
	# NE: N+E都同类型 → check (1,-1) = BORDER(外) → NE=2
	# SE: S+E都同类型 → check (1,1) = GROUND → SE 不同类型 → 0
	# SW: S+W都同类型 → check (-1,1) = BORDER(外) → SW=32
	# NW: N+W都同类型 → check (-1,-1) = BORDER(外) → NW=128
	assert_eq(bitmask, 1 + 2 + 4 + 16 + 32 + 64 + 128, "边缘 BORDER 应看到边界外为同类型 (缺SE)")
	# = 247
```

- [ ] **Step 2: 运行测试确认失败**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_terrain_autotiler.gd
```

预期：FAIL — `TerrainAutotiler` 类不存在

- [ ] **Step 3: 实现 TerrainAutotiler**

```gdscript
# scripts/systems/terrain_autotiler.gd
class_name TerrainAutotiler
extends RefCounted

## 地形 autotile 辅助类
## 根据 MapLayout 中 cell 的邻居关系计算 8-bit bitmask，
## 通过查找表映射到 Pipoya RPG Tileset type3 (8x6) 的 atlas 坐标。

# 方向偏移 + 对应 bit 值
const N := 1
const NE := 2
const E := 4
const SE := 8
const S := 16
const SW := 32
const W := 64
const NW := 128

const _NEIGHBOR_OFFSETS: Array[Dictionary] = [
	{"offset": Vector2i(0, -1), "bit": N},    # 北
	{"offset": Vector2i(1, -1), "bit": NE},   # 东北
	{"offset": Vector2i(1, 0), "bit": E},     # 东
	{"offset": Vector2i(1, 1), "bit": SE},    # 东南
	{"offset": Vector2i(0, 1), "bit": S},     # 南
	{"offset": Vector2i(-1, 1), "bit": SW},   # 西南
	{"offset": Vector2i(-1, 0), "bit": W},    # 西
	{"offset": Vector2i(-1, -1), "bit": NW},  # 西北
]

## bitmask → type3 atlas 坐标 (47 条)
## 左块 (cols 0-3, rows 0-3): 仅边，无角
## 右块: 带角过渡
## 注意：右块映射基于标准 RPG Maker A2 排布推导，可能需要对照实际图片微调
const BITMASK_TO_ATLAS: Dictionary = {
	# === 左块: 仅边 (16 tiles) ===
	0: Vector2i(0, 0),     # 孤立
	4: Vector2i(1, 0),     # E
	68: Vector2i(2, 0),    # E+W
	64: Vector2i(3, 0),    # W
	16: Vector2i(0, 1),    # S
	20: Vector2i(1, 1),    # E+S
	84: Vector2i(2, 1),    # E+S+W
	80: Vector2i(3, 1),    # S+W
	17: Vector2i(0, 2),    # N+S
	21: Vector2i(1, 2),    # N+E+S
	85: Vector2i(2, 2),    # N+E+S+W（十字，无角）
	81: Vector2i(3, 2),    # N+S+W
	1: Vector2i(0, 3),     # N
	5: Vector2i(1, 3),     # N+E
	69: Vector2i(2, 3),    # N+E+W
	65: Vector2i(3, 3),    # N+W
	# === 右块 rows 0-3 cols 4-6: 3边+角 ===
	# 缺N (base=E+S+W=84)
	92: Vector2i(4, 0),    # +SE
	124: Vector2i(5, 0),   # +SE+SW
	116: Vector2i(6, 0),   # +SW
	# 缺E (base=N+S+W=81)
	113: Vector2i(4, 1),   # +SW
	241: Vector2i(5, 1),   # +SW+NW
	209: Vector2i(6, 1),   # +NW
	# 缺S (base=N+E+W=69)
	197: Vector2i(4, 2),   # +NW
	199: Vector2i(5, 2),   # +NW+NE
	71: Vector2i(6, 2),    # +NE
	# 缺W (base=N+E+S=21)
	23: Vector2i(4, 3),    # +NE
	31: Vector2i(5, 3),    # +NE+SE
	29: Vector2i(6, 3),    # +SE
	# === col 7 rows 0-3: 2邻边+角 / 全填充 ===
	255: Vector2i(7, 0),   # 全填充
	28: Vector2i(7, 1),    # E+S+SE
	7: Vector2i(7, 2),     # N+E+NE
	112: Vector2i(7, 3),   # S+W+SW
	# === rows 4-5: 4边+角变化 (base=N+E+S+W=85) ===
	# 缺1角
	253: Vector2i(0, 4),   # 缺NE (SE+SW+NW)
	247: Vector2i(1, 4),   # 缺SE (NE+SW+NW)
	223: Vector2i(2, 4),   # 缺SW (NE+SE+NW)
	127: Vector2i(3, 4),   # 缺NW (NE+SE+SW)
	# 2邻角
	245: Vector2i(4, 4),   # SW+NW
	215: Vector2i(5, 4),   # NE+NW
	95: Vector2i(6, 4),    # NE+SE
	125: Vector2i(7, 4),   # SE+SW
	# 1角
	213: Vector2i(0, 5),   # NW
	87: Vector2i(1, 5),    # NE
	93: Vector2i(2, 5),    # SE
	117: Vector2i(3, 5),   # SW
	# 2对角
	221: Vector2i(4, 5),   # NW+SE
	119: Vector2i(5, 5),   # NE+SW
	# 2邻边+角 (补充)
	193: Vector2i(6, 5),   # W+N+NW
}


static func get_atlas_coord(layout: MapLayout, pos: Vector2i, cell_type: int) -> Vector2i:
	## 计算指定位置的 atlas 坐标
	var bitmask := compute_bitmask(layout, pos, cell_type)
	if BITMASK_TO_ATLAS.has(bitmask):
		return BITMASK_TO_ATLAS[bitmask]
	return Vector2i(0, 0)  # fallback 到孤立块


static func compute_bitmask(layout: MapLayout, pos: Vector2i, cell_type: int) -> int:
	## 计算 8-neighbor bitmask + corner masking
	var mask := 0
	for neighbor in _NEIGHBOR_OFFSETS:
		var neighbor_pos: Vector2i = pos + neighbor["offset"]
		if layout.get_cell(neighbor_pos) == cell_type:
			mask |= neighbor["bit"] as int
	# Corner masking: 角落位仅在两个相邻边都是同类型时才保留
	if not (mask & N and mask & E):
		mask &= ~NE
	if not (mask & E and mask & S):
		mask &= ~SE
	if not (mask & S and mask & W):
		mask &= ~SW
	if not (mask & W and mask & N):
		mask &= ~NW
	return mask
```

- [ ] **Step 4: 注册 class_name 到 global_script_class_cache**

在 `.godot/global_script_class_cache.cfg` 的 `list=[...]` 数组中追加条目（headless 测试需要）。格式参考现有条目（如 MapGenerator）：

```
, {
"base": &"RefCounted",
"class": &"TerrainAutotiler",
"icon": "",
"is_abstract": false,
"is_tool": false,
"language": &"GDScript",
"path": "res://scripts/systems/terrain_autotiler.gd"
}
```

在数组最后一个 `}` 之前插入此条目（注意前面的逗号）。查看现有格式：`grep -A8 "MapGenerator" .godot/global_script_class_cache.cfg`

- [ ] **Step 5: 运行测试确认通过**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_terrain_autotiler.gd
```

预期：全部 PASS

- [ ] **Step 6: 提交**

```bash
git add scripts/systems/terrain_autotiler.gd tests/unit/test_terrain_autotiler.gd
git commit -m "feat: 新增 TerrainAutotiler bitmask 计算和查找表"
```

---

### Task 2: 创建 Pipoya TileSet 资源

**Files:**
- Create: `resources/maps/tilesets/pipoya_generated_tileset.tres`

需要通过 Godot 编辑器或 MCP editor script 创建 TileSet 资源，因为 .tres 格式包含复杂的 atlas 配置和物理层碰撞数据，手写不现实。

- [ ] **Step 1: 用 MCP execute_editor_script 创建 TileSet**

通过 `mcp__gdai-mcp__execute_editor_script` 执行以下编辑器脚本：

```gdscript
# 创建 TileSet 资源，配置 4 个 atlas source + 物理碰撞层
var tileset := TileSet.new()
tileset.tile_size = Vector2i(32, 32)

# 添加 2 个物理层
# 层 0: Solid (collision_layer=4, bit 2 = Layer 3)
tileset.add_physics_layer()
tileset.set_physics_layer_collision_layer(0, 4)  # Layer 3 (Solid)
tileset.set_physics_layer_collision_mask(0, 0)

# 层 1: WallBlock (collision_layer=256, bit 8 = Layer 9)
tileset.add_physics_layer()
tileset.set_physics_layer_collision_layer(1, 256)  # Layer 9 (WallBlock)
tileset.set_physics_layer_collision_mask(1, 0)

# Source 0: Grass (Ground 满铺)
var grass_tex := load("res://assets/tilesets/Pipoya RPG Tileset 32x32/[A]_type3/[A]Grass1_pipo.png")
var grass_source := TileSetAtlasSource.new()
grass_source.texture = grass_tex
grass_source.texture_region_size = Vector2i(32, 32)
# 创建 8x6 的 tile grid
for y in range(6):
	for x in range(8):
		grass_source.create_tile(Vector2i(x, y))
tileset.add_source(grass_source, 0)

# Source 1: Dirt (Border) — 需要 Solid 碰撞
var dirt_tex := load("res://assets/tilesets/Pipoya RPG Tileset 32x32/[A]_type3/[A]Dirt1_pipo.png")
var dirt_source := TileSetAtlasSource.new()
dirt_source.texture = dirt_tex
dirt_source.texture_region_size = Vector2i(32, 32)
for y in range(6):
	for x in range(8):
		dirt_source.create_tile(Vector2i(x, y))
		# 物理层 0 (Solid): 32x32 全覆盖矩形
		var tile_data := dirt_source.get_tile_data(Vector2i(x, y), 0)
		var collision_polygon := PackedVector2Array([
			Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)
		])
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, collision_polygon)
tileset.add_source(dirt_source, 1)

# Source 2: Wall — 需要 Solid + WallBlock 碰撞
var wall_tex := load("res://assets/tilesets/Pipoya RPG Tileset 32x32/[A]_type3/[A]Wall-Up1_pipo.png")
var wall_source := TileSetAtlasSource.new()
wall_source.texture = wall_tex
wall_source.texture_region_size = Vector2i(32, 32)
for y in range(6):
	for x in range(8):
		wall_source.create_tile(Vector2i(x, y))
		var tile_data := wall_source.get_tile_data(Vector2i(x, y), 0)
		var collision_polygon := PackedVector2Array([
			Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)
		])
		# 物理层 0 (Solid)
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, collision_polygon)
		# 物理层 1 (WallBlock)
		tile_data.add_collision_polygon(1)
		tile_data.set_collision_polygon_points(1, 0, collision_polygon)
tileset.add_source(wall_source, 2)

# Source 3: Water (Abyss) — 需要 Solid 碰撞
var water_tex := load("res://assets/tilesets/Pipoya RPG Tileset 32x32/[A]_type3/[A]Water1_pipo.png")
var water_source := TileSetAtlasSource.new()
water_source.texture = water_tex
water_source.texture_region_size = Vector2i(32, 32)
for y in range(6):
	for x in range(8):
		water_source.create_tile(Vector2i(x, y))
		var tile_data := water_source.get_tile_data(Vector2i(x, y), 0)
		var collision_polygon := PackedVector2Array([
			Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)
		])
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, collision_polygon)
tileset.add_source(water_source, 3)

# 保存
ResourceSaver.save(tileset, "res://resources/maps/tilesets/pipoya_generated_tileset.tres")
print("TileSet saved successfully")
```

- [ ] **Step 2: 验证 TileSet 文件已创建**

检查文件存在：`ls resources/maps/tilesets/pipoya_generated_tileset.tres`

- [ ] **Step 3: 提交**

```bash
git add resources/maps/tilesets/pipoya_generated_tileset.tres
git commit -m "feat: 新增 Pipoya type3 TileSet 资源（含碰撞配置）"
```

---

### Task 3: 改造 apply_to_tilemap()

**Files:**
- Modify: `scripts/systems/map_generator.gd:28-53` (apply_to_tilemap 方法)

- [ ] **Step 1: 写 apply_to_tilemap 的集成测试**

在现有 `tests/unit/test_map_generator.gd` 末尾追加测试方法。这些测试不需要真实的 TileMapLayer（无法在 headless 中创建），而是验证 TerrainAutotiler 与 MapLayout 配合的逻辑正确性：

```gdscript
# 追加到 tests/unit/test_map_generator.gd

func test_autotiler_returns_valid_coords_for_generated_layout():
	## 验证生成的地图中每个非 GROUND cell 都能得到有效的 atlas 坐标
	var cfg := _make_config_with_prefabs()
	var layout := generator.generate(cfg, 42)
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		for x in range(MapLayout.PLAYABLE_WIDTH):
			var pos := Vector2i(x, y)
			var cell := layout.get_cell(pos)
			if cell == MapLayout.CellType.GROUND or cell == MapLayout.CellType.SPAWN_ZONE:
				continue
			var coord := TerrainAutotiler.get_atlas_coord(layout, pos, cell)
			assert_true(coord.x >= 0 and coord.x < 8, "atlas x 应在 0-7 范围: pos=%s type=%d" % [pos, cell])
			assert_true(coord.y >= 0 and coord.y < 6, "atlas y 应在 0-5 范围: pos=%s type=%d" % [pos, cell])


func test_border_autotile_consistency():
	## 边界墙应全部返回有效坐标，且角落与直边不同
	var layout := generator.generate(config, 42)
	var corner_coord := TerrainAutotiler.get_atlas_coord(layout, Vector2i(0, 0), MapLayout.CellType.BORDER)
	var edge_coord := TerrainAutotiler.get_atlas_coord(layout, Vector2i(10, 0), MapLayout.CellType.BORDER)
	# 角落和直边应有不同的 atlas 坐标（不同的 tile 形状）
	assert_ne(corner_coord, edge_coord, "角落和直边应使用不同 tile")
```

- [ ] **Step 2: 运行测试确认通过**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_map_generator.gd
```

预期：新增测试 PASS

- [ ] **Step 3: 改造 apply_to_tilemap()**

替换 `scripts/systems/map_generator.gd` 的 `apply_to_tilemap()` 方法（第 28-53 行）：

```gdscript
func apply_to_tilemap(map_scene: Node, layout: MapLayout, _config: MapGeneratorConfig) -> void:
	var ground_layer: TileMapLayer = map_scene.get_node("Ground")
	var terrain_layer: TileMapLayer = map_scene.get_node("Terrain")

	# Grass1 满铺坐标（type3 网格中心 fill tile）
	var grass_src_id := 0
	var grass_tile := Vector2i(5, 1)

	# 地形 source ID
	var border_src_id := 1   # Dirt1
	var wall_src_id := 2     # Wall-Up1
	var abyss_src_id := 3    # Water1

	for gy in range(MapLayout.PLAYABLE_HEIGHT):
		for gx in range(MapLayout.PLAYABLE_WIDTH):
			var grid_pos := Vector2i(gx, gy)
			var tile_pos := Vector2i(MapLayout.PLAYABLE_ORIGIN_X + gx, MapLayout.PLAYABLE_ORIGIN_Y + gy)
			var cell := layout.get_cell(grid_pos)

			# Ground layer: 全部铺草地
			ground_layer.set_cell(tile_pos, grass_src_id, grass_tile)

			# Terrain layer: 非 GROUND/SPAWN_ZONE 叠加 autotile
			match cell:
				MapLayout.CellType.BORDER:
					var atlas := TerrainAutotiler.get_atlas_coord(layout, grid_pos, MapLayout.CellType.BORDER)
					terrain_layer.set_cell(tile_pos, border_src_id, atlas)
				MapLayout.CellType.WALL:
					var atlas := TerrainAutotiler.get_atlas_coord(layout, grid_pos, MapLayout.CellType.WALL)
					terrain_layer.set_cell(tile_pos, wall_src_id, atlas)
				MapLayout.CellType.ABYSS:
					var atlas := TerrainAutotiler.get_atlas_coord(layout, grid_pos, MapLayout.CellType.ABYSS)
					terrain_layer.set_cell(tile_pos, abyss_src_id, atlas)
```

- [ ] **Step 4: 运行所有 map 相关测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_map_generator.gd
```

预期：全部 PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/systems/map_generator.gd tests/unit/test_map_generator.gd
git commit -m "feat: apply_to_tilemap 改用 TerrainAutotiler autotile 渲染"
```

---

### Task 4: 更新 generated_map.tscn TileSet 引用

**Files:**
- Modify: `scenes/levels/maps/generated_map.tscn`

- [ ] **Step 1: 替换 TileSet 引用**

在 `scenes/levels/maps/generated_map.tscn` 中，将 TileSet 引用从 `luminara_terrace_tileset.tres` 替换为 `pipoya_generated_tileset.tres`。

修改 ext_resource 行：
```
# 旧:
[ext_resource type="TileSet" uid="uid://bx217yuq2c30x" path="res://resources/maps/tilesets/luminara_terrace_tileset.tres" id="1_lum"]

# 新:
[ext_resource type="TileSet" path="res://resources/maps/tilesets/pipoya_generated_tileset.tres" id="1_lum"]
```

注意：uid 需要去掉（让 Godot 自动生成新的），或者用 MCP `edit_file` 工具修改。

- [ ] **Step 2: 运行所有测试确认无回归**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

预期：全部 PASS

- [ ] **Step 3: 提交**

```bash
git add scenes/levels/maps/generated_map.tscn
git commit -m "feat: generated_map 使用 Pipoya TileSet"
```

---

### Task 5: 视觉验证与查找表校准

**Files:**
- Modify: `scripts/systems/terrain_autotiler.gd` (可能需要微调 BITMASK_TO_ATLAS)

- [ ] **Step 1: 在 Godot 中运行游戏**

通过 MCP `play_scene` 或 Godot 编辑器运行 main 场景，进入地图查看渲染效果。

- [ ] **Step 2: 检查渲染效果**

重点检查：
1. 草地底层是否正确满铺（无空白格）
2. 边界墙 (Dirt) 是否有平滑的边角过渡
3. 水域 (Water) 是否有正确的岸边过渡
4. Prefab 墙壁 (Wall) 是否有正确的边角

- [ ] **Step 3: 如有 tile 映射错误，调整 BITMASK_TO_ATLAS**

查找表中右块部分（角落 tile）基于标准 RPG Maker A2 排布推导，可能需要根据实际 Pipoya type3 图片微调个别条目。

调整方法：找到渲染异常的 cell → 计算其 bitmask → 对照 Pipoya 图片找正确的 atlas 坐标 → 更新查找表

- [ ] **Step 4: 如果 Grass 中心 tile 坐标不对，修正 `grass_tile`**

当前设为 `Vector2i(5, 1)`，如果不是纯色 fill tile，需要换成正确坐标。

- [ ] **Step 5: 提交最终调整**

```bash
git add scripts/systems/terrain_autotiler.gd scripts/systems/map_generator.gd
git commit -m "fix: 校准 autotile 查找表映射"
```
