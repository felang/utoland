# 商店-战斗场景融合 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将独立的商店场景与战斗场景合并为一个统一场景，通过底部面板覆盖层提供商店功能，塔的布置和移动直接在真实地图上拖拽完成。

**Architecture:** main.gd 新增 Phase 状态机（SHOP/BATTLE）。新增 ShopOverlay（CanvasLayer 底部面板）和 DragManager（统一拖拽管理）。GameData 引入 deploy_id 稳定标识符（从 1 开始，0 表示失败）。删除独立 shop 场景。

**Tech Stack:** Godot 4.6 / GDScript / GUT 测试框架

**Spec:** `docs/superpowers/specs/2026-03-14-shop-battle-fusion-design.md`

---

## Chunk 1: 数据层 + 基础设施改动

### Task 1: EventBus — 新增 tower_moved 信号

**Files:**
- Modify: `scripts/core/event_bus.gd`

**背景：** Task 2 的 `move_tower()` 方法会 emit 此信号，必须先声明。

- [ ] **Step 1: 添加 tower_moved 信号声明**

在 `scripts/core/event_bus.gd` 的 shop 信号区域（约第 37 行后）追加：

```gdscript
signal tower_moved(deploy_id: int, old_pos: Vector2i, new_pos: Vector2i)
```

- [ ] **Step 2: 运行全部测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 所有测试 PASS

- [ ] **Step 3: Commit**

```bash
git add scripts/core/event_bus.gd
git commit -m "feat: EventBus 新增 tower_moved 信号"
```

---

### Task 2: GameData — deploy_id 系统 + move_tower + 接口改造

**Files:**
- Modify: `scripts/core/game_data.gd`
- Modify: `tests/unit/test_game_data_economy.gd`（已有，修改 + 追加测试）

**背景：** 当前 `deployed_towers` 条目格式为 `{id, level, grid_pos}`。需要新增 `deploy_id` 字段（从 1 开始，0 表示失败——GDScript 中 0 为 falsy，非零为 truthy，这样现有 `if deploy_tower(...)` 模式仍然正确）。`deploy_tower()` 返回值从 `bool` 改为 `int`。`undeploy_tower()` 和 `sell_from_deployed_tower()` 参数从数组索引改为 `deploy_id`。新增 `move_tower()` 方法。

**参考现有代码：**
- `game_data.gd:36` — `var deployed_towers: Array[Dictionary] = []`
- `game_data.gd:76-99` — `_DEFAULTS` 字典（reset 用）
- `game_data.gd:121-149` — `reset()` 方法（通过 `_DEFAULTS` 批量重置）
- `game_data.gd:212-225` — `deploy_tower()` 返回 `bool`
- `game_data.gd:227-235` — `undeploy_tower(deploy_index: int) -> void`
- `game_data.gd:254-260` — `sell_from_deployed_tower(deploy_index: int) -> int`

#### Part A: deploy_id 系统 + deploy_tower 返回值改造

- [ ] **Step 1: 写 deploy_id 失败测试**

在 `tests/unit/test_game_data_economy.gd` 末尾追加：

```gdscript
# --- deploy_id 系统测试 ---

func test_deploy_tower_returns_deploy_id() -> void:
	GameData.player_level = 2
	GameData.bag.append({id = "pea_shooter", type = "tower", level = 1})
	var deploy_id: int = GameData.deploy_tower(0, Vector2i(5, 5))
	assert_gt(deploy_id, 0, "deploy_tower 应返回 > 0 的 deploy_id")
	assert_eq(GameData.deployed_towers[0].deploy_id, deploy_id)

func test_deploy_tower_increments_deploy_id() -> void:
	GameData.player_level = 3
	GameData.bag.append({id = "pea_shooter", type = "tower", level = 1})
	GameData.bag.append({id = "stump", type = "tower", level = 1})
	var id1: int = GameData.deploy_tower(0, Vector2i(5, 5))
	var id2: int = GameData.deploy_tower(0, Vector2i(10, 10))
	assert_ne(id1, id2, "每次 deploy 应分配不同的 deploy_id")
	assert_gt(id2, id1, "deploy_id 应递增")

func test_deploy_tower_failure_returns_zero() -> void:
	# 背包为空，部署应失败
	var deploy_id: int = GameData.deploy_tower(0, Vector2i(5, 5))
	assert_eq(deploy_id, 0, "失败时应返回 0")

func test_reset_clears_deploy_id_counter() -> void:
	GameData.player_level = 2
	GameData.bag.append({id = "pea_shooter", type = "tower", level = 1})
	GameData.deploy_tower(0, Vector2i(5, 5))
	GameData.reset()
	GameData.player_level = 2
	GameData.bag.append({id = "pea_shooter", type = "tower", level = 1})
	var deploy_id: int = GameData.deploy_tower(0, Vector2i(5, 5))
	assert_eq(deploy_id, 1, "reset 后 deploy_id 应从 1 重新开始")
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_game_data_economy.gd`
Expected: 新增的 4 个测试 FAIL

- [ ] **Step 3: 实现 deploy_id 系统**

修改 `scripts/core/game_data.gd`：

1. 在变量声明区（约第 50 行后）新增：
```gdscript
var _next_deploy_id: int = 1
```

2. 在 `reset()` 方法末尾（第 149 行后）新增：
```gdscript
	_next_deploy_id = 1
```

3. 修改 `deploy_tower()` 方法（第 212-225 行）：
```gdscript
func deploy_tower(bag_index: int, grid_pos: Vector2i) -> int:
	if not can_deploy():
		return 0
	if bag_index < 0 or bag_index >= bag.size():
		return 0
	var item: Dictionary = bag[bag_index]
	if item.type != "tower":
		return 0
	bag.remove_at(bag_index)
	var deploy_id := _next_deploy_id
	_next_deploy_id += 1
	deployed_towers.append({id = item.id, level = item.level, grid_pos = grid_pos, deploy_id = deploy_id})
	EventBus.item_deployed.emit(item)
	_synergy_manager.recalculate()
	_pair_synergy_manager.recalculate()
	return deploy_id
```

