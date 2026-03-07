# 塔布置交互优化 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 优化布置阶段交互 — 添加网格线、攻击范围圈、放置合法性颜色反馈、右键移除塔退金币。

**Architecture:** 在现有 `placement.gd` 基础上扩展。新增两个轻量级绘制节点（`GridOverlay`、`RangeIndicator`），都是 Node2D + `_draw()` 覆写。修改 `placement.gd` 的 `_input()` 逻辑以支持颜色反馈和移除塔。

**Tech Stack:** GDScript, Godot 4.6, GUT 测试框架

**关键文件参考：**
- `scripts/ui/placement.gd` — 布置主逻辑
- `scenes/levels/placement.tscn` — 布置场景
- `scripts/resources/tower_data.gd` — TowerData（含 `attack_range`）
- `scripts/core/game_config.gd` — GRID_SIZE / MAP 常量
- `tests/unit/test_placement_grid_rules.gd` — 已有单元测试
- 塔数据：shooter `attack_range=300`, slow `attack_range=200`, wall `attack_range=0`

---

### Task 1: GridOverlay — 网格线绘制

**Files:**
- Create: `scripts/ui/grid_overlay.gd`
- Test: `tests/unit/test_grid_overlay.gd`

**Step 1: Write the failing test**

创建 `tests/unit/test_grid_overlay.gd`：

```gdscript
extends GutTest

var overlay: Node2D

func before_each():
	overlay = load("res://scripts/ui/grid_overlay.gd").new()
	add_child_autofree(overlay)

func test_grid_overlay_is_node2d():
	assert_is(overlay, Node2D)

func test_grid_overlay_calculates_line_positions():
	# 验证网格线计算逻辑：从 -MAP_HALF_WIDTH 到 MAP_HALF_WIDTH，间隔 GRID_SIZE
	var gs: float = GameConfig.GRID_SIZE
	var expected_v_count: int = GameConfig.MAP_COLS + 1  # 41 条竖线
	var expected_h_count: int = GameConfig.MAP_ROWS + 1  # 31 条横线

	var v_lines: Array = overlay.get_vertical_line_positions()
	var h_lines: Array = overlay.get_horizontal_line_positions()

	assert_eq(v_lines.size(), expected_v_count, "竖线数量应为 MAP_COLS + 1")
	assert_eq(h_lines.size(), expected_h_count, "横线数量应为 MAP_ROWS + 1")
	assert_eq(v_lines[0], -GameConfig.MAP_HALF_WIDTH, "第一条竖线在左边界")
	assert_eq(h_lines[0], -GameConfig.MAP_HALF_HEIGHT, "第一条横线在上边界")
```

**Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_grid_overlay.gd -gexit`
Expected: FAIL — `grid_overlay.gd` does not exist

**Step 3: Write minimal implementation**

创建 `scripts/ui/grid_overlay.gd`：

```gdscript
extends Node2D
# 全地图网格线覆层

const GRID_COLOR = Color(1, 1, 1, 0.15)

func _draw() -> void:
	var gs: float = GameConfig.GRID_SIZE
	var half_w: float = GameConfig.MAP_HALF_WIDTH
	var half_h: float = GameConfig.MAP_HALF_HEIGHT

	# 竖线
	for x in get_vertical_line_positions():
		draw_line(Vector2(x, -half_h), Vector2(x, half_h), GRID_COLOR)

	# 横线
	for y in get_horizontal_line_positions():
		draw_line(Vector2(-half_w, y), Vector2(half_w, y), GRID_COLOR)

func get_vertical_line_positions() -> Array:
	var positions: Array = []
	var gs: float = GameConfig.GRID_SIZE
	var half_w: float = GameConfig.MAP_HALF_WIDTH
	var x: float = -half_w
	while x <= half_w + 0.01:
		positions.append(x)
		x += gs
	return positions

func get_horizontal_line_positions() -> Array:
	var positions: Array = []
	var gs: float = GameConfig.GRID_SIZE
	var half_h: float = GameConfig.MAP_HALF_HEIGHT
	var y: float = -half_h
	while y <= half_h + 0.01:
		positions.append(y)
		y += gs
	return positions
```

**Step 4: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_grid_overlay.gd -gexit`
Expected: PASS

**Step 5: Add GridOverlay to placement scene**

修改 `scripts/ui/placement.gd`，在 `_ready()` 中动态创建 GridOverlay 并添加为子节点（z_index = -50，在背景之上、实体之下）：

