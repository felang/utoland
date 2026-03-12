# 地图尺寸与摄像机改造 实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将地图尺寸和摄像机参数从硬编码改为配置驱动，实现 Brotato 风格的开阔视野竞技场体验。

**Architecture:** 扩展 EffectConfigData 新增摄像机/地图字段 → GameConfig 在 _ready() 中动态计算地图尺寸 → camera_shake.gd 和 map_boundary.gd 读取计算值 → debug_panel 快捷键改为 Ctrl 组合键并支持运行时调 zoom。

**Tech Stack:** Godot 4.6 GDScript, Resource (.tres), Camera2D drag margins

**Spec:** `docs/superpowers/specs/2026-03-12-map-size-camera-design.md`

**Test command:** `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `scripts/resources/effect_config_data.gd` | Modify | 新增 camera_dead_zone_width/height, map_size_ratio 字段；camera_zoom 从 Vector2 改为 float |
| `resources/effects/default_effects.tres` | Modify | 更新字段值 |
| `scripts/core/game_config.gd` | Modify | MAP_PIXEL_WIDTH/HEIGHT 改 var，_ready() 动态计算；移除 MAP_COLS/MAP_ROWS |
| `scripts/systems/camera_shake.gd` | Modify | 读取 float zoom 转 Vector2，设置 drag margins |
| `scripts/shared/map_boundary.gd` | Create | 动态设置碰撞墙位置和尺寸 |
| `scenes/shared/map_boundary.tscn` | Modify | 附加 map_boundary.gd 脚本 |
| `scripts/systems/enemy_spawner.gd` | Modify | map 边界变量改到 _ready() |
| `scripts/ui/placement.gd` | Modify | 摄像机限制和边界检查改到 _ready() 读取 |
| `scripts/ui/grid_overlay.gd` | Modify | 移除 MAP_COLS/MAP_ROWS 依赖 |
| `scripts/ui/debug_panel.gd` | Modify | Ctrl 组合键，新增 zoom 调整 |
| `project.godot` | Modify | 更新 input map 为 Ctrl 组合键，新增 debug_zoom_in/out |
| `tests/unit/test_game_config_dimensions.gd` | Modify | 断言改为验证动态公式 |
| `tests/unit/test_camera_shake.gd` | Modify | zoom 断言改为 float→Vector2 |
| `tests/unit/test_grid_overlay.gd` | Modify | 移除 MAP_COLS/MAP_ROWS 断言 |
| `tests/unit/test_placement_grid_rules.gd` | Modify | 无需改动（已用 GameConfig.MAP_HALF_WIDTH 动态值） |
| `tests/integration/test_enemy_spawning.gd` | Modify | 无需改动（已用 GameConfig.MAP_HALF_WIDTH 动态值） |

---

## Chunk 1: EffectConfigData + camera_shake + GameConfig（原子改动）

> **重要**：Task 1 将 camera_zoom 从 Vector2 改为 float，这会导致 camera_shake.gd 运行时崩溃。因此 Task 1 和 Task 2 必须在同一次提交中完成，确保任何时刻代码都可运行。

### Task 1: 扩展 EffectConfigData + 同步更新 camera_shake（原子提交）

**Files:**
- Modify: `scripts/resources/effect_config_data.gd:80-84`
- Modify: `scripts/systems/camera_shake.gd:17-28`
- Create: `tests/unit/test_effect_config_camera_fields.gd`
- Modify: `tests/unit/test_camera_shake.gd:32-46`

- [ ] **Step 1: 写新测试 — EffectConfigData 新字段**

创建 `tests/unit/test_effect_config_camera_fields.gd`:

```gdscript
extends GutTest

func test_camera_zoom_is_float():
	var fx: EffectConfigData = GameConfig.effects
	assert_typeof(fx.camera_zoom, TYPE_FLOAT, "camera_zoom 应为 float 类型")

func test_camera_dead_zone_fields_exist():
	var fx: EffectConfigData = GameConfig.effects
	assert_gt(fx.camera_dead_zone_width, 0.0, "dead_zone_width 应大于 0")
	assert_gt(fx.camera_dead_zone_height, 0.0, "dead_zone_height 应大于 0")