4. 修改 `test_deploy_tower_success` 测试（第 169-178 行），将 `var result: bool` 改为 `var result: int` 并将 `assert_true(result)` 改为 `assert_gt(result, 0)`：
```gdscript
func test_deploy_tower_success() -> void:
	GameData.player_level = 2
	GameData.bag.append({id = "pea_shooter", type = "tower", level = 1})
	var pos := Vector2i(5, 3)
	var result: int = GameData.deploy_tower(0, pos)
	assert_gt(result, 0)
	assert_eq(GameData.bag.size(), 0)
	assert_eq(GameData.deployed_towers.size(), 1)
	assert_eq(GameData.deployed_towers[0].id, "pea_shooter")
	assert_eq(GameData.deployed_towers[0].grid_pos, pos)
```

5. 修改 `test_deploy_tower_fails_wrong_type` 测试（第 180-185 行），将 `var result: bool` 改为 `var result: int` 并将 `assert_false(result)` 改为 `assert_eq(result, 0)`：
```gdscript
func test_deploy_tower_fails_wrong_type() -> void:
	GameData.player_level = 2
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	var result: int = GameData.deploy_tower(0, Vector2i(0, 0))
	assert_eq(result, 0)
	assert_eq(GameData.bag.size(), 1)
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_game_data_economy.gd`
Expected: 所有 deploy_tower 测试 PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/core/game_data.gd tests/unit/test_game_data_economy.gd
git commit -m "feat: GameData deploy_id 系统 — deploy_tower 返回 deploy_id"
```

#### Part B: undeploy_tower 改造（接受 deploy_id）

- [ ] **Step 6: 修改 undeploy_tower 测试为 deploy_id 版本**

修改 `tests/unit/test_game_data_economy.gd` 中已有的 undeploy_tower 测试（第 189-199 行）并追加新测试：

```gdscript
func test_undeploy_tower_success() -> void:
	GameData.player_level = 2
	GameData.bag.append({id = "pea_shooter", type = "tower", level = 1})
	var deploy_id: int = GameData.deploy_tower(0, Vector2i(2, 2))
	var result: bool = GameData.undeploy_tower(deploy_id)
	assert_true(result)
	assert_eq(GameData.deployed_towers.size(), 0)
	assert_eq(GameData.bag.size(), 1)
	assert_eq(GameData.bag[0].id, "pea_shooter")
	assert_eq(GameData.bag[0].type, "tower")

func test_undeploy_tower_invalid_deploy_id() -> void:
	var result: bool = GameData.undeploy_tower(999)
	assert_false(result)
	assert_eq(GameData.deployed_towers.size(), 0)

func test_undeploy_tower_correct_item_when_multiple() -> void:
	GameData.player_level = 3
	GameData.bag.append({id = "pea_shooter", type = "tower", level = 1})
	GameData.bag.append({id = "stump", type = "tower", level = 1})
	var id1: int = GameData.deploy_tower(0, Vector2i(5, 5))
	var id2: int = GameData.deploy_tower(0, Vector2i(10, 10))
	# 收回第一个塔
	GameData.undeploy_tower(id1)
	assert_eq(GameData.deployed_towers.size(), 1)
	assert_eq(GameData.deployed_towers[0].deploy_id, id2, "剩余的应该是第二个塔")
```

- [ ] **Step 7: 运行测试确认失败**

Run: 同 Step 2 命令
Expected: undeploy_tower 测试 FAIL（旧签名接受数组索引，新测试传 deploy_id）

- [ ] **Step 8: 改造 undeploy_tower 方法**

修改 `scripts/core/game_data.gd` 中的 `undeploy_tower()`（第 227-235 行）：

```gdscript
func undeploy_tower(deploy_id: int) -> bool:
	var tower_index := -1
	for i in range(deployed_towers.size()):
		if deployed_towers[i].deploy_id == deploy_id:
			tower_index = i
			break
	if tower_index == -1:
		return false
	var item: Dictionary = deployed_towers[tower_index]
	deployed_towers.remove_at(tower_index)
	bag.append({id = item.id, type = "tower", level = item.level})
	EventBus.item_undeployed.emit(item)
	_synergy_manager.recalculate()
	_pair_synergy_manager.recalculate()
	return true
```

- [ ] **Step 9: 运行测试确认通过**

Run: 同 Step 2 命令
Expected: 所有 undeploy_tower 测试 PASS

- [ ] **Step 10: Commit**

```bash
git add scripts/core/game_data.gd tests/unit/test_game_data_economy.gd
git commit -m "refactor: undeploy_tower 改为接受 deploy_id"
```

#### Part C: sell_from_deployed_tower 改造

- [ ] **Step 11: 修改 sell_from_deployed_tower 测试为 deploy_id 版本**

修改 `tests/unit/test_game_data_economy.gd` 中已有的 sell_from_deployed_tower 测试（第 254-267 行）：

```gdscript
func test_sell_from_deployed_tower() -> void:
	# pea_shooter lv1 sell_price = 3
	GameData.player_level = 2
	GameData.bag.append({id = "pea_shooter", type = "tower", level = 1})
	var deploy_id: int = GameData.deploy_tower(0, Vector2i(0, 0))
	var initial_coins: int = GameData.coins
	var refund: int = GameData.sell_from_deployed_tower(deploy_id)
	assert_eq(refund, 3)
	assert_eq(GameData.coins, initial_coins + 3)
	assert_eq(GameData.deployed_towers.size(), 0)

func test_sell_from_deployed_tower_invalid_deploy_id() -> void:
	var initial_coins: int = GameData.coins
	var refund: int = GameData.sell_from_deployed_tower(999)
	assert_eq(refund, 0)
	assert_eq(GameData.coins, initial_coins)
```

- [ ] **Step 12: 运行测试确认失败**

Run: 同 Step 2 命令
Expected: sell_from_deployed_tower 测试 FAIL

- [ ] **Step 13: 改造 sell_from_deployed_tower 方法**

修改 `scripts/core/game_data.gd` 中的 `sell_from_deployed_tower()`（第 254-260 行）：

```gdscript
func sell_from_deployed_tower(deploy_id: int) -> int:
	var tower_index := -1
	for i in range(deployed_towers.size()):
		if deployed_towers[i].deploy_id == deploy_id:
			tower_index = i
			break
	if tower_index == -1:
		return 0
	var entry: Dictionary = deployed_towers[tower_index]
	deployed_towers.remove_at(tower_index)
	var item := {id = entry.id, type = "tower", level = entry.level}
	return _apply_sell(item)