```gdscript
# 在 _ready() 开头，_load_map_background() 之后添加：
var grid_overlay: Node2D = preload("res://scripts/ui/grid_overlay.gd").new()
grid_overlay.z_index = -50
add_child(grid_overlay)
```

**Step 6: Commit**

```bash
git add scripts/ui/grid_overlay.gd tests/unit/test_grid_overlay.gd scripts/ui/placement.gd
git commit -m "feat: 布置场景添加全地图网格线"
```

---

### Task 2: RangeIndicator — 攻击范围圈

**Files:**
- Create: `scripts/ui/range_indicator.gd`
- Test: `tests/unit/test_range_indicator.gd`

**Step 1: Write the failing test**

创建 `tests/unit/test_range_indicator.gd`：

```gdscript
extends GutTest

var indicator: Node2D

func before_each():
	indicator = load("res://scripts/ui/range_indicator.gd").new()
	add_child_autofree(indicator)

func test_initial_radius_is_zero():
	assert_eq(indicator.radius, 0.0)

func test_set_radius_triggers_redraw():
	indicator.set_range(300.0)
	assert_eq(indicator.radius, 300.0)

func test_hide_clears_radius():
	indicator.set_range(200.0)
	indicator.hide_range()
	assert_eq(indicator.radius, 0.0)

func test_zero_radius_means_invisible():
	indicator.set_range(0.0)
	assert_false(indicator.visible)

func test_positive_radius_means_visible():
	indicator.set_range(300.0)
	assert_true(indicator.visible)
```

**Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_range_indicator.gd -gexit`
Expected: FAIL — `range_indicator.gd` does not exist

**Step 3: Write minimal implementation**

创建 `scripts/ui/range_indicator.gd`：

```gdscript
extends Node2D
# 攻击范围圈指示器

const FILL_COLOR = Color(0.3, 0.5, 1.0, 0.1)
const BORDER_COLOR = Color(0.3, 0.5, 1.0, 0.4)
const BORDER_WIDTH = 1.5

var radius: float = 0.0

func set_range(value: float) -> void:
	radius = value
	visible = radius > 0.0
	queue_redraw()

func hide_range() -> void:
	set_range(0.0)

func _draw() -> void:
	if radius <= 0.0:
		return
	draw_circle(Vector2.ZERO, radius, FILL_COLOR)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, BORDER_COLOR, BORDER_WIDTH)
```

**Step 4: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_range_indicator.gd -gexit`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/ui/range_indicator.gd tests/unit/test_range_indicator.gd
git commit -m "feat: RangeIndicator 攻击范围圈组件"
```

---

### Task 3: 集成范围圈到 placement — 预览时显示

**Files:**
- Modify: `scripts/ui/placement.gd`

**Step 1: 在 placement.gd 添加 RangeIndicator 实例**

在文件顶部变量区域添加：

```gdscript
var _range_indicator: Node2D = null
```

在 `_ready()` 中创建 RangeIndicator：

```gdscript
_range_indicator = preload("res://scripts/ui/range_indicator.gd").new()
_range_indicator.z_index = -40
add_child(_range_indicator)
```

**Step 2: 修改 `_select_tower()` — 选塔时显示范围圈**

在 `_select_tower()` 创建 preview_tower 之后，读取 TowerData 的 attack_range 并设置范围圈：

```gdscript
func _select_tower(type: String) -> void:
	var cost: int = SceneFactory.get_tower_cost(type)
	if GameData.coins < cost:
		return

	_deselect_tower()  # 新增：清除已选中的已放置塔的范围圈

	selected_tower_type = type
	if preview_tower:
		preview_tower.queue_free()

	preview_tower = SceneFactory.create_tower(type)
	if preview_tower:
		preview_tower.modulate = Color(1, 1, 1, 0.5)
		add_child(preview_tower)

		# 显示攻击范围
		var td: TowerData = GameConfig.towers[type]
		_range_indicator.set_range(td.attack_range)
```

**Step 3: 修改 `_input()` — 范围圈跟随鼠标**

在 `InputEventMouseMotion` 处理中，同步移动范围圈位置：

```gdscript
if event is InputEventMouseMotion and preview_tower:
	var grid_pos: Vector2 = _get_grid_position(get_global_mouse_position())
	preview_tower.global_position = grid_pos
	_range_indicator.global_position = grid_pos