func test_map_size_ratio_exists():
	var fx: EffectConfigData = GameConfig.effects
	assert_gt(fx.map_size_ratio, 0.0, "map_size_ratio 应大于 0")
```

- [ ] **Step 2: 更新 camera_shake 测试**

在 `tests/unit/test_camera_shake.gd` 中替换 `test_camera_zoom_from_config` 和 `test_camera_has_map_limits`，并新增 drag margins 测试：

```gdscript
func test_camera_zoom_from_config():
	var camera = Camera2D.new()
	camera.set_script(shake_script)
	add_child_autoqfree(camera)
	await get_tree().process_frame
	var expected_zoom: Vector2 = Vector2(GameConfig.effects.camera_zoom, GameConfig.effects.camera_zoom)
	assert_eq(camera.zoom, expected_zoom, "摄像机缩放应从 float 配置转为 Vector2")

func test_camera_has_map_limits():
	var camera = Camera2D.new()
	camera.set_script(shake_script)
	add_child_autoqfree(camera)
	await get_tree().process_frame
	assert_eq(camera.limit_left, -int(GameConfig.MAP_HALF_WIDTH), "左边界应为地图左端")
	assert_eq(camera.limit_right, int(GameConfig.MAP_HALF_WIDTH), "右边界应为地图右端")

func test_camera_drag_margins_from_config():
	var camera = Camera2D.new()
	camera.set_script(shake_script)
	add_child_autoqfree(camera)
	await get_tree().process_frame
	assert_true(camera.drag_horizontal_enabled, "水平拖拽应启用")
	assert_true(camera.drag_vertical_enabled, "垂直拖拽应启用")
	var fx: EffectConfigData = GameConfig.effects
	assert_eq(camera.drag_left_margin, fx.camera_dead_zone_width, "左拖拽边距应匹配配置")
	assert_eq(camera.drag_right_margin, fx.camera_dead_zone_width, "右拖拽边距应匹配配置")
```

- [ ] **Step 3: 修改 effect_config_data.gd**

在 `scripts/resources/effect_config_data.gd` 第 80-84 行，将：
```gdscript
# 摄像机
@export var camera_zoom: Vector2 = Vector2(0.75, 0.75)
@export var camera_smoothing_speed: float = 8.0
@export var camera_look_ahead_distance: float = 40.0
@export var camera_look_ahead_smoothing: float = 3.0
```

改为：
```gdscript
# 摄像机
@export var camera_zoom: float = 0.55
@export var camera_smoothing_speed: float = 8.0
@export var camera_look_ahead_distance: float = 40.0
@export var camera_look_ahead_smoothing: float = 3.0
@export var camera_dead_zone_width: float = 0.1
@export var camera_dead_zone_height: float = 0.1

# 地图
@export var map_size_ratio: float = 1.3
```

- [ ] **Step 4: 清理 default_effects.tres**

当前 `resources/effects/default_effects.tres` 没有显式设置 `camera_zoom` 值（全用脚本默认值）。修改 Resource 类后，如果 .tres 中残留了旧的 Vector2 序列化数据，会导致类型冲突。检查 .tres 文件：
- 如果文件中没有 `camera_zoom` 行（当前就是这种情况），则无需改动，Godot 会使用脚本中的新默认值 `0.55`
- 如果 .tres 中显式包含 `camera_zoom = Vector2(...)` 行，需要删除该行或改为 `camera_zoom = 0.55`

当前文件仅包含 `script = ExtResource("1")`，未显式设置任何属性，所以**无需改动 .tres 文件**。

- [ ] **Step 5: 同步修改 camera_shake.gd _ready()**

将 `scripts/systems/camera_shake.gd` 的 `_ready()` 替换为：

```gdscript
func _ready() -> void:
	var fx: EffectConfigData = GameConfig.effects
	# 缩放（float → Vector2）
	zoom = Vector2(fx.camera_zoom, fx.camera_zoom)
	# 平滑跟随
	position_smoothing_enabled = true
	position_smoothing_speed = fx.camera_smoothing_speed
	# 地图边界限制
	limit_left = -int(GameConfig.MAP_HALF_WIDTH)
	limit_right = int(GameConfig.MAP_HALF_WIDTH)
	limit_top = -int(GameConfig.MAP_HALF_HEIGHT)
	limit_bottom = int(GameConfig.MAP_HALF_HEIGHT)
	# 死区（drag margins）
	drag_horizontal_enabled = true
	drag_vertical_enabled = true
	drag_left_margin = fx.camera_dead_zone_width
	drag_right_margin = fx.camera_dead_zone_width
	drag_top_margin = fx.camera_dead_zone_height
	drag_bottom_margin = fx.camera_dead_zone_height
	# 连接全局 camera shake 请求
	EventBus.camera_shake_requested.connect(shake)