```

- [ ] **Step 14: 运行测试确认通过**

Run: 同 Step 2 命令
Expected: 所有 sell_from_deployed_tower 测试 PASS

- [ ] **Step 15: Commit**

```bash
git add scripts/core/game_data.gd tests/unit/test_game_data_economy.gd
git commit -m "refactor: sell_from_deployed_tower 改为接受 deploy_id"
```

#### Part D: move_tower 新增

- [ ] **Step 16: 写 move_tower 失败测试**

在 `tests/unit/test_game_data_economy.gd` 末尾追加：

```gdscript
# --- move_tower 测试 ---

func test_move_tower_success() -> void:
	GameData.player_level = 2
	GameData.bag.append({id = "pea_shooter", type = "tower", level = 1})
	var deploy_id: int = GameData.deploy_tower(0, Vector2i(5, 5))
	var result: bool = GameData.move_tower(deploy_id, Vector2i(10, 10))
	assert_true(result, "move 应成功")
	assert_eq(GameData.deployed_towers[0].grid_pos, Vector2i(10, 10))

func test_move_tower_invalid_id() -> void:
	var result: bool = GameData.move_tower(999, Vector2i(10, 10))
	assert_false(result, "无效 deploy_id 应返回 false")

func test_move_tower_occupied() -> void:
	GameData.player_level = 3
	GameData.bag.append({id = "pea_shooter", type = "tower", level = 1})
	GameData.bag.append({id = "stump", type = "tower", level = 1})
	GameData.deploy_tower(0, Vector2i(5, 5))
	var id2: int = GameData.deploy_tower(0, Vector2i(10, 10))
	var result: bool = GameData.move_tower(id2, Vector2i(5, 5))
	assert_false(result, "目标位置被占用应返回 false")

func test_move_tower_out_of_bounds() -> void:
	GameData.player_level = 2
	GameData.bag.append({id = "pea_shooter", type = "tower", level = 1})
	var deploy_id: int = GameData.deploy_tower(0, Vector2i(5, 5))
	var result: bool = GameData.move_tower(deploy_id, Vector2i(-1, 5))
	assert_false(result, "越界应返回 false")
	result = GameData.move_tower(deploy_id, Vector2i(GameConfig.MAP_GRID_WIDTH, 5))
	assert_false(result, "越界应返回 false")

func test_move_tower_same_position() -> void:
	GameData.player_level = 2
	GameData.bag.append({id = "pea_shooter", type = "tower", level = 1})
	var deploy_id: int = GameData.deploy_tower(0, Vector2i(5, 5))
	var result: bool = GameData.move_tower(deploy_id, Vector2i(5, 5))
	assert_true(result, "移动到原位应成功")
```

- [ ] **Step 17: 运行测试确认失败**

Run: 同 Step 2 命令
Expected: 新增的 5 个测试 FAIL

- [ ] **Step 18: 实现 move_tower 方法**

在 `scripts/core/game_data.gd` 的 `undeploy_tower()` 之后新增：

```gdscript
func move_tower(deploy_id: int, new_grid_pos: Vector2i) -> bool:
	if new_grid_pos.x < 0 or new_grid_pos.x >= GameConfig.MAP_GRID_WIDTH:
		return false
	if new_grid_pos.y < 0 or new_grid_pos.y >= GameConfig.MAP_GRID_HEIGHT:
		return false
	var tower_index := -1
	for i in range(deployed_towers.size()):
		if deployed_towers[i].deploy_id == deploy_id:
			tower_index = i
			break
	if tower_index == -1:
		return false
	# 检查目标位置是否被占用（排除自身）
	for i in range(deployed_towers.size()):
		if i != tower_index and deployed_towers[i].grid_pos == new_grid_pos:
			return false
	var old_pos: Vector2i = deployed_towers[tower_index].grid_pos
	deployed_towers[tower_index].grid_pos = new_grid_pos
	EventBus.tower_moved.emit(deploy_id, old_pos, new_grid_pos)
	return true
```

- [ ] **Step 19: 运行测试确认通过**

Run: 同 Step 2 命令
Expected: 所有 move_tower 测试 PASS

- [ ] **Step 20: 运行全部 game_data 测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_game_data_economy.gd`
Expected: 所有测试 PASS（含已有测试和新增测试）

- [ ] **Step 21: Commit**

```bash
git add scripts/core/game_data.gd tests/unit/test_game_data_economy.gd
git commit -m "feat: GameData 新增 move_tower 方法"
```

---

### Task 3: WaveManager — 移除自动启动

**Files:**
- Modify: `scripts/systems/wave_manager.gd`
- Modify: `tests/unit/test_wave_manager.gd`（如有）

**背景：** 当前 `wave_manager.gd` 的 `_ready()`（第 14-26 行）末尾调用 `start_next_wave()`。新设计中 main.gd 在 SHOP → BATTLE 切换时显式调用。

- [ ] **Step 1: 检查现有测试中对 _ready 自动启动的依赖**

Run: `grep -n "start_next_wave\|_ready" tests/unit/test_wave_manager.gd` （如果文件存在）

查看哪些测试假设波次在 `_ready()` 后已自动启动。

- [ ] **Step 2: 移除 _ready() 中的 start_next_wave() 调用**

在 `scripts/systems/wave_manager.gd` 的 `_ready()` 方法中，删除最后一行的 `start_next_wave()` 调用。保留其他初始化逻辑（信号连接、加载波次数据等）。

- [ ] **Step 3: 修复受影响的测试**

如果有测试依赖 `_ready()` 自动启动波次，在这些测试的 setup 中显式调用 `wave_manager.start_next_wave()`。

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 所有测试 PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/systems/wave_manager.gd tests/unit/test_wave_manager.gd
git commit -m "refactor: WaveManager 移除 _ready() 自动启动波次"
```

---

### Task 4: SceneManager — 移除 shop 路由 + Player 输入控制

**Files:**
- Modify: `scripts/core/scene_manager.gd`
- Modify: `scripts/entities/player.gd`

**背景：** SceneManager 的 `SCENES` 和 `SCENE_BGM` 字典中有 `"shop"` 条目需要移除。Player 需要新增 `set_input_enabled()` 方法供 DragManager 在拖拽时屏蔽移动。

- [ ] **Step 1: 移除 shop 相关条目**

在 `scripts/core/scene_manager.gd` 中：
- 从 `SCENES` 字典中删除 `"shop"` 条目
- 从 `SCENE_BGM` 字典中删除 `"shop"` 条目

- [ ] **Step 2: Player 新增输入控制**

在 `scripts/entities/player.gd` 中新增：

```gdscript
var _input_enabled := true