```

**Step 4: 修改 `_place_tower()` 和 `_cancel_placement()` — 放下/取消时隐藏**

在 `_place_tower()` 成功放置后：

```gdscript
_range_indicator.hide_range()
```

在 `_cancel_placement()` 中：

```gdscript
_range_indicator.hide_range()
```

**Step 5: 手动测试**

通过 Godot 编辑器运行 placement 场景，验证：
1. 选择射手塔时显示蓝色范围圈（radius=300）
2. 选择减速塔时显示范围圈（radius=200）
3. 选择墙塔时不显示范围圈（radius=0）
4. 范围圈跟随鼠标移动
5. 放置或取消后范围圈消失

**Step 6: Commit**

```bash
git add scripts/ui/placement.gd
git commit -m "feat: 预览塔时显示攻击范围圈"
```

---

### Task 4: 点击已有塔显示范围圈

**Files:**
- Modify: `scripts/ui/placement.gd`

**Step 1: 添加选中塔状态变量**

```gdscript
var _selected_placed_tower: Node2D = null
```

**Step 2: 添加 `_find_tower_at()` 辅助方法**

```gdscript
func _find_tower_at(pos: Vector2) -> Node2D:
	var towers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.TOWERS)
	var closest: Node2D = null
	var min_dist: float = GRID_SIZE / 2.0

	for tower in towers:
		if tower == preview_tower:
			continue
		var dist: float = tower.global_position.distance_to(pos)
		if dist < min_dist:
			min_dist = dist
			closest = tower
	return closest
```

**Step 3: 修改 `_input()` 左键点击逻辑**

在左键点击处理中，如果没有 preview_tower，改为检测点击已有塔：

```gdscript
if event is InputEventMouseButton and event.pressed:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if preview_tower:
			_place_tower()
		else:
			# 点击已有塔：显示范围圈
			var clicked_tower: Node2D = _find_tower_at(get_global_mouse_position())
			if clicked_tower:
				_select_placed_tower(clicked_tower)
			else:
				_deselect_tower()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if preview_tower:
			_cancel_placement()
		# （Task 5 会添加右键移除逻辑）
```

**Step 4: 添加 `_select_placed_tower()` 和 `_deselect_tower()`**

```gdscript
func _select_placed_tower(tower: Node2D) -> void:
	_selected_placed_tower = tower
	if tower.data and tower.data.attack_range > 0:
		_range_indicator.global_position = tower.global_position
		_range_indicator.set_range(tower.data.attack_range)
	else:
		_range_indicator.hide_range()

func _deselect_tower() -> void:
	_selected_placed_tower = null
	_range_indicator.hide_range()
```

**Step 5: 在 `_select_tower()` 中调用 `_deselect_tower()`**

已在 Task 3 Step 2 中添加。确认 `_select_tower()` 开头调用 `_deselect_tower()` 清除已选中塔的高亮。

**Step 6: 添加测试**

在 `tests/unit/test_placement_grid_rules.gd` 中追加：

```gdscript
func test_find_tower_at_returns_closest_tower():
	# 在 (105, 105) 放一个塔（对齐到网格中心）
	var tower = SceneFactory.create_tower(Enums.TowerId.SHOOTER)
	tower.global_position = Vector2(105, 105)
	tower.add_to_group(Enums.Group.TOWERS)
	placement.add_child(tower)

	var found = placement._find_tower_at(Vector2(110, 110))
	assert_eq(found, tower, "应找到最近的塔")

func test_find_tower_at_returns_null_when_too_far():
	var tower = SceneFactory.create_tower(Enums.TowerId.SHOOTER)
	tower.global_position = Vector2(105, 105)
	tower.add_to_group(Enums.Group.TOWERS)
	placement.add_child(tower)

	var found = placement._find_tower_at(Vector2(300, 300))
	assert_null(found, "距离太远应返回 null")
```

**Step 7: Run tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_placement_grid_rules.gd -gexit`
Expected: PASS

**Step 8: Commit**

```bash
git add scripts/ui/placement.gd tests/unit/test_placement_grid_rules.gd
git commit -m "feat: 点击已放置的塔显示攻击范围圈"
```

---

### Task 5: 放置合法性颜色反馈

**Files:**
- Modify: `scripts/ui/placement.gd`

**Step 1: 修改 `_input()` 鼠标移动处理**