```

- [ ] **Step 6: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit`
Expected: ALL PASS

- [ ] **Step 7: 原子提交（EffectConfigData + camera_shake 同时改）**

```bash
git add scripts/resources/effect_config_data.gd scripts/systems/camera_shake.gd tests/unit/test_effect_config_camera_fields.gd tests/unit/test_camera_shake.gd
git commit -m "feat: camera_zoom 改为 float + 新增 dead_zone/map_size_ratio + camera_shake 同步适配"
```

---

### Task 2: GameConfig 地图尺寸动态计算

**Files:**
- Modify: `scripts/core/game_config.gd:17-22`
- Modify: `tests/unit/test_game_config_dimensions.gd`

- [ ] **Step 1: 更新 test_game_config_dimensions.gd 测试**

将 `tests/unit/test_game_config_dimensions.gd` 全部内容替换为：

```gdscript
extends GutTest

func test_viewport_constants_unchanged():
	assert_eq(GameConfig.BASE_VIEWPORT_WIDTH, 640)
	assert_eq(GameConfig.BASE_VIEWPORT_HEIGHT, 360)
	assert_eq(GameConfig.PPU, 32)
	assert_eq(GameConfig.GRID_SIZE, 32)

func test_map_dimensions_are_dynamically_computed():
	var fx: EffectConfigData = GameConfig.effects
	var expected_w: float = GameConfig.BASE_VIEWPORT_WIDTH / fx.camera_zoom * fx.map_size_ratio
	var expected_h: float = GameConfig.BASE_VIEWPORT_HEIGHT / fx.camera_zoom * fx.map_size_ratio
	assert_almost_eq(GameConfig.MAP_PIXEL_WIDTH, expected_w, 0.01, "MAP_PIXEL_WIDTH 应等于 viewport/zoom*ratio")
	assert_almost_eq(GameConfig.MAP_PIXEL_HEIGHT, expected_h, 0.01, "MAP_PIXEL_HEIGHT 应等于 viewport/zoom*ratio")

func test_map_half_extents_are_half_of_full():
	assert_almost_eq(GameConfig.MAP_HALF_WIDTH, GameConfig.MAP_PIXEL_WIDTH / 2.0, 0.01)
	assert_almost_eq(GameConfig.MAP_HALF_HEIGHT, GameConfig.MAP_PIXEL_HEIGHT / 2.0, 0.01)

func test_viewport_matches_project_settings():
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 640)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 360)

func test_entity_dimension_constants_are_stable():
	assert_eq(GameConfig.ENTITY_SIZE_STANDARD, 32)
	assert_eq(GameConfig.ENTITY_SIZE_TANK, 48)
	assert_eq(GameConfig.BULLET_SIZE, 6)
	assert_eq(GameConfig.COIN_RADIUS, 6)

func test_entity_and_ui_size_tokens_are_grid_aligned():
	assert_eq(GameConfig.ENTITY_SIZE_STANDARD, GameConfig.GRID_SIZE)
	assert_eq(GameConfig.BULLET_SIZE, int(GameConfig.GRID_SIZE * 0.2))
	assert_eq(GameConfig.UI_BUTTON_SIZE, Vector2(160, 36))
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit/test_game_config_dimensions.gd -gexit`
Expected: FAIL — MAP_PIXEL_WIDTH 仍是 const 1280，不等于动态公式值

- [ ] **Step 3: 修改 game_config.gd**