func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
```

在 `_physics_process()` 方法的移动输入获取逻辑前添加守卫：

```gdscript
func _physics_process(delta: float) -> void:
	if not _input_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# ... 现有移动逻辑
```

- [ ] **Step 3: 运行测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 所有测试 PASS

- [ ] **Step 4: Commit**

```bash
git add scripts/core/scene_manager.gd scripts/entities/player.gd
git commit -m "refactor: 移除 shop 路由 + Player 输入控制开关"
```

---

### Task 5: SynergyEffectProcessor — activate/deactivate 方法

**Files:**
- Modify: `scripts/systems/synergy_effect_processor.gd`

**背景：** 当前 SynergyEffectProcessor 在 `_ready()` 后始终运行 `_process()`。需要新增 `activate()`/`deactivate()` 方法，SHOP 阶段不运行机制效果。

- [ ] **Step 1: 添加 activate/deactivate 方法**

在 `scripts/systems/synergy_effect_processor.gd` 中：

1. 在变量声明区新增：
```gdscript
var _is_active := false
```

2. 新增方法：
```gdscript
func activate() -> void:
	_is_active = true

func deactivate() -> void:
	_is_active = false
```

3. 修改 `_process()` 方法（约第 45 行），在开头加入守卫：
```gdscript
func _process(delta: float) -> void:
	if not _is_active:
		return
	# ... 现有 _process 逻辑不变
```

- [ ] **Step 2: 运行测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 所有测试 PASS

- [ ] **Step 3: Commit**

```bash
git add scripts/systems/synergy_effect_processor.gd
git commit -m "feat: SynergyEffectProcessor activate/deactivate 生命周期控制"
```

---

## Chunk 2: DragManager 拖拽系统

### Task 6: DragManager — 统一拖拽管理器

**Files:**
- Create: `scripts/systems/drag_manager.gd`
- Create: `tests/unit/test_drag_manager.gd`

**背景：** DragManager 是 Main 场景的子节点，管理所有拖拽操作。它持有 TowerContainer 和 Player 的引用，维护 `_tower_nodes`（deploy_id → 塔节点）映射。

- [ ] **Step 1: 写 DragManager 工具方法的失败测试**

创建 `tests/unit/test_drag_manager.gd`：

```gdscript
extends GutTest

var _drag_manager: Node
var _tower_container: Node2D

func before_each() -> void:
	GameData.reset()
	GameData.coins = 50
	GameData.player_level = 5
	_tower_container = Node2D.new()
	add_child(_tower_container)
	_drag_manager = load("res://scripts/systems/drag_manager.gd").new()
	_drag_manager._tower_container = _tower_container
	add_child(_drag_manager)

func after_each() -> void:
	_drag_manager.queue_free()
	_tower_container.queue_free()

func test_grid_to_world_conversion() -> void:
	var world: Vector2 = _drag_manager._grid_to_world(Vector2i(5, 5))
	var expected := Vector2(5 * 16 + 8, 5 * 16 + 8)
	assert_eq(world, expected)

func test_world_to_grid_conversion() -> void:
	var grid: Vector2i = _drag_manager._world_to_grid(Vector2(88, 88))
	assert_eq(grid, Vector2i(5, 5))

func test_is_valid_grid_pos() -> void:
	assert_true(_drag_manager._is_valid_grid_pos(Vector2i(0, 0)))
	assert_true(_drag_manager._is_valid_grid_pos(Vector2i(39, 24)))
	assert_false(_drag_manager._is_valid_grid_pos(Vector2i(-1, 0)))
	assert_false(_drag_manager._is_valid_grid_pos(Vector2i(40, 0)))
	assert_false(_drag_manager._is_valid_grid_pos(Vector2i(0, 25)))

func test_is_grid_available_empty() -> void:
	assert_true(_drag_manager._is_grid_available(Vector2i(5, 5)))

func test_is_grid_available_occupied() -> void:
	GameData.bag.append({id = "pea_shooter", type = "tower", level = 1})
	GameData.deploy_tower(0, Vector2i(5, 5))
	assert_false(_drag_manager._is_grid_available(Vector2i(5, 5)))
	assert_true(_drag_manager._is_grid_available(Vector2i(6, 6)))

func test_spawn_tower_node() -> void:
	GameData.bag.append({id = "pea_shooter", type = "tower", level = 1})
	var deploy_id: int = GameData.deploy_tower(0, Vector2i(5, 5))
	_drag_manager._spawn_tower_node(deploy_id, "pea_shooter", 1, Vector2i(5, 5))
	assert_true(deploy_id in _drag_manager._tower_nodes)
	assert_eq(_tower_container.get_child_count(), 1)

func test_remove_tower_node() -> void:
	GameData.bag.append({id = "pea_shooter", type = "tower", level = 1})
	var deploy_id: int = GameData.deploy_tower(0, Vector2i(5, 5))
	_drag_manager._spawn_tower_node(deploy_id, "pea_shooter", 1, Vector2i(5, 5))
	_drag_manager._remove_tower_node(deploy_id)
	assert_false(deploy_id in _drag_manager._tower_nodes)

func test_remove_tower_nodes_batch() -> void:
	GameData.bag.append({id = "pea_shooter", type = "tower", level = 1})
	GameData.bag.append({id = "stump", type = "tower", level = 1})
	var id1: int = GameData.deploy_tower(0, Vector2i(5, 5))
	var id2: int = GameData.deploy_tower(0, Vector2i(10, 10))
	_drag_manager._spawn_tower_node(id1, "pea_shooter", 1, Vector2i(5, 5))
	_drag_manager._spawn_tower_node(id2, "stump", 1, Vector2i(10, 10))
	_drag_manager.remove_tower_nodes([id1, id2])
	assert_eq(_drag_manager._tower_nodes.size(), 0)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_drag_manager.gd`
Expected: FAIL（脚本不存在）

- [ ] **Step 3: 创建 DragManager 脚本**

创建 `scripts/systems/drag_manager.gd`：

```gdscript
extends Node
## 统一拖拽管理器 — 管理背包物品部署和地图上塔的移动

