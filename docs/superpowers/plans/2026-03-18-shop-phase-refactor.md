# Shop 阶段重构 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重构商店阶段——底部横条面板替代左侧竖条、武器装备栏+塔点击菜单、二合一合成、金币买升级、移除相机缩放和回收区拖拽。

**Architecture:** ShopOverlay 从左侧 CanvasLayer 竖条改为底部横条（信息栏+主行），主行分三区（武器装备/商店卡片/操作按钮）。合成和卖出操作从拖拽改为点击菜单。DragManager 简化为 PLACE_TOWER + MOVE_TOWER 两种模式。

**Tech Stack:** Godot 4.6 / GDScript / GUT 测试框架

---

## Chunk 1: 后端逻辑（InventoryManager + ShopConfig + PlayerProgression + ShopManager）

### Task 1: 合成机制改为二合一 + 新增手动合成 API

**Files:**
- Modify: `scripts/core/inventory_manager.gd`
- Test: `tests/unit/test_inventory_merge.gd` (Create)

- [ ] **Step 1: 创建合成测试文件**

创建 `tests/unit/test_inventory_merge.gd`：

```gdscript
extends GutTest

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	StatsTracker.reset()
	InventoryManager.coins = 100
	PlayerProgression.player_level = 10

# ===== _check_merge 二合一 =====

func test_check_merge_two_same_weapons() -> void:
	InventoryManager.deployed_weapons = [
		{id = "bow", level = 1},
		{id = "bow", level = 1},
	]
	InventoryManager._check_merge("bow", 1)
	assert_eq(InventoryManager.deployed_weapons.size(), 1)
	assert_eq(InventoryManager.deployed_weapons[0].level, 2)

func test_check_merge_no_merge_with_one() -> void:
	InventoryManager.deployed_weapons = [{id = "bow", level = 1}]
	InventoryManager._check_merge("bow", 1)
	assert_eq(InventoryManager.deployed_weapons.size(), 1)
	assert_eq(InventoryManager.deployed_weapons[0].level, 1)

func test_check_merge_max_level() -> void:
	InventoryManager.deployed_weapons = [
		{id = "bow", level = 3},
		{id = "bow", level = 3},
	]
	InventoryManager._check_merge("bow", 3)
	# Lv3 不合成
	assert_eq(InventoryManager.deployed_weapons.size(), 2)

func test_check_merge_towers_preserves_position() -> void:
	InventoryManager.deployed_towers = [
		{id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 1},
		{id = "pea_shooter", level = 1, grid_pos = Vector2i(10, 10), deploy_id = 2},
	]
	InventoryManager._check_merge("pea_shooter", 1)
	assert_eq(InventoryManager.deployed_towers.size(), 1)
	assert_eq(InventoryManager.deployed_towers[0].level, 2)

# ===== merge_weapon 手动合成 =====

func test_merge_weapon_success() -> void:
	InventoryManager.deployed_weapons = [
		{id = "bow", level = 1},
		{id = "bow", level = 1},
	]
	var result: bool = InventoryManager.merge_weapon(0)
	assert_true(result)
	assert_eq(InventoryManager.deployed_weapons.size(), 1)
	assert_eq(InventoryManager.deployed_weapons[0].id, "bow")
	assert_eq(InventoryManager.deployed_weapons[0].level, 2)

func test_merge_weapon_no_pair() -> void:
	InventoryManager.deployed_weapons = [
		{id = "bow", level = 1},
		{id = "sword", level = 1},
	]
	var result: bool = InventoryManager.merge_weapon(0)
	assert_false(result)
	assert_eq(InventoryManager.deployed_weapons.size(), 2)

func test_merge_weapon_invalid_index() -> void:
	InventoryManager.deployed_weapons = [{id = "bow", level = 1}]
	var result: bool = InventoryManager.merge_weapon(5)
	assert_false(result)

# ===== merge_tower 手动合成 =====

func test_merge_tower_success() -> void:
	InventoryManager.deployed_towers = [
		{id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 1},
		{id = "pea_shooter", level = 1, grid_pos = Vector2i(10, 10), deploy_id = 2},
	]
	var result: bool = InventoryManager.merge_tower(1)
	assert_true(result)
	assert_eq(InventoryManager.deployed_towers.size(), 1)
	assert_eq(InventoryManager.deployed_towers[0].level, 2)
	assert_eq(InventoryManager.deployed_towers[0].deploy_id, 1)
	assert_eq(InventoryManager.deployed_towers[0].grid_pos, Vector2i(5, 5))

func test_merge_tower_no_pair() -> void:
	InventoryManager.deployed_towers = [
		{id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 1},
		{id = "ice_flower", level = 1, grid_pos = Vector2i(10, 10), deploy_id = 2},
	]
	var result: bool = InventoryManager.merge_tower(1)
	assert_false(result)

# ===== can_buy_item 简化 =====

func test_can_buy_item_population_available() -> void:
	assert_true(InventoryManager.can_buy_item("bow", 1))

func test_can_buy_item_population_full() -> void:
	# 填满人口上限
	var cap: int = PlayerProgression.get_population_cap()
	for i in cap:
		InventoryManager.deployed_weapons.append({id = "bow", level = 1})
	# 即使有同类也不允许购买
	assert_false(InventoryManager.can_buy_item("bow", 1))

# ===== 购买不再自动合成 =====

func test_buy_weapon_no_auto_merge() -> void:
	InventoryManager.deployed_weapons = [{id = "bow", level = 1}]
	InventoryManager.buy_and_equip_weapon("bow", 3)
	# 应有 2 个 Lv1 弓（不自动合成）
	assert_eq(InventoryManager.deployed_weapons.size(), 2)
	assert_eq(InventoryManager.deployed_weapons[0].level, 1)
	assert_eq(InventoryManager.deployed_weapons[1].level, 1)
```