在 `scripts/core/game_config.gd` 中，将第 17-22 行：
```gdscript
const MAP_COLS = 40
const MAP_ROWS = 30
const MAP_PIXEL_WIDTH = MAP_COLS * GRID_SIZE   # 1200
const MAP_PIXEL_HEIGHT = MAP_ROWS * GRID_SIZE  # 900
const MAP_HALF_WIDTH = MAP_PIXEL_WIDTH / 2.0     # 600
const MAP_HALF_HEIGHT = MAP_PIXEL_HEIGHT / 2.0   # 450
```

替换为：
```gdscript
# 地图尺寸（动态计算，_ready() 中赋值）
var MAP_PIXEL_WIDTH: float = 0.0
var MAP_PIXEL_HEIGHT: float = 0.0
var MAP_HALF_WIDTH: float = 0.0
var MAP_HALF_HEIGHT: float = 0.0
```

在 `_ready()` 函数中，在 `_load_resources_from_dir("res://resources/items/", items)` 之后添加一行调用：
```gdscript
	# 动态计算地图尺寸
	_compute_map_dimensions()
```

然后在 `_ready()` 函数**之后**（与 `_ready` 同级缩进），添加新的顶层函数：
```gdscript

func _compute_map_dimensions() -> void:
	var fx: EffectConfigData = effects
	if fx:
		MAP_PIXEL_WIDTH = BASE_VIEWPORT_WIDTH / fx.camera_zoom * fx.map_size_ratio
		MAP_PIXEL_HEIGHT = BASE_VIEWPORT_HEIGHT / fx.camera_zoom * fx.map_size_ratio
	else:
		# fallback：与旧尺寸接近
		MAP_PIXEL_WIDTH = 1280.0
		MAP_PIXEL_HEIGHT = 960.0
	MAP_HALF_WIDTH = MAP_PIXEL_WIDTH / 2.0
	MAP_HALF_HEIGHT = MAP_PIXEL_HEIGHT / 2.0
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit/test_game_config_dimensions.gd -gexit`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/core/game_config.gd tests/unit/test_game_config_dimensions.gd
git commit -m "feat: GameConfig 地图尺寸改为动态计算（viewport/zoom*ratio）"
```

---

## Chunk 2: 消费者迁移 + 边界动态化

### Task 3: enemy_spawner.gd 边界变量迁移到 _ready()

**Files:**
- Modify: `scripts/systems/enemy_spawner.gd:13-17`

- [ ] **Step 1: 写失败测试 — spawner 使用动态边界值**

在 `tests/integration/test_enemy_spawning.gd` 中：
1. 末尾添加新测试
2. 同时修复已有的 `test_spawn_position_is_inside_new_map_bounds`（当前未 add_child，_ready() 不执行，边界变量迁移后会变成 0）

添加/替换：
```gdscript
func test_spawner_uses_dynamic_map_bounds():
	var spawner = preload("res://scripts/systems/enemy_spawner.gd").new()
	add_child_autoqfree(spawner)
	await get_tree().process_frame
	assert_almost_eq(spawner.map_min_x, -GameConfig.MAP_HALF_WIDTH, 0.01, "min_x 应等于动态值")
	assert_almost_eq(spawner.map_max_x, GameConfig.MAP_HALF_WIDTH, 0.01, "max_x 应等于动态值")

func test_spawn_position_is_inside_new_map_bounds():
	var spawner = preload("res://scripts/systems/enemy_spawner.gd").new()
	add_child_autoqfree(spawner)
	await get_tree().process_frame
	for i in range(20):
		var pos = spawner.get_random_spawn_position()
		assert_lte(abs(pos.x), GameConfig.MAP_HALF_WIDTH)
		assert_lte(abs(pos.y), GameConfig.MAP_HALF_HEIGHT)
```

（删除原有的 `test_spawn_position_is_inside_new_map_bounds`，用上面的替代）

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/integration/test_enemy_spawning.gd -gexit`
Expected: FAIL — 当前变量声明处用旧 const 值（640/480），动态值不同

- [ ] **Step 3: 修改 enemy_spawner.gd**

