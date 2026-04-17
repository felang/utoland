# #4 地图改造 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the random prefab-scatter map system with a zone-based skeleton+random-fill generator, simple colored-block renderer, and directional spawn point activation.

**Architecture:** New `MapGenerator` reads a `MapBlueprint` (zones with fixed walls + random fill rules) and outputs a `MapLayout` grid. `MapRenderer` draws colored blocks to a TileMapLayer and creates StaticBody2D colliders. `EnemySpawner` receives 4 directional spawn points and activates 2→3→4 per wave.

**Tech Stack:** Godot 4.6 GDScript, GUT test framework

**Spec:** `docs/superpowers/specs/2026-04-17-map-renovation-design.md`

**Test command (all):** `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

**Test command (single file):** `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/<file>.gd -gexit`

---

### Task 1: Delete old map generation system

Remove the entire old random-prefab map generation system. The old `MapLayout` and `MapGenerator` files will be overwritten in later tasks (same paths, new content), so we only truly delete files that won't be recreated.

**Files:**
- Delete: `scripts/systems/terrain_autotiler.gd`
- Delete: `scripts/resources/map_generator_config.gd`
- Delete: `scripts/resources/map_prefab.gd`
- Delete: `resources/maps/default_generator_config.tres`
- Delete: `resources/maps/prefabs/` (entire directory — 8 .tres files)
- Delete: `resources/maps/templates/` (entire directory — 8 .tres files)
- Delete: `resources/maps/tilesets/pipoya_tileset.tres`
- Delete: `resources/maps/tilesets/pipoya_generated_tileset.tres`
- Delete: `scenes/levels/maps/generated_map.tscn`
- Delete: `tests/unit/test_map_generator.gd` (will be rewritten in Task 4)
- Delete: `tests/unit/test_map_layout.gd` (will be rewritten in Task 2)

- [ ] **Step 1: Delete files**

```bash
rm scripts/systems/terrain_autotiler.gd
rm scripts/resources/map_generator_config.gd
rm scripts/resources/map_prefab.gd
rm resources/maps/default_generator_config.tres
rm -rf resources/maps/prefabs/
rm -rf resources/maps/templates/
rm resources/maps/tilesets/pipoya_tileset.tres
rm resources/maps/tilesets/pipoya_generated_tileset.tres
rm scenes/levels/maps/generated_map.tscn
rm tests/unit/test_map_generator.gd
rm tests/unit/test_map_layout.gd
```

Also delete any `.uid` files associated with the deleted scripts:
```bash
find . -name "*.uid" | xargs grep -l "terrain_autotiler\|map_generator_config\|map_prefab" | xargs rm -f 2>/dev/null
```

- [ ] **Step 2: Update `scripts/core/game_config.gd` — remove prefabs loading**

Remove the `prefabs` dictionary and its loading line.

In `scripts/core/game_config.gd`, delete:
```gdscript
var prefabs: Dictionary = {}  # {id: MapPrefab}
```

And in `_ready()`, delete:
```gdscript
	_load_resources_from_dir("res://resources/maps/prefabs/", prefabs)
```

- [ ] **Step 3: Update `.godot/global_script_class_cache.cfg`**

Remove entries for deleted classes: `TerrainAutotiler`, `MapGeneratorConfig`, `MapPrefab`.

Open `.godot/global_script_class_cache.cfg` and remove the dictionary entries where `"class"` is `&"TerrainAutotiler"`, `&"MapGeneratorConfig"`, or `&"MapPrefab"`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor(#4): 删除旧随机地图生成系统(Prefab/Autotiler/Generator Config)"
```

---

### Task 2: New MapLayout data structure (TDD)

Create the new `MapLayout` class with a simple 2-type grid and coordinate conversion.

**Files:**
- Overwrite: `scripts/core/map_layout.gd`
- Create: `tests/unit/test_map_layout.gd`

- [ ] **Step 1: Write failing tests**

Create `tests/unit/test_map_layout.gd`:

```gdscript
extends GutTest

var layout: MapLayout

func before_each() -> void:
	layout = MapLayout.new()
	layout.grid_width = 40
	layout.grid_height = 24
	layout.player_spawn = Vector2i(19, 12)
	layout.spawn_points = {
		"north": Vector2i(20, 0),
		"south": Vector2i(20, 23),
		"east": Vector2i(39, 12),
		"west": Vector2i(0, 12),
	}
	layout.init_grid()

func test_grid_dimensions() -> void:
	assert_eq(layout.grid.size(), 24, "grid should have 24 rows")
	assert_eq(layout.grid[0].size(), 40, "grid should have 40 columns")

func test_default_cells_are_ground() -> void:
	assert_eq(layout.grid[0][0], MapLayout.CellType.GROUND)
	assert_eq(layout.grid[12][20], MapLayout.CellType.GROUND)

func test_set_and_get_cell() -> void:
	layout.set_cell(Vector2i(5, 3), MapLayout.CellType.OBSTACLE)
	assert_eq(layout.get_cell(Vector2i(5, 3)), MapLayout.CellType.OBSTACLE)

func test_is_ground() -> void:
	assert_true(layout.is_ground(Vector2i(10, 10)))
	layout.set_cell(Vector2i(10, 10), MapLayout.CellType.OBSTACLE)
	assert_false(layout.is_ground(Vector2i(10, 10)))

func test_out_of_bounds_is_not_ground() -> void:
	assert_false(layout.is_ground(Vector2i(-1, 0)))
	assert_false(layout.is_ground(Vector2i(40, 0)))
	assert_false(layout.is_ground(Vector2i(0, 24)))

func test_is_placeable_on_ground() -> void:
	assert_true(layout.is_placeable(Vector2i(10, 10)))

func test_is_placeable_false_on_obstacle() -> void:
	layout.set_cell(Vector2i(10, 10), MapLayout.CellType.OBSTACLE)
	assert_false(layout.is_placeable(Vector2i(10, 10)))

func test_is_placeable_false_on_player_spawn() -> void:
	assert_false(layout.is_placeable(Vector2i(19, 12)))

func test_is_placeable_false_on_spawn_point() -> void:
	assert_false(layout.is_placeable(Vector2i(20, 0)))
	assert_false(layout.is_placeable(Vector2i(0, 12)))

func test_grid_to_world() -> void:
	# grid(0,0) => full_grid(3,3) => world = (3-22.5)*32+16, (3-15)*32+16 = (-608, -368)
	# Using GameConfig: PLAYABLE_ORIGIN_X=3, MAP_GRID_WIDTH=45, MAP_GRID_HEIGHT=30
	var world := layout.grid_to_world(Vector2i(0, 0))
	assert_almost_eq(world.x, -608.0, 0.1)
	assert_almost_eq(world.y, -368.0, 0.1)

func test_grid_to_world_center() -> void:
	# grid(19,12) => full_grid(22,15) => world = (22-22.5)*32+16, (15-15)*32+16 = (0, 16)
	var world := layout.grid_to_world(Vector2i(19, 12))
	assert_almost_eq(world.x, 0.0, 0.1)
	assert_almost_eq(world.y, 16.0, 0.1)

func test_world_to_grid() -> void:
	var grid_pos := layout.world_to_grid(Vector2(-608.0, -368.0))
	assert_eq(grid_pos, Vector2i(0, 0))

func test_world_to_grid_roundtrip() -> void:
	var original := Vector2i(15, 8)
	var world := layout.grid_to_world(original)
	var back := layout.world_to_grid(world)
	assert_eq(back, original)

func test_get_placeable_dict() -> void:
	layout.set_cell(Vector2i(5, 5), MapLayout.CellType.OBSTACLE)
	var dict := layout.get_placeable_dict()
	assert_true(dict.has(Vector2i(10, 10)))
	assert_false(dict.has(Vector2i(5, 5)))
	assert_false(dict.has(Vector2i(19, 12)))  # player spawn

func test_get_spawn_points_world() -> void:
	var world_points := layout.get_spawn_points_world()
	assert_eq(world_points.size(), 4)
	assert_true(world_points.has("north"))
	assert_true(world_points.has("south"))
	assert_true(world_points.has("east"))
	assert_true(world_points.has("west"))
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_map_layout.gd -gexit`