- [ ] **Step 2: 运行测试验证失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_inventory_merge.gd`
Expected: FAIL（`merge_weapon`、`merge_tower` 方法不存在，`_check_merge` 阈值为 3，`can_buy_item` 有合成判断）

- [ ] **Step 3: 修改 inventory_manager.gd**

修改 `scripts/core/inventory_manager.gd`：

1. `can_buy_item()` 简化：
```gdscript
func can_buy_item(_item_id: String, _item_level: int) -> bool:
	return can_deploy()
```

2. `buy_and_equip_weapon()` 移除 `_check_merge` 调用（删除第 43 行）

3. `buy_and_place_tower()` 移除 `_check_merge` 调用（删除第 58 行）

4. `_check_merge()` 阈值 3→2，消耗数量 3→2：
```gdscript
func _check_merge(item_id: String, item_level: int) -> void:
	if item_level >= 3:
		return
	var all_items: Array[Dictionary] = _collect_items_by_id_level(item_id, item_level)
	if all_items.size() < 2:
		return
	var consumed: int = 0
	var item_type: String = ""
	var kept_tower_pos: Vector2i = Vector2i.ZERO
	var kept_tower_deploy_id: int = 0
	var i: int = deployed_weapons.size() - 1
	while i >= 0 and consumed < 2:
		if deployed_weapons[i].id == item_id and deployed_weapons[i].level == item_level:
			item_type = "weapon"
			deployed_weapons.remove_at(i)
			consumed += 1
		i -= 1
	i = deployed_towers.size() - 1
	while i >= 0 and consumed < 2:
		if deployed_towers[i].id == item_id and deployed_towers[i].level == item_level:
			item_type = "tower"
			if kept_tower_deploy_id == 0:
				kept_tower_pos = deployed_towers[i].grid_pos
				kept_tower_deploy_id = deployed_towers[i].deploy_id
			deployed_towers.remove_at(i)
			consumed += 1
		i -= 1
	var new_level: int = item_level + 1
	if item_type == "weapon":
		deployed_weapons.append({id = item_id, level = new_level})
	elif item_type == "tower":
		deployed_towers.append({id = item_id, level = new_level, grid_pos = kept_tower_pos, deploy_id = kept_tower_deploy_id})
	EventBus.item_merged.emit(item_id, new_level)
	_check_merge(item_id, new_level)
```

5. 新增 `merge_weapon()` 和 `merge_tower()` 方法：
```gdscript
func merge_weapon(weapon_index: int) -> bool:
	if weapon_index < 0 or weapon_index >= deployed_weapons.size():
		return false
	var entry: Dictionary = deployed_weapons[weapon_index]
	if entry.level >= 3:
		return false
	# 检查是否有配对
	var pair_index: int = -1
	for i in range(deployed_weapons.size()):
		if i != weapon_index and deployed_weapons[i].id == entry.id and deployed_weapons[i].level == entry.level:
			pair_index = i
			break
	if pair_index == -1:
		return false
	# 升级被点击的武器，移除配对
	var kept_id: String = entry.id
	var new_level: int = entry.level + 1
	deployed_weapons[weapon_index] = {id = kept_id, level = new_level}
	deployed_weapons.remove_at(pair_index)
	EventBus.item_merged.emit(kept_id, new_level)
	_check_merge(kept_id, new_level)
	return true

func merge_tower(deploy_id: int) -> bool:
	var tower_index: int = -1
	for i in range(deployed_towers.size()):
		if deployed_towers[i].deploy_id == deploy_id:
			tower_index = i
			break
	if tower_index == -1:
		return false
	var entry: Dictionary = deployed_towers[tower_index]
	if entry.level >= 3:
		return false
	# 查找配对
	var pair_index: int = -1
	for i in range(deployed_towers.size()):
		if i != tower_index and deployed_towers[i].id == entry.id and deployed_towers[i].level == entry.level:
			pair_index = i
			break
	if pair_index == -1:
		return false
	# 保留被点击塔的位置和 deploy_id
	var kept_pos: Vector2i = entry.grid_pos
	var kept_deploy_id: int = entry.deploy_id
	var kept_id: String = entry.id
	var new_level: int = entry.level + 1
	# 移除两个（先移较大索引）
	var remove_first: int = max(tower_index, pair_index)
	var remove_second: int = min(tower_index, pair_index)
	deployed_towers.remove_at(remove_first)
	deployed_towers.remove_at(remove_second)
	deployed_towers.append({id = kept_id, level = new_level, grid_pos = kept_pos, deploy_id = kept_deploy_id})
	EventBus.item_merged.emit(kept_id, new_level)
	_check_merge(kept_id, new_level)
	return true