在 `scripts/systems/enemy_spawner.gd` 中，将第 13-17 行：
```gdscript
# Map boundaries
var map_min_x: float = -GameConfig.MAP_HALF_WIDTH
var map_max_x: float = GameConfig.MAP_HALF_WIDTH
var map_min_y: float = -GameConfig.MAP_HALF_HEIGHT
var map_max_y: float = GameConfig.MAP_HALF_HEIGHT
```

改为：
```gdscript
# Map boundaries（_ready() 中从 GameConfig 读取动态值）
var map_min_x: float = 0.0
var map_max_x: float = 0.0
var map_min_y: float = 0.0
var map_max_y: float = 0.0
```

在 `_ready()` 函数开头添加：
```gdscript
	map_min_x = -GameConfig.MAP_HALF_WIDTH
	map_max_x = GameConfig.MAP_HALF_WIDTH
	map_min_y = -GameConfig.MAP_HALF_HEIGHT
	map_max_y = GameConfig.MAP_HALF_HEIGHT
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/integration/test_enemy_spawning.gd -gexit`
Expected: ALL PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/systems/enemy_spawner.gd tests/integration/test_enemy_spawning.gd
git commit -m "refactor: enemy_spawner 地图边界改到 _ready() 读取动态值"
```

---

### Task 4: placement.gd 摄像机限制迁移

**Files:**
- Modify: `scripts/ui/placement.gd:60-63`

- [ ] **Step 1: 修改 placement.gd**

`placement.gd` 第 60-63 行的摄像机限制已经在 `_ready()` 中通过 `GameConfig.MAP_HALF_WIDTH` 读取，这些是函数体内的读取，autoload `_ready()` 先执行，所以动态值在此时已可用。**无需改动**。

同样，`_can_place_at()` (第 148 行) 和 `_use_fallback_background()` (第 285 行) 中的 `GameConfig.MAP_PIXEL_WIDTH/HEIGHT` 读取都在函数调用时才执行，也无需改动。

- [ ] **Step 2: 运行 placement 测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit/test_placement_grid_rules.gd -gexit`
Expected: ALL PASS（测试中已使用 `GameConfig.MAP_HALF_WIDTH` 动态引用）

- [ ] **Step 3: 不需要提交**（无改动）

---

### Task 5: grid_overlay.gd 移除 MAP_COLS/MAP_ROWS 依赖

**Files:**
- Modify: `scripts/ui/grid_overlay.gd`
- Modify: `tests/unit/test_grid_overlay.gd`

- [ ] **Step 1: 更新 test_grid_overlay.gd**

将 `tests/unit/test_grid_overlay.gd` 全部替换为：

```gdscript
extends GutTest

var overlay: GridOverlay

func before_each():
	overlay = load("res://scripts/ui/grid_overlay.gd").new()
	add_child_autofree(overlay)

func test_grid_overlay_last_vertical_line_is_at_right_boundary():
	var v_lines: Array = overlay.get_vertical_line_positions()
	assert_almost_eq(v_lines[-1], GameConfig.MAP_HALF_WIDTH, 1.0, "最后一条竖线应在右边界附近")

func test_grid_overlay_last_horizontal_line_is_at_bottom_boundary():
	var h_lines: Array = overlay.get_horizontal_line_positions()
	assert_almost_eq(h_lines[-1], GameConfig.MAP_HALF_HEIGHT, 1.0, "最后一条横线应在下边界附近")

func test_grid_overlay_first_lines_at_negative_boundary():
	var v_lines: Array = overlay.get_vertical_line_positions()
	var h_lines: Array = overlay.get_horizontal_line_positions()
	assert_almost_eq(v_lines[0], -GameConfig.MAP_HALF_WIDTH, 1.0, "第一条竖线在左边界附近")
	assert_almost_eq(h_lines[0], -GameConfig.MAP_HALF_HEIGHT, 1.0, "第一条横线在上边界附近")

func test_grid_overlay_lines_are_grid_spaced():
	var v_lines: Array = overlay.get_vertical_line_positions()
	if v_lines.size() >= 2:
		var spacing: float = v_lines[1] - v_lines[0]
		assert_almost_eq(spacing, float(GameConfig.GRID_SIZE), 0.01, "竖线间距应为 GRID_SIZE")

func test_grid_overlay_line_count_matches_formula():
	var v_lines: Array = overlay.get_vertical_line_positions()
	var h_lines: Array = overlay.get_horizontal_line_positions()
	var expected_v: int = int(floor(GameConfig.MAP_PIXEL_WIDTH / GameConfig.GRID_SIZE)) + 1
	var expected_h: int = int(floor(GameConfig.MAP_PIXEL_HEIGHT / GameConfig.GRID_SIZE)) + 1
	assert_eq(v_lines.size(), expected_v, "竖线数量应为 floor(MAP_WIDTH/GRID) + 1")
	assert_eq(h_lines.size(), expected_h, "横线数量应为 floor(MAP_HEIGHT/GRID) + 1")
```