Expected: FAIL (MapLayout class doesn't have the new API yet)

- [ ] **Step 3: Implement MapLayout**

Overwrite `scripts/core/map_layout.gd`:

```gdscript
class_name MapLayout
extends RefCounted

enum CellType { GROUND, OBSTACLE }

var grid: Array = []
var spawn_points: Dictionary = {}
var player_spawn: Vector2i = Vector2i(19, 12)
var grid_width: int = 40
var grid_height: int = 24

func init_grid() -> void:
	grid.clear()
	for y in range(grid_height):
		var row: Array = []
		row.resize(grid_width)
		row.fill(CellType.GROUND)
		grid.append(row)

func get_cell(pos: Vector2i) -> int:
	if pos.x < 0 or pos.x >= grid_width or pos.y < 0 or pos.y >= grid_height:
		return CellType.OBSTACLE
	return grid[pos.y][pos.x]

func set_cell(pos: Vector2i, cell_type: int) -> void:
	if pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height:
		grid[pos.y][pos.x] = cell_type

func is_ground(pos: Vector2i) -> bool:
	return get_cell(pos) == CellType.GROUND

func is_placeable(pos: Vector2i) -> bool:
	if not is_ground(pos):
		return false
	if pos == player_spawn:
		return false
	for sp in spawn_points.values():
		if pos == sp:
			return false
	return true

func grid_to_world(pos: Vector2i) -> Vector2:
	var full_x := GameConfig.PLAYABLE_ORIGIN_X + pos.x
	var full_y := GameConfig.PLAYABLE_ORIGIN_Y + pos.y
	var world_x := (full_x - GameConfig.MAP_GRID_WIDTH / 2.0) * GameConfig.GRID_SIZE + GameConfig.GRID_SIZE / 2.0
	var world_y := (full_y - GameConfig.MAP_GRID_HEIGHT / 2.0) * GameConfig.GRID_SIZE + GameConfig.GRID_SIZE / 2.0
	return Vector2(world_x, world_y)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var gx := int(floor((world_pos.x + GameConfig.MAP_HALF_WIDTH) / GameConfig.GRID_SIZE)) - GameConfig.PLAYABLE_ORIGIN_X
	var gy := int(floor((world_pos.y + GameConfig.MAP_HALF_HEIGHT) / GameConfig.GRID_SIZE)) - GameConfig.PLAYABLE_ORIGIN_Y
	return Vector2i(gx, gy)

func get_placeable_dict() -> Dictionary:
	var dict := {}
	for y in range(grid_height):
		for x in range(grid_width):
			var pos := Vector2i(x, y)
			if is_placeable(pos):
				dict[pos] = true
	return dict

func get_spawn_points_world() -> Dictionary:
	var result := {}
	for dir in spawn_points:
		result[dir] = grid_to_world(spawn_points[dir])
	return result

func get_player_spawn_world() -> Vector2:
	return grid_to_world(player_spawn)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_map_layout.gd -gexit`

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/core/map_layout.gd tests/unit/test_map_layout.gd
git commit -m "feat(#4): 新 MapLayout — 40×24 网格 + GROUND/OBSTACLE 双类型 + 坐标转换"
```

---

### Task 3: ZoneData + MapBlueprint resources

Create the two new Resource classes for describing map blueprints.

**Files:**
- Create: `scripts/resources/zone_data.gd`
- Create: `scripts/resources/map_blueprint.gd`
- Modify: `scripts/resources/map_data.gd`

- [ ] **Step 1: Create ZoneData**

Create `scripts/resources/zone_data.gd`:

```gdscript
class_name ZoneData
extends Resource

@export var id: String = ""
@export var origin: Vector2i = Vector2i.ZERO
@export var size: Vector2i = Vector2i.ZERO
@export var fixed_walls: Array[Vector2i] = []
@export var fill_count: Vector2i = Vector2i.ZERO
@export var fill_margin: int = 1
```

- [ ] **Step 2: Create MapBlueprint**

Create `scripts/resources/map_blueprint.gd`:

```gdscript
class_name MapBlueprint
extends Resource

@export var id: String = ""
@export var grid_width: int = 40
@export var grid_height: int = 24
@export var zones: Array[ZoneData] = []
@export var spawn_points: Dictionary = {}
@export var player_spawn: Vector2i = Vector2i(19, 12)
@export var border_gap_size: int = 3
```

- [ ] **Step 3: Update MapData — replace generator_config with blueprint**

In `scripts/resources/map_data.gd`, replace:
```gdscript
@export var generator_config: MapGeneratorConfig = null  # null 表示手绘地图
```
with:
```gdscript
@export var blueprint: MapBlueprint = null  # null 表示手绘地图，有值走程序化生成
```

- [ ] **Step 4: Update `.godot/global_script_class_cache.cfg`**

Add entries for `ZoneData`, `MapBlueprint`. Format:
```
{
"base": &"Resource",
"class": &"ZoneData",
"icon": "",
"language": &"GDScript",
"path": "res://scripts/resources/zone_data.gd"
}
```
```
{
"base": &"Resource",
"class": &"MapBlueprint",
"icon": "",
"language": &"GDScript",
"path": "res://scripts/resources/map_blueprint.gd"
}
```

- [ ] **Step 5: Commit**

```bash
git add scripts/resources/zone_data.gd scripts/resources/map_blueprint.gd scripts/resources/map_data.gd .godot/global_script_class_cache.cfg
git commit -m "feat(#4): ZoneData + MapBlueprint 资源类 + MapData.blueprint 字段"
```

---

### Task 4: MapGenerator (TDD)

Implement the zone-based skeleton + random fill generator with BFS connectivity validation.

**Files:**
- Overwrite: `scripts/systems/map_generator.gd`
- Create: `tests/unit/test_map_generator.gd`

- [ ] **Step 1: Write failing tests**

Create `tests/unit/test_map_generator.gd`:

```gdscript
extends GutTest

var generator: MapGenerator
var blueprint: MapBlueprint

func before_each() -> void:
	generator = MapGenerator.new()
	blueprint = _create_test_blueprint()

func _create_test_blueprint() -> MapBlueprint:
	var bp := MapBlueprint.new()
	bp.id = "test"
	bp.grid_width = 40
	bp.grid_height = 24
	bp.player_spawn = Vector2i(19, 12)
	bp.spawn_points = {
		"north": Vector2i(20, 0),
		"south": Vector2i(20, 23),
		"east": Vector2i(39, 12),
		"west": Vector2i(0, 12),
	}
	bp.border_gap_size = 3

	# 简单的测试区域：一个 4×4 区域带固定墙
	var zone := ZoneData.new()
	zone.id = "test_zone"
	zone.origin = Vector2i(10, 10)
	zone.size = Vector2i(4, 4)
	zone.fixed_walls = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	zone.fill_count = Vector2i(0, 0)
	bp.zones = [zone]
	return bp

func test_grid_dimensions() -> void:
	var layout := generator.generate(blueprint)
	assert_eq(layout.grid_width, 40)
	assert_eq(layout.grid_height, 24)
	assert_eq(layout.grid.size(), 24)

func test_border_walls() -> void:
	var layout := generator.generate(blueprint)
	# 非刷新点位置的边界应是 OBSTACLE
	assert_eq(layout.get_cell(Vector2i(5, 0)), MapLayout.CellType.OBSTACLE, "top border")
	assert_eq(layout.get_cell(Vector2i(0, 5)), MapLayout.CellType.OBSTACLE, "left border")
	assert_eq(layout.get_cell(Vector2i(39, 5)), MapLayout.CellType.OBSTACLE, "right border")
	assert_eq(layout.get_cell(Vector2i(5, 23)), MapLayout.CellType.OBSTACLE, "bottom border")

func test_border_gaps_at_spawn_points() -> void:
	var layout := generator.generate(blueprint)
	# 北刷新点(20,0)附近应有缺口
	assert_eq(layout.get_cell(Vector2i(20, 0)), MapLayout.CellType.GROUND, "north spawn gap center")
	assert_eq(layout.get_cell(Vector2i(19, 0)), MapLayout.CellType.GROUND, "north spawn gap left")
	assert_eq(layout.get_cell(Vector2i(21, 0)), MapLayout.CellType.GROUND, "north spawn gap right")

func test_interior_is_ground() -> void:
	var layout := generator.generate(blueprint)
	assert_eq(layout.get_cell(Vector2i(15, 12)), MapLayout.CellType.GROUND, "interior cell")

func test_fixed_walls_placed() -> void:
	var layout := generator.generate(blueprint)
	# test_zone 固定墙在 origin(10,10) + offsets (0,0)(1,0)(2,0)(3,0)
	assert_eq(layout.get_cell(Vector2i(10, 10)), MapLayout.CellType.OBSTACLE)
	assert_eq(layout.get_cell(Vector2i(11, 10)), MapLayout.CellType.OBSTACLE)
	assert_eq(layout.get_cell(Vector2i(12, 10)), MapLayout.CellType.OBSTACLE)
	assert_eq(layout.get_cell(Vector2i(13, 10)), MapLayout.CellType.OBSTACLE)

func test_random_fill_count() -> void:
	var bp := _create_test_blueprint()
	bp.zones[0].fill_count = Vector2i(2, 4)
	bp.zones[0].fixed_walls = []
	var layout := generator.generate(bp)
	# 统计区域内 OBSTACLE 数量
	var count := 0
	for y in range(10, 14):
		for x in range(10, 14):
			if layout.get_cell(Vector2i(x, y)) == MapLayout.CellType.OBSTACLE:
				count += 1
	assert_gte(count, 2, "at least 2 random obstacles")
	assert_lte(count, 4, "at most 4 random obstacles")

func test_player_spawn_area_clear() -> void:
	var layout := generator.generate(blueprint)
	# 玩家出生点周围 3×3 应全部是 GROUND
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var pos := blueprint.player_spawn + Vector2i(dx, dy)
			assert_eq(layout.get_cell(pos), MapLayout.CellType.GROUND,
				"player spawn area (%d,%d) should be ground" % [pos.x, pos.y])

func test_connectivity() -> void:
	var layout := generator.generate(blueprint)
	# BFS 从玩家位置出发应能到达所有刷新点
	var visited := {}
	var queue: Array[Vector2i] = [layout.player_spawn]
	visited[layout.player_spawn] = true
	var dirs: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		for dir in dirs:
			var next: Vector2i = current + dir
			if visited.has(next):
				continue
			if layout.is_ground(next):
				visited[next] = true
				queue.append(next)
	for sp in layout.spawn_points.values():
		assert_true(visited.has(sp), "spawn point %s should be reachable" % str(sp))

func test_spawn_points_stored() -> void:
	var layout := generator.generate(blueprint)
	assert_eq(layout.spawn_points.size(), 4)
	assert_eq(layout.spawn_points["north"], Vector2i(20, 0))
	assert_eq(layout.player_spawn, Vector2i(19, 12))

func test_seed_reproducibility() -> void:
	var layout_a := generator.generate(blueprint, 42)
	var layout_b := generator.generate(blueprint, 42)
	for y in range(24):
		for x in range(40):
			assert_eq(layout_a.grid[y][x], layout_b.grid[y][x],
				"cell (%d,%d) should match with same seed" % [x, y])
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_map_generator.gd -gexit`

Expected: FAIL

- [ ] **Step 3: Implement MapGenerator**

Overwrite `scripts/systems/map_generator.gd`:

```gdscript
class_name MapGenerator
extends RefCounted

var _rng := RandomNumberGenerator.new()

func generate(blueprint: MapBlueprint, seed_value: int = -1) -> MapLayout:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

	var layout := MapLayout.new()
	layout.grid_width = blueprint.grid_width
	layout.grid_height = blueprint.grid_height
	layout.player_spawn = blueprint.player_spawn
	layout.spawn_points = blueprint.spawn_points.duplicate()
	layout.init_grid()

	_draw_border(layout, blueprint)
	_draw_skeletons(layout, blueprint)
	_random_fill(layout, blueprint)
	_ensure_connectivity(layout, blueprint)
	return layout

func _draw_border(layout: MapLayout, blueprint: MapBlueprint) -> void:
	var w := layout.grid_width
	var h := layout.grid_height
	var gap := blueprint.border_gap_size
	var half_gap := gap / 2

	for x in range(w):
		layout.set_cell(Vector2i(x, 0), MapLayout.CellType.OBSTACLE)
		layout.set_cell(Vector2i(x, h - 1), MapLayout.CellType.OBSTACLE)
	for y in range(h):
		layout.set_cell(Vector2i(0, y), MapLayout.CellType.OBSTACLE)
		layout.set_cell(Vector2i(w - 1, y), MapLayout.CellType.OBSTACLE)

	# 在刷新点位置开缺口
	for dir in blueprint.spawn_points:
		var sp: Vector2i = blueprint.spawn_points[dir]
		for offset in range(-half_gap, half_gap + 1):
			if dir == "north" or dir == "south":
				var gx := clampi(sp.x + offset, 0, w - 1)
				layout.set_cell(Vector2i(gx, sp.y), MapLayout.CellType.GROUND)
			else:
				var gy := clampi(sp.y + offset, 0, h - 1)
				layout.set_cell(Vector2i(sp.x, gy), MapLayout.CellType.GROUND)

func _draw_skeletons(layout: MapLayout, blueprint: MapBlueprint) -> void:
	for zone in blueprint.zones:
		for wall_offset in zone.fixed_walls:
			var pos := zone.origin + wall_offset
			layout.set_cell(pos, MapLayout.CellType.OBSTACLE)

func _random_fill(layout: MapLayout, blueprint: MapBlueprint) -> void:
	for zone in blueprint.zones:
		if zone.fill_count == Vector2i.ZERO:
			continue
		var count := _rng.randi_range(zone.fill_count.x, zone.fill_count.y)
		var placed := 0
		var attempts := 0
		var max_attempts := count * 10
		while placed < count and attempts < max_attempts:
			attempts += 1
			var rx := _rng.randi_range(0, zone.size.x - 1)
			var ry := _rng.randi_range(0, zone.size.y - 1)
			var pos := zone.origin + Vector2i(rx, ry)
			if not _can_place_fill(layout, pos, zone, blueprint):
				continue
			layout.set_cell(pos, MapLayout.CellType.OBSTACLE)
			placed += 1

func _can_place_fill(layout: MapLayout, pos: Vector2i, zone: ZoneData, blueprint: MapBlueprint) -> bool:
	if not layout.is_ground(pos):
		return false
	# 不能在玩家出生点周围 3×3
	if abs(pos.x - blueprint.player_spawn.x) <= 1 and abs(pos.y - blueprint.player_spawn.y) <= 1:
		return false
	# 不能在刷新点上
	for sp in blueprint.spawn_points.values():
		if pos == sp:
			return false
	# 距固定墙至少 fill_margin
	for wall_offset in zone.fixed_walls:
		var wall_pos := zone.origin + wall_offset
		if abs(pos.x - wall_pos.x) < zone.fill_margin and abs(pos.y - wall_pos.y) < zone.fill_margin:
			# 在 margin 内但不在固定墙上（已检查 is_ground）
			if zone.fill_margin > 0 and pos != wall_pos:
				var dist := absi(pos.x - wall_pos.x) + absi(pos.y - wall_pos.y)
				if dist < zone.fill_margin:
					return false
	return true

func _ensure_connectivity(layout: MapLayout, blueprint: MapBlueprint) -> void:
	if _is_connected(layout, blueprint):
		return
	# 移除所有随机填充并重试（退化为纯骨架）
	for zone in blueprint.zones:
		if zone.fill_count == Vector2i.ZERO:
			continue
		var fixed_set := {}
		for w in zone.fixed_walls:
			fixed_set[zone.origin + w] = true
		for y in range(zone.size.y):
			for x in range(zone.size.x):
				var pos := zone.origin + Vector2i(x, y)
				if layout.get_cell(pos) == MapLayout.CellType.OBSTACLE and not fixed_set.has(pos):
					layout.set_cell(pos, MapLayout.CellType.GROUND)

func _is_connected(layout: MapLayout, blueprint: MapBlueprint) -> bool:
	var visited := {}
	var queue: Array[Vector2i] = [blueprint.player_spawn]
	visited[blueprint.player_spawn] = true
	var dirs: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		for dir in dirs:
			var next: Vector2i = current + dir
			if visited.has(next):
				continue
			if layout.is_ground(next):
				visited[next] = true
				queue.append(next)
	for sp in blueprint.spawn_points.values():
		if not visited.has(sp):
			return false
	return true
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_map_generator.gd -gexit`

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/systems/map_generator.gd tests/unit/test_map_generator.gd
git commit -m "feat(#4): 新 MapGenerator — 骨架+随机填充+BFS 连通性验证"
```

---

### Task 5: MapRenderer

Implement the simple colored-block renderer and collision generator.

**Files:**
- Create: `scripts/systems/map_renderer.gd`

- [ ] **Step 1: Implement MapRenderer**

Create `scripts/systems/map_renderer.gd`:

```gdscript
class_name MapRenderer
extends RefCounted

const GROUND_COLOR := Color("#4a7c3f")
const OBSTACLE_COLOR := Color("#555555")
const SPAWN_MARKER_COLOR := Color("#cc3333")

func render(layout: MapLayout, tilemap: TileMapLayer) -> void:
	var tileset := _create_tileset()
	tilemap.tile_set = tileset
	for y in range(layout.grid_height):
		for x in range(layout.grid_width):
			var grid_pos := Vector2i(x, y)
			var tile_pos := Vector2i(GameConfig.PLAYABLE_ORIGIN_X + x, GameConfig.PLAYABLE_ORIGIN_Y + y)
			var cell := layout.get_cell(grid_pos)
			if cell == MapLayout.CellType.OBSTACLE:
				tilemap.set_cell(tile_pos, 0, Vector2i(1, 0))
			else:
				tilemap.set_cell(tile_pos, 0, Vector2i(0, 0))

func create_colliders(layout: MapLayout, parent: Node2D) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 4  # Layer 3 (Solid) = bitmask 4
	body.collision_mask = 0
	parent.add_child(body)
	for y in range(layout.grid_height):
		for x in range(layout.grid_width):
			if layout.get_cell(Vector2i(x, y)) == MapLayout.CellType.OBSTACLE:
				var shape := CollisionShape2D.new()
				var rect := RectangleShape2D.new()
				rect.size = Vector2(GameConfig.GRID_SIZE, GameConfig.GRID_SIZE)
				shape.shape = rect
				shape.position = layout.grid_to_world(Vector2i(x, y))
				body.add_child(shape)

func create_spawn_markers(layout: MapLayout, parent: Node2D) -> void:
	for dir in layout.spawn_points:
		var world_pos: Vector2 = layout.grid_to_world(layout.spawn_points[dir])
		var marker := Sprite2D.new()
		marker.name = "SpawnMarker_" + dir
		var img := Image.create(GameConfig.GRID_SIZE, GameConfig.GRID_SIZE, false, Image.FORMAT_RGBA8)
		img.fill(SPAWN_MARKER_COLOR)
		marker.texture = ImageTexture.create_from_image(img)
		marker.position = world_pos
		parent.add_child(marker)

func _create_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(GameConfig.GRID_SIZE, GameConfig.GRID_SIZE)
	var img := Image.create(GameConfig.GRID_SIZE * 2, GameConfig.GRID_SIZE, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, GameConfig.GRID_SIZE, GameConfig.GRID_SIZE), GROUND_COLOR)
	img.fill_rect(Rect2i(GameConfig.GRID_SIZE, 0, GameConfig.GRID_SIZE, GameConfig.GRID_SIZE), OBSTACLE_COLOR)
	var tex := ImageTexture.create_from_image(img)
	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(GameConfig.GRID_SIZE, GameConfig.GRID_SIZE)
	ts.add_source(source)
	return ts
```

- [ ] **Step 2: Update `.godot/global_script_class_cache.cfg`**

Add entry for `MapRenderer`:
```
{
"base": &"RefCounted",
"class": &"MapRenderer",
"icon": "",
"language": &"GDScript",
"path": "res://scripts/systems/map_renderer.gd"
}
```

- [ ] **Step 3: Commit**

```bash
git add scripts/systems/map_renderer.gd .godot/global_script_class_cache.cfg
git commit -m "feat(#4): MapRenderer — 纯色方块渲染 + StaticBody2D 碰撞生成"
```

---

### Task 6: Data files — zones, blueprint, scene

Create the actual zone `.tres` data files, forest blueprint, and update the map scene.

**Files:**
- Create: `resources/maps/zones/central_ruins.tres`
- Create: `resources/maps/zones/ne_corridor.tres`
- Create: `resources/maps/zones/south_rubble.tres`
- Create: `resources/maps/blueprints/forest_blueprint.tres`
- Create: `scenes/levels/maps/generated_map.tscn` (recreate)
- Modify: `resources/maps/forest.tres`

- [ ] **Step 1: Create zone data files**

Create `resources/maps/zones/central_ruins.tres`:

```
[gd_resource type="Resource" script_class="ZoneData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/zone_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "central_ruins"
origin = Vector2i(15, 9)
size = Vector2i(10, 6)
fixed_walls = Array[Vector2i]([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(8, 0), Vector2i(9, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(0, 5), Vector2i(9, 1), Vector2i(9, 4), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5)])
fill_count = Vector2i(1, 2)
fill_margin = 1
```

Wall layout (relative to origin):
```
x: 0  1  2  3  4  5  6  7  8  9
y0: W  W  W  W  W  W  W  W  W  W   (top)
y1: W  .  .  .  .  .  .  .  .  W   (left+right)
y2: W  .  .  .  .  .  .  .  .  .   (left, east opening)
y3: W  .  .  .  .  .  .  .  .  .   (left, east opening)
y4: W  .  .  .  .  .  .  .  .  W   (left+right)
y5: W  W  W  W  .  .  W  W  W  W   (bottom, south opening at x=4,5)
```

Create `resources/maps/zones/ne_corridor.tres`:

```
[gd_resource type="Resource" script_class="ZoneData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/zone_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "ne_corridor"
origin = Vector2i(12, 2)
size = Vector2i(8, 6)
fixed_walls = Array[Vector2i]([Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5), Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4), Vector2i(5, 5)])
fill_count = Vector2i(0, 1)
fill_margin = 1
```

Wall layout:
```
x: 0  1  2  3  4  5  6  7
   .  .  W  .  .  W  .  .    tower area | wall | passage(2) | wall | tower area
```

Create `resources/maps/zones/south_rubble.tres`:

```
[gd_resource type="Resource" script_class="ZoneData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/zone_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "south_rubble"
origin = Vector2i(10, 17)
size = Vector2i(20, 6)
fixed_walls = Array[Vector2i]([])
fill_count = Vector2i(8, 15)
fill_margin = 1
```

- [ ] **Step 2: Create forest blueprint**

Create `resources/maps/blueprints/forest_blueprint.tres`:

```
[gd_resource type="Resource" script_class="MapBlueprint" load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/resources/map_blueprint.gd" id="1"]
[ext_resource type="Resource" path="res://resources/maps/zones/central_ruins.tres" id="2"]
[ext_resource type="Resource" path="res://resources/maps/zones/ne_corridor.tres" id="3"]
[ext_resource type="Resource" path="res://resources/maps/zones/south_rubble.tres" id="4"]

[resource]
script = ExtResource("1")
id = "forest"
grid_width = 40
grid_height = 24
zones = [ExtResource("2"), ExtResource("3"), ExtResource("4")]
spawn_points = { "north": Vector2i(20, 0), "south": Vector2i(20, 23), "east": Vector2i(39, 12), "west": Vector2i(0, 12) }
player_spawn = Vector2i(19, 12)
border_gap_size = 3
```

- [ ] **Step 3: Create generated_map.tscn**

Create `scenes/levels/maps/generated_map.tscn`:

```
[gd_scene format=3]

[node name="MapRoot" type="Node2D"]

[node name="Ground" type="TileMapLayer" parent="."]

[node name="SpawnMarkers" type="Node2D" parent="."]

[node name="Colliders" type="Node2D" parent="."]

[node name="PickupLayer" type="Node2D" parent="."]

[node name="EntityLayer" type="Node2D" parent="."]
y_sort_enabled = true
z_index = 1

[node name="ProjectileLayer" type="Node2D" parent="."]
z_index = 2
```

- [ ] **Step 4: Update forest.tres**

Replace the entire content of `resources/maps/forest.tres`:

```
[gd_resource type="Resource" script_class="MapData" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/resources/map_data.gd" id="1"]
[ext_resource type="Resource" path="res://resources/maps/blueprints/forest_blueprint.tres" id="2"]

[resource]
script = ExtResource("1")
id = "forest"
display_name = "森林"
description = "茂密的森林环境"
preview_image = "res://assets/maps/forest_preview.png"
background = "res://assets/maps/forest_bg.png"
map_scene = "res://scenes/levels/maps/generated_map.tscn"
wave_count = 20
blueprint = ExtResource("2")
```

Key changes from the old file:
- Removed `ext_resource` to `default_generator_config.tres` (deleted)
- Replaced `generator_config = ExtResource("2")` with `blueprint = ExtResource("2")` pointing to the new blueprint
- Updated `wave_count` from 12 to 20 (matches current 20-wave data)

- [ ] **Step 5: Commit**

```bash
git add resources/maps/zones/ resources/maps/blueprints/ scenes/levels/maps/generated_map.tscn resources/maps/forest.tres
git commit -m "feat(#4): 森林地图蓝图数据 — 3 区域 + 4 刷新点 + 生成场景"
```

---

### Task 7: Update GameConfig and main.gd integration

Wire up the new map generation system in main.gd.

**Files:**
- Modify: `scripts/ui/main.gd` (specifically `_load_map()`)

- [ ] **Step 1: Update `_load_map()` in main.gd**

In `scripts/ui/main.gd`, replace the existing `_load_map()` method (lines ~74-100):

```gdscript
func _load_map() -> void:
	var map_data: MapData = GameConfig.maps.get(PlayerState.selected_map)
	if map_data == null or map_data.map_scene.is_empty():
		push_warning("地图场景未配置: " + PlayerState.selected_map)
		return
	if not ResourceLoader.exists(map_data.map_scene):
		push_warning("地图场景文件不存在: " + map_data.map_scene)
		return
	var map_instance = load(map_data.map_scene).instantiate()
	add_child(map_instance)
	move_child(map_instance, 0)

	if map_data.blueprint != null:
		var generator := MapGenerator.new()
		var layout := generator.generate(map_data.blueprint)
		_map_layout = layout
		_player_spawn_pos = layout.get_player_spawn_world()
		# 渲染
		var renderer := MapRenderer.new()
		renderer.render(layout, map_instance.get_node("Ground"))
		renderer.create_colliders(layout, map_instance.get_node("Colliders"))
		renderer.create_spawn_markers(layout, map_instance.get_node("SpawnMarkers"))
	else:
		_player_spawn_pos = Vector2.ZERO

	_entity_layer = map_instance.get_node("EntityLayer")
	_projectile_layer = map_instance.get_node("ProjectileLayer")
	_pickup_layer = map_instance.get_node("PickupLayer")
	assert(_entity_layer != null, "地图缺少 EntityLayer 节点")
	assert(_projectile_layer != null, "地图缺少 ProjectileLayer 节点")
	assert(_pickup_layer != null, "地图缺少 PickupLayer 节点")
```

- [ ] **Step 2: Pass spawn points to EnemySpawner**

In main.gd `_ready()`, after `_load_map()` and before `$WaveManager.start_next_wave()`, add:

```gdscript
	# 传递刷新点给 EnemySpawner
	if _map_layout:
		$EnemySpawner.all_spawn_points = _map_layout.get_spawn_points_world()
```

If EnemySpawner is not a direct child of main (check the scene tree), find it via `get_tree().get_first_node_in_group()` or adjust the path.

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/main.gd
git commit -m "feat(#4): main.gd 集成新地图生成系统 — generate+render+spawn points"
```

---

### Task 8: EnemySpawner directional spawn system (TDD)

Refactor EnemySpawner to use directional spawn points with wave-based activation.

**Files:**
- Modify: `scripts/systems/enemy_spawner.gd`
- Modify: `scripts/resources/wave_data.gd`
- Create: `tests/unit/test_spawn_directions.gd`

- [ ] **Step 1: Add `active_spawn_directions` to WaveData**

In `scripts/resources/wave_data.gd`, add after the Boss fields:

```gdscript
# 刷新点方向覆盖（空=走自动规则）
@export var active_spawn_directions: Array[String] = []
```

- [ ] **Step 2: Write failing tests**

Create `tests/unit/test_spawn_directions.gd`:

```gdscript
extends GutTest

var spawner: EnemySpawner

func before_each() -> void:
	spawner = EnemySpawner.new()
	spawner.all_spawn_points = {
		"north": Vector2(0.0, -368.0),
		"south": Vector2(0.0, 368.0),
		"east": Vector2(608.0, 0.0),
		"west": Vector2(-608.0, 0.0),
	}
	add_child(spawner)

func after_each() -> void:
	spawner.queue_free()

func test_auto_directions_wave_1_to_5() -> void:
	spawner.update_active_directions(3, WaveData.new())
	assert_eq(spawner.active_directions.size(), 2, "wave 3 should activate 2 directions")

func test_auto_directions_wave_6_to_12() -> void:
	spawner.update_active_directions(8, WaveData.new())
	assert_eq(spawner.active_directions.size(), 3, "wave 8 should activate 3 directions")

func test_auto_directions_wave_13_plus() -> void:
	spawner.update_active_directions(15, WaveData.new())
	assert_eq(spawner.active_directions.size(), 4, "wave 15 should activate all 4")

func test_wave_data_overrides_auto() -> void:
	var wd := WaveData.new()
	wd.active_spawn_directions = ["north", "south"]
	spawner.update_active_directions(15, wd)
	assert_eq(spawner.active_directions.size(), 2, "override should use 2 directions")
	assert_has(spawner.active_directions, "north")
	assert_has(spawner.active_directions, "south")

func test_spawn_position_from_active_direction() -> void:
	spawner.active_directions = ["north"]
	var pos := spawner.get_random_spawn_position()
	# 应该在北刷新点附近（±16px）
	assert_almost_eq(pos.x, 0.0, 20.0)
	assert_almost_eq(pos.y, -368.0, 20.0)

func test_spawn_position_fallback_when_no_points() -> void:
	spawner.all_spawn_points = {}
	spawner.active_directions = []
	var pos := spawner.get_random_spawn_position()
	# 应该返回某个有效位置（不崩溃）
	assert_true(pos is Vector2)
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_spawn_directions.gd -gexit`

Expected: FAIL

- [ ] **Step 4: Refactor EnemySpawner**

In `scripts/systems/enemy_spawner.gd`, make these changes:

**Replace** the old spawn_points and map boundary vars:
```gdscript
var spawn_points: Array[Vector2] = []
var map_min_x: float = -GameConfig.PLAY_HALF_WIDTH
var map_max_x: float = GameConfig.PLAY_HALF_WIDTH
var map_min_y: float = -GameConfig.PLAY_HALF_HEIGHT
var map_max_y: float = GameConfig.PLAY_HALF_HEIGHT
```

**With:**
```gdscript
var all_spawn_points: Dictionary = {}  # {"north": Vector2, ...}
var active_directions: Array[String] = []
```

**Replace** `get_random_spawn_position()` and `_legacy_random_position()`:

```gdscript
func get_random_spawn_position() -> Vector2:
	if active_directions.is_empty() or all_spawn_points.is_empty():
		return Vector2(
			randf_range(-GameConfig.PLAY_HALF_WIDTH, GameConfig.PLAY_HALF_WIDTH),
			randf_range(-GameConfig.PLAY_HALF_HEIGHT, GameConfig.PLAY_HALF_HEIGHT)
		)
	var dir: String = active_directions[randi() % active_directions.size()]
	var base_pos: Vector2 = all_spawn_points[dir]
	return base_pos + Vector2(randf_range(-16, 16), randf_range(-16, 16))

func update_active_directions(wave_number: int, wave_data: WaveData) -> void:
	if not wave_data.active_spawn_directions.is_empty():
		active_directions = wave_data.active_spawn_directions.duplicate()
		return
	var count: int
	if wave_number <= 5:
		count = 2
	elif wave_number <= 12:
		count = 3
	else:
		count = all_spawn_points.size()
	active_directions = _pick_random_directions(count)

func _pick_random_directions(count: int) -> Array[String]:
	var dirs: Array[String] = []
	var all_dirs := all_spawn_points.keys()
	all_dirs.shuffle()
	for i in range(mini(count, all_dirs.size())):
		dirs.append(all_dirs[i])
	return dirs
```

**Update** `_on_wave_started()` to call `update_active_directions`:

In the `_on_wave_started` method, add at the beginning (after existing setup):
```gdscript
	update_active_directions(_wave_number, wave_data)
```

Delete `_legacy_random_position()` entirely.

- [ ] **Step 5: Run tests to verify they pass**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_spawn_directions.gd -gexit`

Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add scripts/systems/enemy_spawner.gd scripts/resources/wave_data.gd tests/unit/test_spawn_directions.gd
git commit -m "feat(#4): 方向刷新点系统 — 自动 2→3→4 激活 + WaveData 覆盖"
```

---

### Task 9: Update existing tests

Fix tests broken by the refactoring.

**Files:**
- Modify: `tests/unit/test_map_select.gd` (if it references `generator_config`)
- Check: `tests/unit/test_map_waves.gd` (likely unaffected)
- Check: all other tests for compilation errors

- [ ] **Step 1: Check and fix test_map_select.gd**

Read `tests/unit/test_map_select.gd`. If it references `generator_config`, change to `blueprint`. If it references `MapGeneratorConfig`, remove those references.

- [ ] **Step 2: Run all tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

Fix any compilation errors or test failures caused by the refactoring. Common issues:
- References to deleted classes (`MapGeneratorConfig`, `MapPrefab`, `TerrainAutotiler`)
- References to `MapLayout.CellType.WALL`, `ABYSS`, `BORDER` (now only `GROUND`/`OBSTACLE`)
- References to `generator_config` on `MapData` (now `blueprint`)
- References to old `spawn_points` array on `EnemySpawner` (now `all_spawn_points` dict)

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "fix(#4): 修复旧测试适配新地图系统"
```

---

### Task 10: Integration test

End-to-end test verifying the complete flow: blueprint → generate → layout validation.

**Files:**
- Create: `tests/integration/test_map_generation_flow.gd`

- [ ] **Step 1: Write integration test**

Create `tests/integration/test_map_generation_flow.gd`:

```gdscript
extends GutTest

func test_forest_blueprint_generates_valid_layout() -> void:
	var blueprint: MapBlueprint = load("res://resources/maps/blueprints/forest_blueprint.tres")
	assert_not_null(blueprint, "forest blueprint should load")
	assert_eq(blueprint.zones.size(), 3, "should have 3 zones")
	assert_eq(blueprint.spawn_points.size(), 4, "should have 4 spawn points")

	var generator := MapGenerator.new()
	var layout := generator.generate(blueprint)

	# 网格尺寸
	assert_eq(layout.grid_width, 40)
	assert_eq(layout.grid_height, 24)

	# 玩家出生点是 GROUND
	assert_true(layout.is_ground(layout.player_spawn), "player spawn should be ground")

	# 所有刷新点可达
	var visited := {}
	var queue: Array[Vector2i] = [layout.player_spawn]
	visited[layout.player_spawn] = true
	var dirs: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		for dir in dirs:
			var next: Vector2i = current + dir
			if visited.has(next):
				continue
			if layout.is_ground(next):
				visited[next] = true
				queue.append(next)
	for sp_dir in layout.spawn_points:
		var sp: Vector2i = layout.spawn_points[sp_dir]
		assert_true(visited.has(sp), "%s spawn point should be reachable" % sp_dir)

	# 中央废墟骨架存在
	assert_eq(layout.get_cell(Vector2i(15, 9)), MapLayout.CellType.OBSTACLE, "central ruins top-left wall")
	assert_eq(layout.get_cell(Vector2i(24, 9)), MapLayout.CellType.OBSTACLE, "central ruins top-right wall")

	# 东北狭道墙柱存在
	assert_eq(layout.get_cell(Vector2i(14, 2)), MapLayout.CellType.OBSTACLE, "NE corridor left wall")
	assert_eq(layout.get_cell(Vector2i(17, 2)), MapLayout.CellType.OBSTACLE, "NE corridor right wall")

	# 东北狭道通道畅通
	assert_eq(layout.get_cell(Vector2i(15, 4)), MapLayout.CellType.GROUND, "NE corridor passage")
	assert_eq(layout.get_cell(Vector2i(16, 4)), MapLayout.CellType.GROUND, "NE corridor passage")

func test_spawn_direction_activation() -> void:
	var spawner := EnemySpawner.new()
	spawner.all_spawn_points = {
		"north": Vector2(0, -368),
		"south": Vector2(0, 368),
		"east": Vector2(608, 0),
		"west": Vector2(-608, 0),
	}
	add_child(spawner)

	# 前期 2 个方向
	spawner.update_active_directions(1, WaveData.new())
	assert_eq(spawner.active_directions.size(), 2)

	# 中期 3 个方向
	spawner.update_active_directions(6, WaveData.new())
	assert_eq(spawner.active_directions.size(), 3)

	# 后期全部
	spawner.update_active_directions(13, WaveData.new())
	assert_eq(spawner.active_directions.size(), 4)

	# Boss 波覆盖
	var boss_wd := WaveData.new()
	boss_wd.active_spawn_directions = ["north", "south", "east", "west"]
	spawner.update_active_directions(5, boss_wd)
	assert_eq(spawner.active_directions.size(), 4)

	spawner.queue_free()

func test_multiple_generations_differ() -> void:
	var blueprint: MapBlueprint = load("res://resources/maps/blueprints/forest_blueprint.tres")
	var generator := MapGenerator.new()
	var layout_a := generator.generate(blueprint, 1)
	var layout_b := generator.generate(blueprint, 2)
	# 南部碎石区有随机填充，两次生成应有差异
	var diff_count := 0
	for y in range(17, 23):
		for x in range(10, 30):
			if layout_a.grid[y][x] != layout_b.grid[y][x]:
				diff_count += 1
	assert_gt(diff_count, 0, "different seeds should produce different layouts in rubble zone")
```

- [ ] **Step 2: Run integration test**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_map_generation_flow.gd -gexit`

Expected: All tests PASS

- [ ] **Step 3: Run full test suite**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

Expected: All tests PASS (no regressions)

- [ ] **Step 4: Commit**

```bash
git add tests/integration/test_map_generation_flow.gd
git commit -m "test(#4): 地图生成集成测试 — 蓝图加载+连通性+刷新点激活+随机差异"
```

---

## Summary

| Task | Description | Key files |
|------|-------------|-----------|
| 1 | Delete old map system | 11 files deleted, GameConfig cleaned |
| 2 | New MapLayout (TDD) | `map_layout.gd` + tests |
| 3 | ZoneData + MapBlueprint | 2 new Resource classes + MapData update |
| 4 | MapGenerator (TDD) | `map_generator.gd` + tests |
| 5 | MapRenderer | `map_renderer.gd` (blocks + colliders) |
| 6 | Data files + scene | 3 zone .tres + blueprint .tres + .tscn |
| 7 | main.gd integration | `_load_map()` rewrite |
| 8 | Spawn directions (TDD) | EnemySpawner + WaveData + tests |
| 9 | Fix existing tests | Adapt to new API |
| 10 | Integration test | End-to-end validation |