```

- [ ] **Step 4: 运行测试验证通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_inventory_merge.gd`
Expected: ALL PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/core/inventory_manager.gd tests/unit/test_inventory_merge.gd
git commit -m "feat: 合成机制改为二合一，新增手动合成 API"
```

### Task 2: ShopConfig 新增买升级价格配置

**Files:**
- Modify: `scripts/resources/shop_config.gd`
- Modify: `resources/shop/shop_config.tres`

- [ ] **Step 1: 修改 ShopConfig 类**

在 `scripts/resources/shop_config.gd` 末尾添加：

```gdscript
@export var level_up_base_cost: int = 4
@export var level_up_cost_increment: int = 2

func get_level_up_cost(current_level: int) -> int:
	return level_up_base_cost + (current_level - 1) * level_up_cost_increment
```

- [ ] **Step 2: 更新 .tres 文件**

在 `resources/shop/shop_config.tres` 中添加新字段（或确认默认值生效）。

- [ ] **Step 3: 提交**

```bash
git add scripts/resources/shop_config.gd resources/shop/shop_config.tres
git commit -m "feat: ShopConfig 新增 level_up 价格配置"
```

### Task 3: PlayerProgression 新增 buy_level_up

**Files:**
- Modify: `scripts/core/player_progression.gd`
- Test: `tests/unit/test_inventory_merge.gd` (追加测试)

- [ ] **Step 1: 在 test_inventory_merge.gd 追加测试**

```gdscript
# ===== buy_level_up =====

func test_buy_level_up() -> void:
	PlayerProgression.player_level = 3
	var old_cap: int = PlayerProgression.get_population_cap()
	PlayerProgression.buy_level_up()
	assert_eq(PlayerProgression.player_level, 4)
	assert_gt(PlayerProgression.get_population_cap(), old_cap)

func test_buy_level_up_does_not_change_exp() -> void:
	PlayerProgression.current_exp = 50
	PlayerProgression.buy_level_up()
	assert_eq(PlayerProgression.current_exp, 50)
```

- [ ] **Step 2: 运行测试验证失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_inventory_merge.gd`
Expected: FAIL（`buy_level_up` 不存在）

- [ ] **Step 3: 在 player_progression.gd 添加 buy_level_up**

在 `scripts/core/player_progression.gd` 的 `get_population_cap()` 后添加：

```gdscript
func buy_level_up() -> void:
	player_level += 1
	EventBus.player_level_changed.emit(player_level)
```

- [ ] **Step 4: 运行测试验证通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_inventory_merge.gd`
Expected: ALL PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/core/player_progression.gd tests/unit/test_inventory_merge.gd
git commit -m "feat: PlayerProgression.buy_level_up() 金币升级接口"
```

### Task 4: ShopManager 新增 buy_level_up

**Files:**
- Modify: `scripts/systems/shop_manager.gd`
- Test: `tests/unit/test_inventory_merge.gd` (追加测试)

- [ ] **Step 1: 追加测试**

```gdscript
# ===== ShopManager.buy_level_up =====

func test_shop_manager_buy_level_up_success() -> void:
	var sm := ShopManager.new()
	InventoryManager.coins = 100
	PlayerProgression.player_level = 1
	var cost: int = GameConfig.shop_config.get_level_up_cost(1)
	var result: bool = sm.buy_level_up()
	assert_true(result)
	assert_eq(PlayerProgression.player_level, 2)
	assert_eq(InventoryManager.coins, 100 - cost)

func test_shop_manager_buy_level_up_insufficient_gold() -> void:
	var sm := ShopManager.new()
	InventoryManager.coins = 0
	PlayerProgression.player_level = 1
	var result: bool = sm.buy_level_up()
	assert_false(result)
	assert_eq(PlayerProgression.player_level, 1)
```

- [ ] **Step 2: 运行测试验证失败**

- [ ] **Step 3: 在 shop_manager.gd 添加 buy_level_up**

在 `scripts/systems/shop_manager.gd` 的 `confirm_tower_purchase()` 后添加：

```gdscript
## 购买升级（花金币提升等级）
func buy_level_up() -> bool:
	var cost: int = GameConfig.shop_config.get_level_up_cost(PlayerProgression.player_level)
	if InventoryManager.coins < cost:
		return false
	InventoryManager.coins -= cost
	EventBus.coins_changed.emit(-cost, InventoryManager.coins)
	PlayerProgression.buy_level_up()
	return true
```

- [ ] **Step 4: 运行测试验证通过**

- [ ] **Step 5: 提交**

```bash
git add scripts/systems/shop_manager.gd tests/unit/test_inventory_merge.gd
git commit -m "feat: ShopManager.buy_level_up() 金币升级功能"
```

---

## Chunk 2: DragManager 简化 + main.gd 相机移除

> **依赖顺序**: Task 5 (DragManager) 必须在 Task 7 (main.gd) 之前完成，因为 main.gd 调用 `set_shop_mode()` 依赖 DragManager 先实现该方法。

### Task 5: DragManager 简化——移除 MAP_TOWER/WEAPON/回收区，新增 shop_mode 和塔菜单

**Files:**
- Modify: `scripts/systems/drag_manager.gd`
- Test: `tests/unit/test_drag_manager.gd` (更新)

- [ ] **Step 1: 更新 test_drag_manager.gd**

删除以下测试：
- `test_set_recycle_area`
- `test_is_over_recycle_area`
- `test_is_over_recycle_area_null`
- `test_start_weapon_drag`
- `test_start_weapon_drag_while_dragging`
- `test_cleanup_resets_weapon_state`

新增测试：