- [ ] **Step 2: 运行测试确认通过**

grid_overlay.gd 本身不需要改动 — 它已经在 `_draw()` 和函数体中读取 `GameConfig.MAP_HALF_WIDTH/HEIGHT`（运行时读取，动态值已可用），并用 `GameConfig.GRID_SIZE`（保留为 const）做间距。`MAP_COLS/MAP_ROWS` 只在旧测试中被引用。

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit/test_grid_overlay.gd -gexit`
Expected: ALL PASS

- [ ] **Step 3: 提交**

```bash
git add tests/unit/test_grid_overlay.gd
git commit -m "test: grid_overlay 测试移除 MAP_COLS/MAP_ROWS 依赖，改用动态边界"
```

---

### Task 6: map_boundary.gd 动态碰撞墙

**Files:**
- Create: `scripts/shared/map_boundary.gd`
- Modify: `scenes/shared/map_boundary.tscn`

- [ ] **Step 1: 写失败测试**

创建 `tests/unit/test_map_boundary.gd`:

```gdscript
extends GutTest

func test_map_boundary_walls_match_game_config():
	var boundary_scene = load("res://scenes/shared/map_boundary.tscn")
	var boundary = boundary_scene.instantiate()
	add_child_autoqfree(boundary)
	await get_tree().process_frame

	var half_w: float = GameConfig.MAP_HALF_WIDTH
	var half_h: float = GameConfig.MAP_HALF_HEIGHT
	var wall_thickness: float = 32.0

	# 检查墙壁位置（含半个墙厚偏移）
	var top: StaticBody2D = boundary.get_node("TopWall")
	var bottom: StaticBody2D = boundary.get_node("BottomWall")
	var left: StaticBody2D = boundary.get_node("LeftWall")
	var right: StaticBody2D = boundary.get_node("RightWall")

	assert_almost_eq(top.position.y, -(half_h + wall_thickness / 2.0), 1.0, "TopWall y 位置")
	assert_almost_eq(bottom.position.y, half_h + wall_thickness / 2.0, 1.0, "BottomWall y 位置")
	assert_almost_eq(left.position.x, -(half_w + wall_thickness / 2.0), 1.0, "LeftWall x 位置")
	assert_almost_eq(right.position.x, half_w + wall_thickness / 2.0, 1.0, "RightWall x 位置")
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit/test_map_boundary.gd -gexit`
Expected: FAIL — 当前硬编码位置与动态值不匹配

- [ ] **Step 3: 创建 scripts/shared/map_boundary.gd**

```gdscript
extends Node2D

# 根据 GameConfig 动态计算的地图尺寸设置碰撞墙位置和大小

const WALL_THICKNESS: float = 32.0

func _ready() -> void:
	var half_w: float = GameConfig.MAP_HALF_WIDTH
	var half_h: float = GameConfig.MAP_HALF_HEIGHT
	var map_w: float = GameConfig.MAP_PIXEL_WIDTH + WALL_THICKNESS
	var map_h: float = GameConfig.MAP_PIXEL_HEIGHT + WALL_THICKNESS

	# TopWall
	var top: StaticBody2D = $TopWall
	top.position = Vector2(0, -(half_h + WALL_THICKNESS / 2.0))
	_set_wall_shape(top, Vector2(map_w, WALL_THICKNESS))

	# BottomWall
	var bottom: StaticBody2D = $BottomWall
	bottom.position = Vector2(0, half_h + WALL_THICKNESS / 2.0)
	_set_wall_shape(bottom, Vector2(map_w, WALL_THICKNESS))

	# LeftWall
	var left: StaticBody2D = $LeftWall
	left.position = Vector2(-(half_w + WALL_THICKNESS / 2.0), 0)
	_set_wall_shape(left, Vector2(WALL_THICKNESS, map_h))

	# RightWall
	var right: StaticBody2D = $RightWall
	right.position = Vector2(half_w + WALL_THICKNESS / 2.0, 0)
	_set_wall_shape(right, Vector2(WALL_THICKNESS, map_h))