enum DragSource { NONE, BAG_TOWER, BAG_WEAPON, MAP_TOWER }

const WEAPON_EQUIP_RADIUS := 48.0

var _tower_container: Node2D
var _player: Node2D
var _shop_overlay: CanvasLayer

var _is_dragging := false
var _drag_source: DragSource = DragSource.NONE
var _drag_data: Dictionary = {}
var _tower_nodes: Dictionary = {}  # deploy_id → Node2D

var _preview_node: Node2D = null
var _range_circle: Node2D = null

var _drag_original_grid_pos: Vector2i
var _drag_original_deploy_id: int = -1

func initialize(tower_container: Node2D, player: Node2D, shop_overlay: CanvasLayer) -> void:
	_tower_container = tower_container
	_player = player
	_shop_overlay = shop_overlay
	shop_overlay.bag_item_drag_started.connect(_on_bag_item_drag_started)

func _on_bag_item_drag_started(bag_index: int, item: Dictionary) -> void:
	if _is_dragging:
		return
	_drag_data = {bag_index = bag_index, item = item}
	if item.type == "tower":
		_start_drag(DragSource.BAG_TOWER)
	elif item.type == "weapon":
		_start_drag(DragSource.BAG_WEAPON)

func start_map_tower_drag(deploy_id: int) -> void:
	if _is_dragging:
		return
	if deploy_id not in _tower_nodes:
		return
	for entry in GameData.deployed_towers:
		if entry.deploy_id == deploy_id:
			_drag_data = {deploy_id = deploy_id, item = entry}
			_drag_original_deploy_id = deploy_id
			_drag_original_grid_pos = entry.grid_pos
			_start_drag(DragSource.MAP_TOWER)
			_tower_nodes[deploy_id].modulate.a = 0.3
			break

func _start_drag(source: DragSource) -> void:
	_is_dragging = true
	_drag_source = source
	_create_preview()
	if _player and _player.has_method("set_input_enabled"):
		_player.set_input_enabled(false)

func _input(event: InputEvent) -> void:
	if not _is_dragging:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_check_tower_click(event.global_position)
		return

	if event is InputEventMouseMotion:
		_update_preview(event.global_position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_drag(event.global_position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_drag()

func _check_tower_click(global_pos: Vector2) -> void:
	for deploy_id in _tower_nodes:
		var tower_node: Node2D = _tower_nodes[deploy_id]
		if tower_node.global_position.distance_to(global_pos) < GameConfig.GRID_SIZE:
			start_map_tower_drag(deploy_id)
			break

func _end_drag(global_pos: Vector2) -> void:
	match _drag_source:
		DragSource.BAG_TOWER:
			_try_deploy_tower(global_pos)
		DragSource.BAG_WEAPON:
			_try_equip_weapon(global_pos)
		DragSource.MAP_TOWER:
			_try_move_or_undeploy_tower(global_pos)
	_cleanup_drag()

func _cancel_drag() -> void:
	if _drag_source == DragSource.MAP_TOWER and _drag_original_deploy_id >= 0:
		if _drag_original_deploy_id in _tower_nodes:
			_tower_nodes[_drag_original_deploy_id].modulate.a = 1.0
	_cleanup_drag()

func _cleanup_drag() -> void:
	_is_dragging = false
	_drag_source = DragSource.NONE
	_drag_data = {}
	_drag_original_deploy_id = -1
	if _preview_node:
		_preview_node.queue_free()
		_preview_node = null
	if _range_circle:
		_range_circle.queue_free()
		_range_circle = null
	if _player and _player.has_method("set_input_enabled"):
		_player.set_input_enabled(true)

# --- 部署塔 ---

func _try_deploy_tower(global_pos: Vector2) -> void:
	var grid_pos := _world_to_grid(global_pos)
	if not _is_valid_grid_pos(grid_pos) or not _is_grid_available(grid_pos):
		return
	var bag_index: int = _drag_data.bag_index
	var item: Dictionary = _drag_data.item
	var deploy_id: int = GameData.deploy_tower(bag_index, grid_pos)
	if deploy_id > 0:
		_spawn_tower_node(deploy_id, item.id, item.level, grid_pos)
		_shop_overlay._update_ui()

# --- 装备武器 ---

func _try_equip_weapon(global_pos: Vector2) -> void:
	if _player == null:
		return
	var distance := global_pos.distance_to(_player.global_position)
	if distance <= WEAPON_EQUIP_RADIUS:
		var bag_index: int = _drag_data.bag_index
		GameData.deploy_weapon(bag_index)
		_shop_overlay._update_ui()

# --- 移动/收回塔 ---

func _try_move_or_undeploy_tower(global_pos: Vector2) -> void:
	var deploy_id: int = _drag_data.deploy_id
	# 拖到面板区域 → 收回背包
	if _is_over_panel(global_pos):
		if GameData.undeploy_tower(deploy_id):
			_remove_tower_node(deploy_id)
			_shop_overlay._update_ui()
			return
	# 尝试移动到新位置
	var grid_pos := _world_to_grid(global_pos)
	if _is_valid_grid_pos(grid_pos) and _is_grid_available(grid_pos):
		if GameData.move_tower(deploy_id, grid_pos):
			_tower_nodes[deploy_id].position = _grid_to_world(grid_pos)
			_tower_nodes[deploy_id].modulate.a = 1.0
			return
	# 移动失败，恢复原位
	if deploy_id in _tower_nodes:
		_tower_nodes[deploy_id].modulate.a = 1.0

# --- 塔节点管理 ---

func _spawn_tower_node(deploy_id: int, tower_id: String, level: int, grid_pos: Vector2i) -> void:
	var tower: Node2D = SceneFactory.create_tower(tower_id, level)
	tower.position = _grid_to_world(grid_pos)
	_tower_container.add_child(tower)
	_tower_nodes[deploy_id] = tower

func _remove_tower_node(deploy_id: int) -> void:
	if deploy_id in _tower_nodes:
		_tower_nodes[deploy_id].queue_free()
		_tower_nodes.erase(deploy_id)

func remove_tower_nodes(consumed_deploy_ids: Array) -> void:
	for deploy_id in consumed_deploy_ids:
		_remove_tower_node(deploy_id)

# --- 预览系统 ---

func _create_preview() -> void:
	_preview_node = Node2D.new()
	var sprite := Sprite2D.new()
	sprite.modulate = Color(1, 1, 1, 0.5)
	_preview_node.add_child(sprite)
	if _drag_source in [DragSource.BAG_TOWER, DragSource.MAP_TOWER]:
		_range_circle = Node2D.new()
		_preview_node.add_child(_range_circle)
	_tower_container.get_parent().add_child(_preview_node)

func _update_preview(global_pos: Vector2) -> void:
	if _preview_node == null:
		return
	if _drag_source in [DragSource.BAG_TOWER, DragSource.MAP_TOWER]:
		var grid_pos := _world_to_grid(global_pos)
		_preview_node.global_position = _grid_to_world(grid_pos)
		var is_valid := _is_valid_grid_pos(grid_pos) and _is_grid_available(grid_pos)
		if _range_circle:
			_range_circle.modulate = Color.GREEN if is_valid else Color.RED
	else:
		_preview_node.global_position = global_pos

# --- 工具方法 ---

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * GameConfig.GRID_SIZE + GameConfig.GRID_SIZE / 2,
		grid_pos.y * GameConfig.GRID_SIZE + GameConfig.GRID_SIZE / 2
	)

func _world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / GameConfig.GRID_SIZE),
		int(world_pos.y / GameConfig.GRID_SIZE)
	)