```gdscript
func test_set_shop_mode() -> void:
	_drag_manager.set_shop_mode(true)
	assert_true(_drag_manager._is_shop_mode)
	_drag_manager.set_shop_mode(false)
	assert_false(_drag_manager._is_shop_mode)

func test_is_grid_available_move_tower_excludes_self() -> void:
	InventoryManager.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 1})
	_drag_manager._drag_source = _drag_manager.DragSource.MOVE_TOWER
	_drag_manager._drag_original_deploy_id = 1
	# 塔自身位置应视为可用
	assert_true(_drag_manager._is_grid_available(Vector2i(5, 5)))
```

- [ ] **Step 2: 运行测试验证失败**

- [ ] **Step 3: 重构 drag_manager.gd**

重写 `scripts/systems/drag_manager.gd`：

1. `DragSource` 枚举改为 `{ NONE, PLACE_TOWER, MOVE_TOWER }`
2. 新增 `var _is_shop_mode: bool = false`
3. 新增 `func set_shop_mode(enabled: bool) -> void`
4. 删除所有回收区相关代码：`_recycle_area`、`_recycle_hint_label`、`set_recycle_area()`、`is_over_recycle_area()`、`_update_recycle_hint()`、`_hide_recycle_hint()`、`_get_drag_refund()`
5. 删除武器拖拽相关：`_drag_weapon_index`、`_on_weapon_sold_callback`、`start_weapon_drag()`、`_try_sell_weapon()`
6. 删除 `start_map_tower_drag()`（改为菜单触发）
7. `_check_tower_click()` 改为弹出菜单（仅在 `_is_shop_mode` 时响应）
8. 新增 `start_move_tower(deploy_id: int)` 方法（由塔菜单"移动"调用）
9. `_is_grid_available()` 中 `MAP_TOWER` 替换为 `MOVE_TOWER`
10. `_cancel_drag()` 和 `_end_drag()` 中的 `MAP_TOWER` 替换为 `MOVE_TOWER`
11. 新增塔菜单（PopupMenu）：`_show_tower_menu(deploy_id)`，显示合成/卖出/移动选项

塔菜单实现：
```gdscript
var _tower_menu: PopupMenu = null
var _menu_deploy_id: int = -1

func _check_tower_click(global_pos: Vector2) -> void:
	if not _is_shop_mode:
		return
	for deploy_id in _tower_nodes:
		var tower_node: Node2D = _tower_nodes[deploy_id]
		if tower_node.global_position.distance_to(global_pos) < GameConfig.GRID_SIZE:
			_show_tower_menu(deploy_id)
			break

func _show_tower_menu(deploy_id: int) -> void:
	_menu_deploy_id = deploy_id
	if _tower_menu == null:
		_tower_menu = PopupMenu.new()
		_tower_menu.name = "TowerMenu"
		_tower_menu.id_pressed.connect(_on_tower_menu_pressed)
		add_child(_tower_menu)
	_tower_menu.clear()

	# 查找塔数据
	var entry: Dictionary = {}
	for t in InventoryManager.deployed_towers:
		if t.deploy_id == deploy_id:
			entry = t
			break
	if entry.is_empty():
		return

	# 合成选项（检查是否有配对）
	var has_pair: bool = false
	for t in InventoryManager.deployed_towers:
		if t.deploy_id != deploy_id and t.id == entry.id and t.level == entry.level and entry.level < 3:
			has_pair = true
			break
	if has_pair:
		_tower_menu.add_item("合成", 0)

	# 卖出选项
	var tower_data: TowerData = GameConfig.towers.get(entry.id)
	var refund: int = tower_data.sell_price_per_level[entry.level - 1] if tower_data else 0
	_tower_menu.add_item("卖出 $%d" % refund, 1)

	# 移动选项
	_tower_menu.add_item("移动", 2)

	# 显示在塔上方（转为屏幕坐标）
	var tower_node: Node2D = _tower_nodes[deploy_id]
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * tower_node.global_position
	_tower_menu.position = Vector2i(int(screen_pos.x), int(screen_pos.y) - 60)
	_tower_menu.popup()

func _on_tower_menu_pressed(id: int) -> void:
	var deploy_id: int = _menu_deploy_id
	match id:
		0:  # 合成
			var old_towers: Array = InventoryManager.deployed_towers.duplicate(true)
			if InventoryManager.merge_tower(deploy_id):
				_handle_tower_merge_visual(deploy_id, old_towers)
		1:  # 卖出
			var refund: int = InventoryManager.sell_from_deployed_tower(deploy_id)
			if refund > 0:
				_remove_tower_node(deploy_id)
		2:  # 移动
			start_move_tower(deploy_id)
	_menu_deploy_id = -1

func _handle_tower_merge_visual(kept_deploy_id: int, old_towers: Array) -> void:
	# 移除被消耗的塔节点
	var current_ids: Array[int] = []
	for entry in InventoryManager.deployed_towers:
		current_ids.append(entry.deploy_id)
	for entry in old_towers:
		if entry.deploy_id not in current_ids:
			_remove_tower_node(entry.deploy_id)
	# 升级保留塔的视觉
	for entry in InventoryManager.deployed_towers:
		if entry.deploy_id == kept_deploy_id:
			upgrade_tower_node(entry.deploy_id, entry.id, entry.level, entry.grid_pos)
			break

func start_move_tower(deploy_id: int) -> void:
	if _is_dragging:
		return
	if deploy_id not in _tower_nodes:
		return
	for entry in InventoryManager.deployed_towers:
		if entry.deploy_id == deploy_id:
			_drag_data = {deploy_id = deploy_id, item = entry}
			_drag_original_deploy_id = deploy_id
			_drag_original_grid_pos = entry.grid_pos
			_start_drag(DragSource.MOVE_TOWER)
			break
```