在 `InputEventMouseMotion` 处理中，更新预览塔颜色：

```gdscript
if event is InputEventMouseMotion and preview_tower:
	var grid_pos: Vector2 = _get_grid_position(get_global_mouse_position())
	preview_tower.global_position = grid_pos
	_range_indicator.global_position = grid_pos

	# 合法性颜色反馈
	if _can_place_at(grid_pos):
		preview_tower.modulate = Color(1, 1, 1, 0.5)
	else:
		preview_tower.modulate = Color(1, 0.3, 0.3, 0.5)
```

**Step 2: 手动测试**

通过 Godot 编辑器运行，验证：
1. 鼠标在空地上：预览塔正常半透明白色
2. 鼠标在已有塔旁（重叠距离内）：预览塔变红
3. 鼠标在地图边界外：预览塔变红
4. 鼠标在玩家位置：预览塔变红

**Step 3: Commit**

```bash
git add scripts/ui/placement.gd
git commit -m "feat: 预览塔放置合法性颜色反馈"
```

---

### Task 6: 右键移除已放置的塔

**Files:**
- Modify: `scripts/ui/placement.gd`
- Test: `tests/unit/test_placement_grid_rules.gd`

**Step 1: Write the failing test**

在 `tests/unit/test_placement_grid_rules.gd` 追加：

```gdscript
func test_remove_tower_refunds_coins():
	GameData.coins = 60

	# 手动放置一个塔
	var tower = SceneFactory.create_tower(Enums.TowerId.SHOOTER)
	tower.global_position = Vector2(105, 105)
	tower.add_to_group(Enums.Group.TOWERS)
	placement.add_child(tower)

	var cost: int = SceneFactory.get_tower_cost(Enums.TowerId.SHOOTER)
	placement._remove_tower_at(Vector2(110, 110))

	assert_eq(GameData.coins, 60 + cost, "移除塔应退还金币")

func test_remove_tower_at_empty_does_nothing():
	GameData.coins = 60
	placement._remove_tower_at(Vector2(300, 300))
	assert_eq(GameData.coins, 60, "空位置不应改变金币")
```

**Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_placement_grid_rules.gd -gexit`
Expected: FAIL — `_remove_tower_at` not found

**Step 3: Implement `_remove_tower_at()`**

在 `placement.gd` 中添加：

```gdscript
func _remove_tower_at(pos: Vector2) -> void:
	var tower: Node2D = _find_tower_at(pos)
	if not tower:
		return

	var cost: int = SceneFactory.get_tower_cost(tower.tower_type)
	GameData.coins += cost
	tower.queue_free()
	_deselect_tower()
	_update_ui()
```

**Step 4: 修改 `_input()` 右键逻辑**

```gdscript
elif event.button_index == MOUSE_BUTTON_RIGHT:
	if preview_tower:
		_cancel_placement()
	else:
		_remove_tower_at(get_global_mouse_position())
```

**Step 5: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_placement_grid_rules.gd -gexit`
Expected: PASS

**Step 6: Run all tests to verify no regressions**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: All tests PASS

**Step 7: Commit**

```bash
git add scripts/ui/placement.gd tests/unit/test_placement_grid_rules.gd
git commit -m "feat: 右键移除已放置的塔并退还金币"
```

---

### Task 7: 全量回归测试 + 手动验收

**Step 1: Run all unit and integration tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: All tests PASS (原 161 + 新增测试)

**Step 2: 手动验收清单**

运行 placement 场景，逐项验证：

- [ ] 全地图网格线始终可见，淡色不干扰背景
- [ ] 选择射手塔：蓝色范围圈（300px）跟随鼠标
- [ ] 选择减速塔：蓝色范围圈（200px）跟随鼠标
- [ ] 选择墙塔：无范围圈
- [ ] 放置后范围圈消失
- [ ] 取消放置后范围圈消失
- [ ] 预览塔在合法位置显示白色半透明
- [ ] 预览塔在非法位置（重叠/出界/玩家位置）显示红色半透明
- [ ] 左键点击已放置的塔显示其范围圈
- [ ] 点击空白处隐藏范围圈
- [ ] 右键点击已放置的塔：移除塔 + 退还金币
- [ ] 右键点击空白处：无事发生
- [ ] 开始战斗按钮正常工作

**Step 3: Final commit (if any fixups needed)**

```bash
git commit -m "fix: 布置交互优化修复"
```