func _is_valid_grid_pos(grid_pos: Vector2i) -> bool:
	return (grid_pos.x >= 0 and grid_pos.x < GameConfig.MAP_GRID_WIDTH
		and grid_pos.y >= 0 and grid_pos.y < GameConfig.MAP_GRID_HEIGHT)

func _is_grid_available(grid_pos: Vector2i) -> bool:
	for entry in GameData.deployed_towers:
		if entry.grid_pos == grid_pos:
			if _drag_source == DragSource.MAP_TOWER and entry.deploy_id == _drag_original_deploy_id:
				continue
			return false
	return true

func _is_over_panel(global_pos: Vector2) -> bool:
	var panel: PanelContainer = _shop_overlay._panel
	var panel_rect: Rect2 = panel.get_global_rect()
	return panel_rect.has_point(global_pos)
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_drag_manager.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/systems/drag_manager.gd tests/unit/test_drag_manager.gd
git commit -m "feat: DragManager 统一拖拽管理器"
```

---

## Chunk 3: ShopOverlay UI + Main 集成 + 清理

### Task 7: ShopOverlay — 底部面板 UI

**Files:**
- Create: `scripts/ui/shop_overlay.gd`
- Create: `scenes/ui/shop_overlay.tscn`
- Create: `tests/unit/test_shop_overlay.gd`

**背景：** 从现有 `shop.gd` 迁移核心购买/刷新/升级逻辑。ShopOverlay 是 CanvasLayer（layer=10），底部面板。不再包含地图区域和装备面板。

- [ ] **Step 1: 创建 shop_overlay.gd 和 shop_overlay.tscn**

先创建脚本和场景，再写测试（因为测试需要 `load()` 场景文件，场景必须先存在）。

创建 `scripts/ui/shop_overlay.gd`：

```gdscript
extends CanvasLayer
## 底部商店面板覆盖层

signal start_battle_pressed
signal bag_item_drag_started(bag_index: int, item: Dictionary)

const SLIDE_DURATION := 0.3

var _shop_manager: ShopManager
var _panel: PanelContainer
var _slide_original_y: float = 0.0

var _coins_label: Label
var _level_label: Label
var _pop_label: Label
var _wave_label: Label
var _level_up_button: Button
var _refresh_button: Button
var _start_button: Button
var _shop_slots: Array[Button] = []
var _bag_container: HBoxContainer
var _bag_slots: Array[Button] = []

# 由 main.gd 注入
var drag_manager: Node = null

func _ready() -> void:
	layer = 10
	_shop_manager = ShopManager.new()
	_setup_ui()
	_update_ui()

func _setup_ui() -> void:
	_panel = $ShopPanel
	_slide_original_y = _panel.position.y
	_coins_label = $ShopPanel/TopRow/CoinsLabel
	_level_label = $ShopPanel/TopRow/LevelLabel
	_pop_label = $ShopPanel/TopRow/PopLabel
	_wave_label = $ShopPanel/TopRow/WaveLabel
	_level_up_button = $ShopPanel/TopRow/LevelUpButton
	_refresh_button = $ShopPanel/TopRow/RefreshButton
	_start_button = $ShopPanel/TopRow/StartButton
	_bag_container = $ShopPanel/BagRow

	_level_up_button.pressed.connect(_on_level_up_pressed)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	_start_button.pressed.connect(_on_start_pressed)

	for i in range(4):
		var slot: Button = $ShopPanel/ShopRow.get_child(i)
		slot.pressed.connect(_on_shop_slot_pressed.bind(i))
		_shop_slots.append(slot)

func refresh_shop(is_first: bool = false) -> void:
	_shop_manager.refresh_shop(is_first)
	_update_ui()

func _update_ui() -> void:
	_update_info_bar()
	_update_shop_slots_display()
	_update_bag_display()
	_update_level_up_button()

func _update_info_bar() -> void:
	_coins_label.text = "$%d" % GameData.coins
	_level_label.text = "Lv.%d" % GameData.player_level
	var pop_current: int = GameData.deployed_weapons.size() + GameData.deployed_towers.size()
	var pop_max: int = GameConfig.shop_config.population_per_level[GameData.player_level - 1]
	_pop_label.text = "人口 %d/%d" % [pop_current, pop_max]
	_wave_label.text = "Wave %d" % GameData.current_wave

func _update_shop_slots_display() -> void:
	for i in range(4):
		if i < GameData.shop_slots.size() and GameData.shop_slots[i] != null:
			var slot_data: Dictionary = GameData.shop_slots[i]
			_shop_slots[i].text = "%s $%d" % [slot_data.display_name, slot_data.cost]
			_shop_slots[i].disabled = false
		else:
			_shop_slots[i].text = "已售出"
			_shop_slots[i].disabled = true