- [ ] **Step 4: 运行测试验证通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_drag_manager.gd`
Expected: ALL PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/systems/drag_manager.gd tests/unit/test_drag_manager.gd
git commit -m "refactor: DragManager 简化为 PLACE_TOWER+MOVE_TOWER，新增塔点击菜单"
```

### Task 6: WeaponManager 移除拖拽回调机制

**Files:**
- Modify: `scripts/entities/weapons/weapon_manager.gd`

- [ ] **Step 1: 移除拖拽回调相关代码**

从 `scripts/entities/weapons/weapon_manager.gd` 中：

1. 删除变量：`var _weapon_drag_callback: Callable`（第 23 行）
2. 删除方法：`set_weapon_drag_callback()`（第 152-154 行）
3. 删除 `_setup_click_area()` 方法（第 224-240 行）
4. 删除 `add_weapon()` 中调用 `_setup_click_area(sprite, _pivots.size())` 的那行

- [ ] **Step 2: 提交**

```bash
git add scripts/entities/weapons/weapon_manager.gd
git commit -m "refactor: WeaponManager 移除武器拖拽回调机制"
```

### Task 7: main.gd 移除相机操控和武器拖拽回调

**Files:**
- Modify: `scripts/ui/main.gd`

- [ ] **Step 1: 移除相机常量和方法**

从 `scripts/ui/main.gd` 中：

1. 删除常量：`CAMERA_TRANSITION_DURATION`、`SHOP_ZOOM`、`SHOP_CAMERA_POS`
2. 删除变量：`_camera`
3. 删除方法：`_restore_battle_camera()`、`_get_clamped_camera_pos()`
4. 删除 `_ready()` 中：`_camera = $Player.get_node("Camera")` 缓存
5. 删除 `_ready()` 中：`wm.set_weapon_drag_callback(...)` 回调设置
6. 删除 `_ready()` 中：`_drag_manager.set_recycle_area(_shop_overlay.get_recycle_area())`

- [ ] **Step 2: 简化 _enter_shop_phase**

替换 `_enter_shop_phase()` 为（注意 refresh/BGM/HUD 在 if 块外面，无条件执行）：

```gdscript
func _enter_shop_phase(is_first: bool = false) -> void:
	current_phase = Phase.SHOP
	$Player.set_input_enabled(true)
	_drag_manager.set_shop_mode(true)

	# 波次结束奖励金币（首次不发）
	if not is_first:
		_shop_overlay.slide_in()
		var reward: int = GameConfig.shop_config.wave_reward
		InventoryManager.coins += reward
		StatsTracker.record_coins_earned(reward)
		EventBus.coins_changed.emit(reward, InventoryManager.coins)
		var player_node: Node2D = $Player
		if player_node:
			player_node.coins = InventoryManager.coins

	# 以下无条件执行（首次和非首次都需要）
	_shop_overlay.refresh_shop(is_first)
	AudioManager.play_bgm("placement")
	$HUD.set_battle_phase(false)
```

- [ ] **Step 3: 简化 _enter_battle_phase**

替换 `_enter_battle_phase()` 为：

```gdscript
func _enter_battle_phase() -> void:
	current_phase = Phase.BATTLE
	_drag_manager.set_shop_mode(false)
	_shop_overlay.slide_out()
	AudioManager.play_bgm("battle")
	$HUD.set_battle_phase(true)
	$WaveManager.start_next_wave()
```

- [ ] **Step 4: 验证游戏可启动**

通过 gdai-mcp 的 `play_scene` 或 Godot 编辑器运行，确认不崩溃。

- [ ] **Step 5: 提交**

```bash
git add scripts/ui/main.gd
git commit -m "refactor: main.gd 移除相机操控和武器拖拽回调"
```

---

## Chunk 3: ShopOverlay 重写（底部面板 + 武器装备栏 + 菜单）

### Task 8: 重写 shop_overlay.tscn 锚点

**Files:**
- Modify: `scenes/ui/shop_overlay.tscn`

- [ ] **Step 1: 重写场景文件**

将 `scenes/ui/shop_overlay.tscn` 的 ShopPanel 锚点改为底部全宽：

```
[gd_scene format=3 uid="uid://dkqv7xm2w3a8p"]

[ext_resource type="Script" path="res://scripts/ui/shop_overlay.gd" id="1_shop"]

[node name="ShopOverlay" type="CanvasLayer"]
layer = 10
script = ExtResource("1_shop")

[node name="ShopPanel" type="PanelContainer" parent="."]
anchor_left = 0.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -120
grow_vertical = 0

[node name="VBoxContainer" type="VBoxContainer" parent="ShopPanel"]
layout_mode = 2
theme_override_constants/separation = 2
```

- [ ] **Step 2: 提交**

```bash
git add scenes/ui/shop_overlay.tscn
git commit -m "refactor: shop_overlay.tscn 锚点改为底部全宽"
```

### Task 9: 重写 shop_overlay.gd

**Files:**
- Modify: `scripts/ui/shop_overlay.gd`

- [ ] **Step 1: 重写 shop_overlay.gd**

完全重写 `scripts/ui/shop_overlay.gd`。关键变更：