func _set_wall_shape(wall: StaticBody2D, size: Vector2) -> void:
	var shape: CollisionShape2D = wall.get_node("CollisionShape2D")
	if shape and shape.shape is RectangleShape2D:
		shape.shape.size = size
```

- [ ] **Step 4: 在 map_boundary.tscn 中附加脚本**

**推荐方式**：使用 gdai-mcp 插件的 `attach_script` 工具，将 `res://scripts/shared/map_boundary.gd` 附加到 `scenes/shared/map_boundary.tscn` 的 MapBoundary 根节点。

**备用方式**（手动编辑 .tscn）：在文件开头添加 ext_resource，修改根 node 行：
```
[ext_resource type="Script" path="res://scripts/shared/map_boundary.gd" id="Script_boundary"]
```
根节点添加：
```
script = ExtResource("Script_boundary")
```

- [ ] **Step 5: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit/test_map_boundary.gd -gexit`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add scripts/shared/map_boundary.gd scenes/shared/map_boundary.tscn tests/unit/test_map_boundary.gd
git commit -m "feat: map_boundary 碰撞墙位置和尺寸改为动态计算"
```

---

## Chunk 3: Debug 快捷键改造

### Task 7: project.godot input map 更新

**Files:**
- Modify: `project.godot`

- [ ] **Step 1: 通过 Godot MCP 工具或手动编辑 project.godot**

更新 input map 区域，将 F1~F4 改为 Ctrl+D, Ctrl+1~3，新增 debug_zoom_in (Ctrl+5) 和 debug_zoom_out (Ctrl+4)。

Godot InputEventKey physical_keycode 参考：
- D = 68, 1 = 49, 2 = 50, 3 = 51, 4 = 52, 5 = 53
- ctrl_pressed = true

替换 project.godot 中 `debug_toggle` 到 `debug_godmode` 的 6 个 action 定义为：

```ini
debug_toggle={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":true,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
debug_skip_wave={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":true,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":49,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
debug_add_coins={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":true,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":50,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
debug_godmode={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":true,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":51,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
debug_zoom_out={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":true,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":52,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
debug_zoom_in={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":true,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":53,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

- [ ] **Step 2: 提交**

```bash
git add project.godot
git commit -m "chore: debug 快捷键改为 Ctrl 组合键，新增 zoom in/out"
```

---

### Task 8: debug_panel.gd 支持 Ctrl 快捷键 + zoom 调整

**Files:**
- Modify: `scripts/ui/debug_panel.gd`

- [ ] **Step 1: 写失败测试**

创建 `tests/unit/test_debug_panel_zoom.gd`:

```gdscript
extends GutTest

func test_debug_panel_has_zoom_actions():
	# 验证 input map 中存在 zoom action
	assert_true(InputMap.has_action("debug_zoom_in"), "debug_zoom_in action 应存在")
	assert_true(InputMap.has_action("debug_zoom_out"), "debug_zoom_out action 应存在")
```

- [ ] **Step 2: 运行测试确认通过**（因为 Task 8 已添加 input map）

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit/test_debug_panel_zoom.gd -gexit`
Expected: PASS

- [ ] **Step 3: 修改 debug_panel.gd**

替换 `scripts/ui/debug_panel.gd` 全部内容为：