func _update_bag_display() -> void:
	# 移除旧按钮（立即从树上移除再释放）
	for child in _bag_container.get_children():
		_bag_container.remove_child(child)
		child.queue_free()
	_bag_slots.clear()

	var bag_capacity: int = GameConfig.shop_config.bag_capacity
	for i in range(bag_capacity):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(50, 50)
		if i < GameData.bag.size():
			var item: Dictionary = GameData.bag[i]
			var stars := "★".repeat(item.level)
			btn.text = "%s%s" % [item.id, stars]
			btn.gui_input.connect(_on_bag_slot_input.bind(i))
		else:
			btn.text = ""
			btn.disabled = true
		_bag_container.add_child(btn)
		_bag_slots.append(btn)

func _update_level_up_button() -> void:
	var max_level: int = GameConfig.shop_config.level_up_costs.size() + 1
	if GameData.player_level >= max_level:
		_level_up_button.text = "满级"
		_level_up_button.disabled = true
	else:
		var cost: int = GameConfig.shop_config.level_up_costs[GameData.player_level - 1]
		_level_up_button.text = "Lv↑ $%d" % cost
		_level_up_button.disabled = GameData.coins < cost

# --- 事件处理 ---

func _on_shop_slot_pressed(slot_index: int) -> void:
	var snapshot: Array = GameData.deployed_towers.duplicate(true)
	var success: bool = _shop_manager.buy_item(slot_index)
	if success:
		_handle_merge_tower_cleanup(snapshot)
		_update_ui()

func _on_refresh_pressed() -> void:
	_shop_manager.manual_refresh()
	_update_ui()

func _on_level_up_pressed() -> void:
	GameData.buy_level_up()
	_update_ui()

func _on_start_pressed() -> void:
	start_battle_pressed.emit()

func _on_bag_slot_input(event: InputEvent, bag_index: int) -> void:
	if bag_index >= GameData.bag.size():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			GameData.sell_from_bag(bag_index)
			_update_ui()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var item: Dictionary = GameData.bag[bag_index]
			bag_item_drag_started.emit(bag_index, item)

# --- 面板动画 ---

func slide_out() -> void:
	var tween := create_tween()
	var panel_height: float = _panel.size.y
	tween.tween_property(_panel, "position:y", _slide_original_y + panel_height, SLIDE_DURATION)
	tween.tween_callback(func(): _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE)

func slide_in() -> void:
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.position.y = _slide_original_y + _panel.size.y
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", _slide_original_y, SLIDE_DURATION)
	_update_ui()

# --- 合成塔节点清理 ---

func _handle_merge_tower_cleanup(snapshot: Array) -> void:
	if drag_manager == null:
		return
	var current_ids: Array[int] = []
	for entry in GameData.deployed_towers:
		current_ids.append(entry.deploy_id)
	var consumed_ids: Array[int] = []
	for entry in snapshot:
		if entry.deploy_id not in current_ids:
			consumed_ids.append(entry.deploy_id)
	if consumed_ids.size() > 0:
		drag_manager.remove_tower_nodes(consumed_ids)
```

创建 `scenes/ui/shop_overlay.tscn` — 通过 MCP 工具或手动创建：

节点结构：
```
ShopOverlay (CanvasLayer, script=shop_overlay.gd, layer=10)
└── ShopPanel (PanelContainer, anchored bottom full width, height=120)
    ├── TopRow (HBoxContainer)
    │   ├── CoinsLabel (Label, text="$0")
    │   ├── LevelLabel (Label, text="Lv.1")
    │   ├── PopLabel (Label, text="人口 0/2")
    │   ├── WaveLabel (Label, text="Wave 0")
    │   ├── Spacer (Control, size_flags_horizontal=EXPAND_FILL)
    │   ├── LevelUpButton (Button, text="Lv↑")
    │   ├── RefreshButton (Button, text="🔄 $2")
    │   └── StartButton (Button, text="开战▶")
    ├── ShopRow (HBoxContainer)
    │   ├── ShopSlot0 (Button, size_flags_horizontal=EXPAND_FILL)
    │   ├── ShopSlot1 (Button, size_flags_horizontal=EXPAND_FILL)
    │   ├── ShopSlot2 (Button, size_flags_horizontal=EXPAND_FILL)
    │   └── ShopSlot3 (Button, size_flags_horizontal=EXPAND_FILL)
    └── BagRow (HBoxContainer)
```

- [ ] **Step 2: 写 ShopOverlay 测试**

创建 `tests/unit/test_shop_overlay.gd`（使用 `load()` 而非 `preload()`，避免编译时依赖）：

```gdscript
extends GutTest

var _overlay: CanvasLayer

func before_each() -> void:
	GameData.reset()
	GameData.coins = 20
	_overlay = load("res://scenes/ui/shop_overlay.tscn").instantiate()
	add_child(_overlay)

func after_each() -> void:
	_overlay.queue_free()

func test_refresh_shop_populates_slots() -> void:
	_overlay.refresh_shop(true)
	var has_items := false
	for slot in GameData.shop_slots:
		if slot != null:
			has_items = true
			break
	assert_true(has_items, "刷新后商店应有物品")

func test_start_battle_signal() -> void:
	watch_signals(_overlay)
	_overlay._on_start_pressed()
	assert_signal_emitted(_overlay, "start_battle_pressed")

func test_buy_item_updates_bag() -> void:
	_overlay.refresh_shop(true)
	var slot_index := -1
	for i in range(GameData.shop_slots.size()):
		if GameData.shop_slots[i] != null:
			slot_index = i
			break
	if slot_index >= 0:
		var old_bag_size: int = GameData.bag.size()
		_overlay._on_shop_slot_pressed(slot_index)
		assert_gt(GameData.bag.size(), old_bag_size, "购买后背包应增加物品")
```

- [ ] **Step 3: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_shop_overlay.gd`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/shop_overlay.gd scenes/ui/shop_overlay.tscn tests/unit/test_shop_overlay.gd
git commit -m "feat: ShopOverlay 底部商店面板 UI"
```

---

### Task 8: Main.gd — 阶段状态机集成

**Files:**
- Modify: `scripts/ui/main.gd`
- Modify: `scenes/levels/main.tscn`

**背景：** main.gd 新增 Phase 状态机，集成 ShopOverlay 和 DragManager，移除 `_restore_towers()` 和跳转 shop 场景的逻辑。

**参考现有 main.gd 关键行：**
- 第 3-6 行：变量声明（GRID_SIZE, _tower_container, _synergy_processor）
- 第 8-27 行：`_ready()` — 初始化
- 第 41-46 行：`_restore_towers()` — 从 GameData 恢复塔节点
- 第 52-53 行：`_on_wave_transition_ready()` — 调用 `SceneManager.go_to("shop")`

- [ ] **Step 1: 修改 main.gd**

修改 `scripts/ui/main.gd`：

```gdscript
extends Node2D