1. **布局**：`_setup_ui()` 改为底部横条双行结构
   - 信息栏（HBoxContainer）：金币/等级/人口/波次 + 右侧开战按钮
   - 主行（HBoxContainer）：武器区(GridContainer 3列) | VSeparator | 商店卡片区(HBoxContainer 4卡片) | VSeparator | 操作区(VBoxContainer 刷新+升级)

2. **武器装备栏**：
   - `_weapon_grid: GridContainer`（columns=3）
   - `_update_weapon_grid()` 从 `InventoryManager.deployed_weapons` 读取，生成 28px 图标按钮
   - 点击图标调用 `_show_weapon_menu(weapon_index)`

3. **武器菜单**：
   - `_weapon_menu: PopupMenu`
   - 合成选项（有配对时显示）
   - 卖出选项（显示金额）
   - `_on_weapon_menu_pressed(id)` 处理合成/卖出

4. **动画方向改为垂直**：
   - `slide_out()`: tween `position:y` 向下移出
   - `slide_in()`: 预设 y 在屏幕外，tween 回原位
   - `_slide_original_y` 替代 `_slide_original_x`

5. **买升级按钮**：
   - `_level_up_button: Button`
   - 显示 "升级 $X"（X = `ShopConfig.get_level_up_cost()`）
   - 点击调用 `_shop_manager.buy_level_up()`

6. **移除**：
   - 回收区 UI（`_recycle_area`、`get_recycle_area()`）
   - `_on_weapon_sold()` 方法
   - `_handle_merge_weapon_cleanup()` 和 `_handle_merge_tower_cleanup()`（合成现在由菜单直接处理）

完整重写代码：