```gdscript
# scripts/ui/debug_panel.gd
extends CanvasLayer

## 调试面板 — Ctrl+D 显隐，Ctrl+1 跳波，Ctrl+2 加钱，Ctrl+3 无敌，Ctrl+4/5 调 zoom

const ZOOM_STEP: float = 0.05
const ZOOM_MIN: float = 0.3
const ZOOM_MAX: float = 1.0

var _label: Label
var _godmode: bool = false

func _ready() -> void:
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		visible = not visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_skip_wave"):
		_skip_wave()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_add_coins"):
		GameData.coins += 100
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_godmode"):
		_toggle_godmode()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_zoom_out"):
		_adjust_zoom(-ZOOM_STEP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_zoom_in"):
		_adjust_zoom(ZOOM_STEP)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_info()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(4, 4)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color.GREEN)
	panel.add_child(_label)
	add_child(panel)

func _update_info() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	var wave_managers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.WAVE_MANAGER)
	var wave_info: String = "N/A"
	var total_info: String = "N/A"
	if wave_managers.size() > 0:
		var wm: Node = wave_managers[0]
		wave_info = str(wm.current_wave)
		total_info = str(wm.total_waves)

	var player: Node = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	var hp_text: String = "N/A"
	var dmg_text: String = "N/A"
	if player and player.has_node("HealthComponent"):
		hp_text = "%d/%d" % [int(player.health.current_hp), int(player.health.max_hp)]
	dmg_text = "x%.1f" % GameData.player_stats.get(Enums.Stat.DAMAGE_MULT, 1.0)

	# 摄像机 zoom 信息
	var zoom_text: String = "N/A"
	var camera: Camera2D = _get_player_camera()
	if camera:
		zoom_text = "%.2f" % camera.zoom.x
		var visible_w: float = GameConfig.BASE_VIEWPORT_WIDTH / camera.zoom.x
		var visible_h: float = GameConfig.BASE_VIEWPORT_HEIGHT / camera.zoom.y
		zoom_text += " (%dx%d)" % [int(visible_w), int(visible_h)]

	var godmode_text: String = " [GOD]" if _godmode else ""
	_label.text = "Wave: %s/%s | Enemies: %d\nHP: %s | DMG: %s\nCoins: %d | FPS: %d%s\nZoom: %s | Map: %dx%d" % [
		wave_info, total_info, enemies.size(),
		hp_text, dmg_text,
		GameData.coins, Engine.get_frames_per_second(),
		godmode_text,
		zoom_text, int(GameConfig.MAP_PIXEL_WIDTH), int(GameConfig.MAP_PIXEL_HEIGHT)
	]

func _skip_wave() -> void:
	var wave_managers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.WAVE_MANAGER)
	if wave_managers.size() > 0:
		wave_managers[0].complete_wave()

func _toggle_godmode() -> void:
	_godmode = not _godmode
	var player: Node = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	if player and player.has_node("HealthComponent"):
		player.health.invincible = _godmode

func _adjust_zoom(delta: float) -> void:
	var camera: Camera2D = _get_player_camera()
	if not camera:
		return
	var new_zoom: float = clampf(camera.zoom.x + delta, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(new_zoom, new_zoom)

func _get_player_camera() -> Camera2D:
	var player: Node = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	if player:
		for child in player.get_children():
			if child is Camera2D:
				return child
	return null
```

- [ ] **Step 4: 运行全部测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: ALL PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/ui/debug_panel.gd tests/unit/test_debug_panel_zoom.gd
git commit -m "feat: debug_panel 改用 Ctrl 快捷键，新增运行时 zoom 调整和信息显示"
```

---

## Chunk 4: 全量测试 + 最终验证

### Task 9: 运行全量测试，确认无回归

- [ ] **Step 1: 运行全部测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: ALL PASS，无新 FAIL

- [ ] **Step 2: 如果有失败，定位并修复**

常见可能的失败点：
- `test_spawn_position_is_inside_new_map_bounds` — spawner 实例未添加到场景树，`_ready()` 未执行。如果失败需将测试改为 `add_child_autoqfree(spawner)` + `await get_tree().process_frame`
- 其他引用 `GameConfig.MAP_COLS/MAP_ROWS` 的测试 — 搜索并移除这些引用

- [ ] **Step 3: 最终提交（如果有修复）**

```bash
git add -A
git commit -m "fix: 修复全量测试回归"
```