enum Phase { SHOP, BATTLE }

const GRID_SIZE := GameConfig.GRID_SIZE

var current_phase: Phase = Phase.SHOP
var _tower_container: Node2D
var _synergy_processor: SynergyEffectProcessor
var _shop_overlay: CanvasLayer
var _drag_manager: Node

func _ready() -> void:
	_tower_container = Node2D.new()
	_tower_container.name = "TowerContainer"
	add_child(_tower_container)

	_load_map()

	# ShopOverlay（预先在 main.tscn 中添加为子节点）
	_shop_overlay = $ShopOverlay
	_shop_overlay.start_battle_pressed.connect(_on_start_battle)

	# DragManager（预先在 main.tscn 中添加为子节点）
	_drag_manager = $DragManager
	_drag_manager.initialize(_tower_container, $Player, _shop_overlay)
	_shop_overlay.drag_manager = _drag_manager

	# SynergyEffectProcessor
	_synergy_processor = SynergyEffectProcessor.new()
	_synergy_processor.name = "SynergyEffectProcessor"
	add_child(_synergy_processor)

	# 暂停覆盖层（保留现有内联创建逻辑）
	var pause_overlay = load("res://scripts/ui/pause_overlay.gd").new()
	add_child(pause_overlay)
	# 调试面板
	var debug_panel = load("res://scripts/ui/debug_panel.gd").new()
	add_child(debug_panel)

	# 信号连接
	EventBus.wave_transition_ready.connect(_on_wave_transition_ready)
	EventBus.coins_generated.connect(_on_coins_generated)

	# 进入首次 SHOP 阶段
	_enter_shop_phase(true)

func _enter_shop_phase(is_first: bool = false) -> void:
	current_phase = Phase.SHOP
	_shop_overlay.refresh_shop(is_first)
	if not is_first:
		_shop_overlay.slide_in()
	_synergy_processor.deactivate()
	AudioManager.play_bgm("placement")
	$HUD.set_battle_phase(false)

func _enter_battle_phase() -> void:
	current_phase = Phase.BATTLE
	_shop_overlay.slide_out()
	_synergy_processor.activate()
	AudioManager.play_bgm("battle")
	$HUD.set_battle_phase(true)
	$WaveManager.start_next_wave()

func _on_start_battle() -> void:
	if current_phase == Phase.SHOP:
		_enter_battle_phase()

func _on_wave_transition_ready() -> void:
	_enter_shop_phase()

# 保留现有的 _load_map, _on_coins_generated 方法
# 删除 _restore_towers() 方法
# 删除 _grid_to_world() 方法（DragManager 有自己的版本）
```

- [ ] **Step 2: 修改 main.tscn 添加子节点**

在 `scenes/levels/main.tscn` 中添加：
- `ShopOverlay` — 实例化 `scenes/ui/shop_overlay.tscn`
- `DragManager` — Node，附加 `scripts/systems/drag_manager.gd`

通过 MCP 工具完成：
1. `add_scene` 添加 shop_overlay.tscn 到 Main 节点下
2. `add_node` 添加 Node 类型的 DragManager，然后 `attach_script` 附加 drag_manager.gd

- [ ] **Step 3: 运行全部测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 所有测试 PASS

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/main.gd scenes/levels/main.tscn
git commit -m "feat: main.gd 阶段状态机 + ShopOverlay/DragManager 集成"
```

---

### Task 9: HUD — 适配阶段显示

**Files:**
- Modify: `scripts/ui/hud.gd`

**背景：** HUD 在 SHOP 阶段也显示，但波次计时/击杀信息应显示"准备中"或隐藏。

- [ ] **Step 1: 修改 HUD**

在 `scripts/ui/hud.gd` 中新增：

```gdscript
var _is_battle_phase := false

func set_battle_phase(is_battle: bool) -> void:
	_is_battle_phase = is_battle
	if not is_battle:
		timer_display.text = "准备中"
		kill_display.visible = false
	else:
		kill_display.visible = true
```

修改 `_update_timer()` 方法，在开头添加守卫：
```gdscript
func _update_timer() -> void:
	if not _is_battle_phase:
		return
	# ... 现有计时逻辑
```

- [ ] **Step 2: 运行测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 所有测试 PASS

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/hud.gd
git commit -m "feat: HUD 适配 SHOP/BATTLE 阶段显示"
```

---

### Task 10: 删除旧 shop 场景 + 最终验收

**Files:**
- Delete: `scenes/ui/shop.tscn`
- Delete: `scripts/ui/shop.gd`
- Modify: 任何仍引用旧 shop 文件的测试

- [ ] **Step 1: 搜索旧 shop 引用**

Run: `grep -rn "shop.tscn\|shop.gd\|go_to.*\"shop\"" scripts/ scenes/ tests/ --include="*.gd" --include="*.tscn"`

确认所有引用已在前面的 Task 中清理。

- [ ] **Step 2: 删除旧文件**

```bash
git rm scenes/ui/shop.tscn scripts/ui/shop.gd
```

- [ ] **Step 3: 修复任何剩余引用**

根据 Step 1 结果修复残留引用。

- [ ] **Step 4: 运行全部测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 所有测试 PASS

- [ ] **Step 5: 手动验收测试**

通过 Godot 编辑器运行游戏，验证完整流程：
1. 选择地图后直接进入战斗场景（SHOP 阶段），底部面板可见
2. 可以购买物品到背包、刷新商店、升级人口
3. 从背包拖拽塔到地图放置（带预览和范围圈）
4. 拖拽地图上的塔移动位置
5. 拖拽塔回底部面板收回背包
6. 拖拽武器到玩家角色装备
7. 背包右键卖出物品
8. 玩家可自由移动
9. 点击"开战"后面板滑出，战斗正常进行
10. 波次结束后面板滑回，商店自动刷新
11. 所有波次通关后跳转 result

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: 完成商店-战斗场景融合 — 删除旧 shop 场景"
```