```gdscript
extends CanvasLayer
## 底部商店面板 — 横条双行 UI

signal start_battle_pressed

const SLIDE_DURATION := 0.3
const CARD_ICON_SIZE := Vector2(24, 24)
const WEAPON_ICON_SIZE := Vector2(28, 28)

var _shop_manager: ShopManager
var _panel: PanelContainer
var _slide_original_y: float = 0.0

# 信息栏
var _coins_label: Label
var _level_label: Label
var _pop_label: Label
var _wave_label: Label

# 操作按钮
var _refresh_button: Button
var _level_up_button: Button
var _start_button: Button

# 商店卡片
var _card_containers: Array[PanelContainer] = []
var _card_icons: Array[TextureRect] = []
var _card_names: Array[Label] = []
var _card_prices: Array[Label] = []
var _card_buttons: Array[Button] = []

# 武器装备栏
var _weapon_grid: GridContainer
var _weapon_menu: PopupMenu
var _menu_weapon_index: int = -1

# 放置状态
var _pending_tower_slot_index: int = -1

# 外部注入
var drag_manager: Node = null
var weapon_manager: WeaponManager = null

func _ready() -> void:
	layer = 10
	_shop_manager = ShopManager.new()
	_setup_ui()
	_update_ui()
	EventBus.item_sold.connect(func(_item: Dictionary, _refund: int): _update_ui())
	EventBus.item_merged.connect(func(_id: String, _level: int): _update_ui())

func _setup_ui() -> void:
	_panel = $ShopPanel
	_slide_original_y = _panel.position.y

	var vbox: VBoxContainer = $ShopPanel/VBoxContainer

	# === 信息栏（上行）===
	var info_bar := HBoxContainer.new()
	info_bar.name = "InfoBar"
	info_bar.add_theme_constant_override("separation", 12)
	vbox.add_child(info_bar)

	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 14)
	info_bar.add_child(_coins_label)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 14)
	info_bar.add_child(_level_label)

	_pop_label = Label.new()
	_pop_label.add_theme_font_size_override("font_size", 14)
	info_bar.add_child(_pop_label)

	_wave_label = Label.new()
	_wave_label.add_theme_font_size_override("font_size", 14)
	info_bar.add_child(_wave_label)

	# 弹性占位
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_bar.add_child(spacer)

	_start_button = Button.new()
	_start_button.text = "开战"
	_start_button.pressed.connect(_on_start_pressed)
	info_bar.add_child(_start_button)

	# === 主行（下行）===
	var main_row := HBoxContainer.new()
	main_row.name = "MainRow"
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 8)
	vbox.add_child(main_row)

	# — 武器区 (~30%) —
	var weapon_section := VBoxContainer.new()
	weapon_section.name = "WeaponSection"
	weapon_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_section.size_flags_stretch_ratio = 0.3
	main_row.add_child(weapon_section)

	var weapon_label := Label.new()
	weapon_label.text = "武器"
	weapon_label.add_theme_font_size_override("font_size", 10)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_section.add_child(weapon_label)

	_weapon_grid = GridContainer.new()
	_weapon_grid.columns = 3
	_weapon_grid.add_theme_constant_override("h_separation", 3)
	_weapon_grid.add_theme_constant_override("v_separation", 3)
	weapon_section.add_child(_weapon_grid)

	# 分隔线
	var sep1 := VSeparator.new()
	main_row.add_child(sep1)

	# — 商店卡片区 (~55%) —
	var card_section := HBoxContainer.new()
	card_section.name = "CardSection"
	card_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_section.size_flags_stretch_ratio = 0.55
	card_section.add_theme_constant_override("separation", 4)
	main_row.add_child(card_section)

	for i in range(4):
		var card := _create_card(i)
		card_section.add_child(card)

	# 分隔线
	var sep2 := VSeparator.new()
	main_row.add_child(sep2)

	# — 操作区 (~15%) —
	var action_section := VBoxContainer.new()
	action_section.name = "ActionSection"
	action_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_section.size_flags_stretch_ratio = 0.15
	action_section.add_theme_constant_override("separation", 4)
	main_row.add_child(action_section)

	_refresh_button = Button.new()
	_refresh_button.text = "刷新 $2"
	_refresh_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_refresh_button.pressed.connect(_on_refresh_pressed)
	action_section.add_child(_refresh_button)

	_level_up_button = Button.new()
	_level_up_button.text = "升级 $4"
	_level_up_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_level_up_button.pressed.connect(_on_level_up_pressed)
	action_section.add_child(_level_up_button)

	# 武器菜单
	_weapon_menu = PopupMenu.new()
	_weapon_menu.name = "WeaponMenu"
	_weapon_menu.id_pressed.connect(_on_weapon_menu_pressed)
	add_child(_weapon_menu)

func _create_card(index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "ShopCard%d" % index
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = CARD_ICON_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)
	_card_icons.append(icon)

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(name_label)
	_card_names.append(name_label)

	var price_label := Label.new()
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 10)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	vbox.add_child(price_label)
	_card_prices.append(price_label)

	var btn := Button.new()
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on_shop_slot_pressed.bind(index))
	card.add_child(btn)
	_card_buttons.append(btn)

	_card_containers.append(card)
	return card

func refresh_shop(is_first: bool = false) -> void:
	_shop_manager.refresh_shop(is_first)
	_update_ui()

func _update_ui() -> void:
	_update_info_bar()
	_update_cards()
	_update_weapon_grid()
	_update_action_buttons()

func _update_info_bar() -> void:
	_coins_label.text = "$%d" % InventoryManager.coins
	_level_label.text = "Lv.%d" % PlayerProgression.player_level
	var pop_current: int = InventoryManager.get_population_used()
	var pop_max: int = PlayerProgression.get_population_cap()
	_pop_label.text = "人口 %d/%d" % [pop_current, pop_max]
	_wave_label.text = "W%d" % PlayerState.current_wave

func _update_cards() -> void:
	var is_placing: bool = _pending_tower_slot_index >= 0
	for i in range(4):
		if i < InventoryManager.shop_slots.size() and not InventoryManager.shop_slots[i].is_empty():
			var slot_data: Dictionary = InventoryManager.shop_slots[i]
			var item_data: Resource = _get_item_data(slot_data.id)

			if item_data and item_data.icon_path != "" and ResourceLoader.exists(item_data.icon_path):
				_card_icons[i].texture = load(item_data.icon_path)
			else:
				_card_icons[i].texture = null

			_card_names[i].text = item_data.display_name if item_data else slot_data.id
			_card_prices[i].text = "$%d" % slot_data.cost

			var can_buy: bool = InventoryManager.coins >= slot_data.cost and InventoryManager.can_buy_item(slot_data.id, 1)
			_card_buttons[i].disabled = not can_buy or is_placing

			if is_placing and i == _pending_tower_slot_index:
				_card_names[i].text = "放置中"
				_card_buttons[i].disabled = true

			_card_containers[i].modulate = Color.WHITE if (can_buy and not is_placing) else Color(0.5, 0.5, 0.5)
		else:
			_card_icons[i].texture = null
			_card_names[i].text = "已售出"
			_card_prices[i].text = ""
			_card_buttons[i].disabled = true
			_card_containers[i].modulate = Color(0.5, 0.5, 0.5)

func _update_weapon_grid() -> void:
	# 清除旧图标
	for child in _weapon_grid.get_children():
		child.queue_free()
	# 创建已装备武器图标
	for i in range(InventoryManager.deployed_weapons.size()):
		var entry: Dictionary = InventoryManager.deployed_weapons[i]
		var btn := Button.new()
		btn.custom_minimum_size = WEAPON_ICON_SIZE
		btn.flat = true
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		# 图标
		var weapon_data: WeaponData = GameConfig.weapons.get(entry.id)
		if weapon_data and not weapon_data.icon_path.is_empty() and ResourceLoader.exists(weapon_data.icon_path):
			var icon := TextureRect.new()
			icon.texture = load(weapon_data.icon_path)
			icon.custom_minimum_size = WEAPON_ICON_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(icon)
		btn.pressed.connect(_show_weapon_menu.bind(i))
		_weapon_grid.add_child(btn)
	# 空槽（填到 6 个）
	var empty_count: int = max(6 - InventoryManager.deployed_weapons.size(), 0)
	for i in range(empty_count):
		var empty := Panel.new()
		empty.custom_minimum_size = WEAPON_ICON_SIZE
		empty.modulate = Color(0.3, 0.3, 0.3)
		_weapon_grid.add_child(empty)

func _update_action_buttons() -> void:
	_refresh_button.text = "刷新 $%d" % GameConfig.shop_config.refresh_cost
	_refresh_button.disabled = InventoryManager.coins < GameConfig.shop_config.refresh_cost

	var level_cost: int = GameConfig.shop_config.get_level_up_cost(PlayerProgression.player_level)
	_level_up_button.text = "升级 $%d" % level_cost
	_level_up_button.disabled = InventoryManager.coins < level_cost

func _show_weapon_menu(weapon_index: int) -> void:
	_menu_weapon_index = weapon_index
	_weapon_menu.clear()

	var entry: Dictionary = InventoryManager.deployed_weapons[weapon_index]

	# 合成选项
	var has_pair: bool = false
	for i in range(InventoryManager.deployed_weapons.size()):
		if i != weapon_index and InventoryManager.deployed_weapons[i].id == entry.id and InventoryManager.deployed_weapons[i].level == entry.level and entry.level < 3:
			has_pair = true
			break
	if has_pair:
		_weapon_menu.add_item("合成", 0)

	# 卖出选项
	var weapon_data: WeaponData = GameConfig.weapons.get(entry.id)
	var refund: int = weapon_data.sell_price_per_level[entry.level - 1] if weapon_data else 0
	_weapon_menu.add_item("卖出 $%d" % refund, 1)

	# 显示菜单
	var btn: Button = _weapon_grid.get_child(weapon_index)
	var global_pos: Vector2 = btn.global_position
	_weapon_menu.position = Vector2i(int(global_pos.x), int(global_pos.y) - 50)
	_weapon_menu.popup()

func _on_weapon_menu_pressed(id: int) -> void:
	match id:
		0:  # 合成
			if InventoryManager.merge_weapon(_menu_weapon_index):
				if weapon_manager:
					weapon_manager.refresh_weapons()
				_update_ui()
		1:  # 卖出
			var refund: int = InventoryManager.sell_from_deployed_weapon(_menu_weapon_index)
			if refund > 0 and weapon_manager:
				weapon_manager.remove_weapon(_menu_weapon_index)
			_update_ui()
	_menu_weapon_index = -1

func _on_shop_slot_pressed(slot_index: int) -> void:
	var slot: Dictionary = InventoryManager.shop_slots[slot_index]
	if slot.is_empty():
		return
	if slot.type == "weapon":
		var success: bool = _shop_manager.buy_weapon(slot_index)
		if success:
			if weapon_manager:
				weapon_manager.refresh_weapons()
			_update_ui()
	elif slot.type == "tower":
		var tower_slot: Dictionary = _shop_manager.get_tower_slot(slot_index)
		if not tower_slot.is_empty():
			_pending_tower_slot_index = slot_index
			_update_cards()
			_start_button.disabled = true
			drag_manager.start_tower_placement(
				tower_slot.id,
				_on_tower_placed,
				_on_tower_placement_cancelled
			)

func _on_tower_placed(grid_pos: Vector2i) -> void:
	if _pending_tower_slot_index < 0:
		return
	var slot: Dictionary = InventoryManager.shop_slots[_pending_tower_slot_index]
	var tower_id: String = slot.id if not slot.is_empty() else ""
	var deploy_id: int = _shop_manager.confirm_tower_purchase(_pending_tower_slot_index, grid_pos)
	if deploy_id > 0:
		drag_manager.spawn_tower_node(deploy_id, tower_id, 1, grid_pos)
	_pending_tower_slot_index = -1
	_start_button.disabled = false
	_update_ui()

func _on_tower_placement_cancelled() -> void:
	_pending_tower_slot_index = -1
	_start_button.disabled = false
	_update_ui()

func _on_refresh_pressed() -> void:
	_shop_manager.manual_refresh()
	_update_ui()

func _on_level_up_pressed() -> void:
	if _shop_manager.buy_level_up():
		_update_ui()

func _on_start_pressed() -> void:
	start_battle_pressed.emit()

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

func _get_item_data(item_id: String) -> Resource:
	if GameConfig.weapons.has(item_id):
		return GameConfig.weapons[item_id]
	if GameConfig.towers.has(item_id):
		return GameConfig.towers[item_id]
	return null
```

- [ ] **Step 2: 提交**

```bash
git add scripts/ui/shop_overlay.gd scenes/ui/shop_overlay.tscn
git commit -m "feat: ShopOverlay 重写为底部横条面板（武器装备栏+菜单+买升级）"
```

---

## Chunk 4: 更新现有测试 + 集成验证

### Task 10: 更新现有测试

**Files:**
- Modify: `tests/unit/test_weapon_config.gd` (如有合成测试需更新)
- Modify: `tests/unit/test_object_pool.gd` (如有合成测试需更新)

- [ ] **Step 1: 检查并更新现有测试中的合成相关断言**

检查 `test_weapon_config.gd` 和 `test_object_pool.gd` 中是否有依赖 3 合 1 行为的测试，将阈值改为 2。

- [ ] **Step 2: 运行全部测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: ALL PASS

- [ ] **Step 3: 提交**

```bash
git add tests/
git commit -m "test: 更新现有测试适配二合一合成和商店重构"
```

### Task 11: 集成验证

- [ ] **Step 1: 在 Godot 编辑器中运行游戏**

验证点：
1. 进入商店阶段——底部面板从下方弹出
2. 相机不再缩放/移动
3. 武器区显示已装备武器图标
4. 点击武器图标弹出合成/卖出菜单
5. 商店卡片可正常购买武器和塔
6. 购买塔后进入放置模式
7. 点击地图上的塔弹出合成/卖出/移动菜单
8. 刷新按钮和升级按钮正常工作
9. 点击开战后面板弹入，进入战斗
10. 波次结束后面板再次弹出

- [ ] **Step 2: 修复发现的问题（如有）**

- [ ] **Step 3: 最终提交**

```bash
git add -A
git commit -m "fix: 商店重构集成修复"
```
