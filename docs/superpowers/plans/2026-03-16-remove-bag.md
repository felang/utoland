# 移除背包实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 移除背包中间层，购买武器直接装备，购买塔进入放置模式直接布置。

**Architecture:** 原子化改动——GameData 先移除 bag 相关字段/方法并新增直接购买方法，然后 ShopManager/ShopOverlay/DragManager 同步适配，最后更新测试。

**Tech Stack:** Godot 4.6, GDScript, GUT 测试框架

---

## Chunk 1: 核心逻辑改动

### Task 1: 改造 GameData（移除 bag，新增直接购买方法）

**Files:**
- Modify: `scripts/core/game_data.gd`

- [ ] **Step 1: 删除 bag 相关字段和方法**

删除以下内容：
- `var bag: Array[Dictionary] = []`（第 30 行）
- `_DEFAULTS` 中的 `"bag": []` 条目（第 73 行）
- `get_bag_count()` 方法（第 149-150 行）
- `can_buy()` 方法（第 155-157 行）
- `deploy_weapon()` 方法（第 176-187 行）
- `undeploy_weapon()` 方法（第 189-195 行）
- `deploy_tower()` 方法（第 197-210 行）
- `undeploy_tower()` 方法（第 212-224 行）
- `sell_from_bag()` 方法（第 248-253 行）

- [ ] **Step 2: 新增 buy_and_equip_weapon()**

在 GameData 的 `# ===== 部署/撤回 =====` 区域添加：

```gdscript
## 购买并直接装备武器（无背包）
func buy_and_equip_weapon(weapon_id: String, cost: int) -> bool:
	if not can_deploy():
		return false
	if coins < cost:
		return false
	coins -= cost
	deployed_weapons.append({id = weapon_id, level = 1})
	var item := {id = weapon_id, type = "weapon", level = 1}
	EventBus.item_purchased.emit(item)
	EventBus.coins_changed.emit(-cost, coins)
	_check_merge(weapon_id, 1)
	return true
```

- [ ] **Step 3: 新增 buy_and_place_tower()**

```gdscript
## 购买并直接布置塔（无背包）
func buy_and_place_tower(tower_id: String, cost: int, grid_pos: Vector2i) -> int:
	if not can_deploy():
		return 0
	if coins < cost:
		return 0
	coins -= cost
	var deploy_id: int = _next_deploy_id
	_next_deploy_id += 1
	deployed_towers.append({id = tower_id, level = deploy_id, grid_pos = grid_pos, deploy_id = deploy_id})
	var item := {id = tower_id, type = "tower", level = 1}
	EventBus.item_purchased.emit(item)
	EventBus.coins_changed.emit(-cost, coins)
	_check_merge(tower_id, 1)
	return deploy_id
```

注意：`deployed_towers` entry 中 `level` 字段应为 1，上面有笔误。正确写法：
```gdscript
	deployed_towers.append({id = tower_id, level = 1, grid_pos = grid_pos, deploy_id = deploy_id})
```

- [ ] **Step 4: 改造 _check_merge() 和 _collect_items_by_id_level()**

删除 `_check_merge()` 中的 bag 扫描部分（第 299-306 行）。
删除 `_collect_items_by_id_level()` 中的 bag 扫描部分（第 332-334 行）。

修改 `_check_merge()` 合成品生成逻辑——合成品不再放入 bag，而是留在 deployed 中：

武器合成：消耗 3 个 deployed_weapons，添加 1 个新的到 deployed_weapons。
塔合成：消耗 3 个 deployed_towers，添加 1 个新的到 deployed_towers（保留第一个被消耗塔的位置和 deploy_id）。

```gdscript
func _check_merge(item_id: String, item_level: int) -> void:
	if item_level >= 3:
		return
	var all_items: Array[Dictionary] = _collect_items_by_id_level(item_id, item_level)
	if all_items.size() < 3:
		return
	var consumed: int = 0
	var item_type: String = ""
	var kept_tower_pos: Vector2i = Vector2i.ZERO
	var kept_tower_deploy_id: int = 0
	# 从 deployed_weapons 回收
	var i: int = deployed_weapons.size() - 1
	while i >= 0 and consumed < 3:
		if deployed_weapons[i].id == item_id and deployed_weapons[i].level == item_level:
			item_type = "weapon"
			deployed_weapons.remove_at(i)
			consumed += 1
		i -= 1
	# 从 deployed_towers 回收
	i = deployed_towers.size() - 1
	while i >= 0 and consumed < 3:
		if deployed_towers[i].id == item_id and deployed_towers[i].level == item_level:
			item_type = "tower"
			# 保留第一个被消耗塔的位置
			if kept_tower_deploy_id == 0:
				kept_tower_pos = deployed_towers[i].grid_pos
				kept_tower_deploy_id = deployed_towers[i].deploy_id
			deployed_towers.remove_at(i)
			consumed += 1
		i -= 1
	# 生成合成品，留在 deployed 中
	var new_level: int = item_level + 1
	if item_type == "weapon":
		deployed_weapons.append({id = item_id, level = new_level})
	elif item_type == "tower":
		deployed_towers.append({id = item_id, level = new_level, grid_pos = kept_tower_pos, deploy_id = kept_tower_deploy_id})
	EventBus.item_merged.emit(item_id, new_level)
	_check_merge(item_id, new_level)

func _collect_items_by_id_level(item_id: String, item_level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in deployed_weapons:
		if item.id == item_id and item.level == item_level:
			result.append(item)
	for item in deployed_towers:
		if item.id == item_id and item.level == item_level:
			result.append(item)
	return result
```

- [ ] **Step 5: Commit**

```bash
git add scripts/core/game_data.gd && git commit -m "refactor: GameData 移除 bag，新增直接购买方法"
```

---

### Task 2: 改造 ShopManager 和 ShopConfig

**Files:**
- Modify: `scripts/systems/shop_manager.gd`
- Modify: `scripts/resources/shop_config.gd`

- [ ] **Step 1: 更新 ShopConfig**

删除 `bag_capacity` 字段（第 8 行）。更新注释。

```gdscript
class_name ShopConfig
extends Resource

# 商店全局配置：槽位、刷新费用、升级费用、种群数量等

@export var slot_count: int = 4
@export var refresh_cost: int = 2
@export var item_cost: int = 3
@export var level_up_costs: PackedInt32Array = PackedInt32Array([4, 8, 12, 20, 28, 36])
@export var population_per_level: PackedInt32Array = PackedInt32Array([2, 3, 4, 5, 6, 7, 8])
```

- [ ] **Step 2: 改造 ShopManager.buy_item()**

武器购买直接调用 `GameData.buy_and_equip_weapon()`。
塔购买改为返回状态，不直接购买——由 UI 层处理放置流程后再调用 `GameData.buy_and_place_tower()`。

新增方法 `buy_weapon()` 和辅助方法 `get_slot()`:

```gdscript
class_name ShopManager
extends RefCounted

## 商店管理器 — 负责商店刷新、物品购买
## 由商店场景实例化（非 Autoload）。

func refresh_shop(is_first: bool = false) -> void:
	var config: ShopConfig = GameConfig.shop_config
	GameData.shop_slots = []
	var guaranteed_ids: Array[String] = []
	if is_first:
		if GameData._recommended_weapon != "" and _has_item(GameData._recommended_weapon):
			guaranteed_ids.append(GameData._recommended_weapon)
		if GameData._recommended_tower != "" and _has_item(GameData._recommended_tower):
			guaranteed_ids.append(GameData._recommended_tower)
	for i in config.slot_count:
		if i < guaranteed_ids.size():
			var item_id: String = guaranteed_ids[i]
			GameData.shop_slots.append({
				id = item_id,
				type = _get_item_type(item_id),
				cost = config.item_cost,
			})
		else:
			GameData.shop_slots.append(_generate_random_slot())

func manual_refresh() -> bool:
	var config: ShopConfig = GameConfig.shop_config
	if GameData.coins < config.refresh_cost:
		return false
	GameData.coins -= config.refresh_cost
	EventBus.coins_changed.emit(-config.refresh_cost, GameData.coins)
	refresh_shop()
	return true

## 购买武器（直接装备）
func buy_weapon(slot_index: int) -> bool:
	var slot: Dictionary = _validate_slot(slot_index)
	if slot.is_empty():
		return false
	if slot.type != "weapon":
		return false
	var success: bool = GameData.buy_and_equip_weapon(slot.id, slot.cost)
	if success:
		GameData.shop_slots[slot_index] = {}
	return success

## 获取塔购买信息（不扣款，由 UI 放置成功后调用 confirm_tower_purchase）
func get_tower_slot(slot_index: int) -> Dictionary:
	var slot: Dictionary = _validate_slot(slot_index)
	if slot.is_empty() or slot.type != "tower":
		return {}
	return slot

## 确认塔购买（放置成功后调用）
func confirm_tower_purchase(slot_index: int, grid_pos: Vector2i) -> int:
	var slot: Dictionary = _validate_slot(slot_index)
	if slot.is_empty():
		return 0
	var deploy_id: int = GameData.buy_and_place_tower(slot.id, slot.cost, grid_pos)
	if deploy_id > 0:
		GameData.shop_slots[slot_index] = {}
	return deploy_id

func _validate_slot(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= GameData.shop_slots.size():
		return {}
	var slot: Dictionary = GameData.shop_slots[slot_index]
	if slot.is_empty():
		return {}
	if GameData.coins < slot.cost:
		return {}
	if not GameData.can_deploy():
		return {}
	return slot

func _generate_random_slot() -> Dictionary:
	var config: ShopConfig = GameConfig.shop_config
	var pool: Array[String] = _get_all_items()
	if pool.is_empty():
		return {}
	var item_id: String = pool[randi() % pool.size()]
	return {
		id = item_id,
		type = _get_item_type(item_id),
		cost = config.item_cost,
	}

func _get_all_items() -> Array[String]:
	var pool: Array[String] = []
	for id: String in GameConfig.weapons:
		pool.append(id)
	for id: String in GameConfig.towers:
		pool.append(id)
	return pool

func _has_item(item_id: String) -> bool:
	return GameConfig.weapons.has(item_id) or GameConfig.towers.has(item_id)

func _get_item_type(item_id: String) -> String:
	if GameConfig.weapons.has(item_id):
		return "weapon"
	return "tower"
```

- [ ] **Step 3: Commit**

```bash
git add scripts/systems/shop_manager.gd scripts/resources/shop_config.gd && git commit -m "refactor: ShopManager/ShopConfig 移除 bag，支持直接购买"
```

---

### Task 3: 改造 ShopOverlay UI（移除背包栏，改造购买流程）

**Files:**
- Modify: `scripts/ui/shop_overlay.gd`

- [ ] **Step 1: 删除背包相关 UI**

删除：
- `signal bag_item_drag_started`（第 5 行）
- `_bag_container` 和 `_bag_slots` 变量（第 22 行）
- `_setup_ui()` 中 `_bag_container` 的引用（第 43 行）
- `_update_bag_display()` 方法（第 84-103 行）
- `_on_bag_slot_input()` 方法（第 133-142 行）
- `_update_ui()` 中 `_update_bag_display()` 调用（第 61 行）

- [ ] **Step 2: 改造 _on_shop_slot_pressed()**

购买武器直接装备；购买塔进入放置模式：

```gdscript
func _on_shop_slot_pressed(slot_index: int) -> void:
	var slot: Dictionary = GameData.shop_slots[slot_index]
	if slot.is_empty():
		return
	if slot.type == "weapon":
		var snapshot: Array = GameData.deployed_weapons.duplicate(true)
		var success: bool = _shop_manager.buy_weapon(slot_index)
		if success:
			_update_ui()
	elif slot.type == "tower":
		var tower_slot: Dictionary = _shop_manager.get_tower_slot(slot_index)
		if not tower_slot.is_empty():
			_start_tower_placement(slot_index, tower_slot)
```

- [ ] **Step 3: 新增塔放置模式**

添加变量和方法：

```gdscript
var _pending_tower_slot_index: int = -1
var _pending_tower_data: Dictionary = {}

func _start_tower_placement(slot_index: int, tower_slot: Dictionary) -> void:
	_pending_tower_slot_index = slot_index
	_pending_tower_data = tower_slot
	if drag_manager and drag_manager.has_method("start_tower_placement"):
		drag_manager.start_tower_placement(tower_slot.id, funcref_place_callback)

## 放置成功回调
func _on_tower_placed(grid_pos: Vector2i) -> void:
	if _pending_tower_slot_index < 0:
		return
	var snapshot: Array = GameData.deployed_towers.duplicate(true)
	var deploy_id: int = _shop_manager.confirm_tower_purchase(_pending_tower_slot_index, grid_pos)
	if deploy_id > 0:
		_handle_merge_tower_cleanup(snapshot)
	_pending_tower_slot_index = -1
	_pending_tower_data = {}
	_update_ui()

## 放置取消回调
func _on_tower_placement_cancelled() -> void:
	_pending_tower_slot_index = -1
	_pending_tower_data = {}
```

注意：实际回调机制取决于 DragManager 的 API。在 Task 4 中会改造 DragManager 来支持 `start_tower_placement(tower_id, on_placed, on_cancelled)` 回调模式。

- [ ] **Step 4: 更新购买按钮 disabled 状态**

购买按钮禁用条件从 `can_buy()` 改为 `can_deploy()`：
在 `_update_shop_slots_display()` 中增加人口检查：

```gdscript
func _update_shop_slots_display() -> void:
	var can_afford_and_deploy: bool = GameData.can_deploy()
	for i in range(4):
		if i < GameData.shop_slots.size() and not GameData.shop_slots[i].is_empty():
			var slot_data: Dictionary = GameData.shop_slots[i]
			var item_data: Resource = _get_item_data(slot_data.id)
			var name_text: String = item_data.display_name if item_data else slot_data.id
			_shop_slots[i].text = "%s $%d" % [name_text, slot_data.cost]
			_shop_slots[i].disabled = GameData.coins < slot_data.cost or not can_afford_and_deploy
		else:
			_shop_slots[i].text = "已售出"
			_shop_slots[i].disabled = true
```

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/shop_overlay.gd && git commit -m "refactor: ShopOverlay 移除背包栏，改造购买流程"
```

---

### Task 4: 改造 DragManager（移除背包拖拽，新增塔放置模式）

**Files:**
- Modify: `scripts/systems/drag_manager.gd`

- [ ] **Step 1: 移除背包拖拽逻辑**

删除：
- `DragSource` 枚举中的 `BAG_TOWER` 和 `BAG_WEAPON`，改为 `enum DragSource { NONE, PLACE_TOWER, MAP_TOWER }`
- `_on_bag_item_drag_started()` 方法（第 29-36 行）
- `initialize()` 中 `shop_overlay.bag_item_drag_started.connect(...)` 连接（第 27 行）
- `_try_deploy_tower()` 方法中对 `_drag_data.bag_index` 的引用
- `_try_equip_weapon()` 方法（整个删除）
- `_end_drag()` 中 `BAG_TOWER` 和 `BAG_WEAPON` 的 match 分支

- [ ] **Step 2: 新增 start_tower_placement() 方法**

```gdscript
var _on_placed_callback: Callable
var _on_cancelled_callback: Callable
var _placement_tower_id: String = ""

## 商店触发的塔放置模式
func start_tower_placement(tower_id: String, on_placed: Callable, on_cancelled: Callable) -> void:
	if _is_dragging:
		return
	_placement_tower_id = tower_id
	_on_placed_callback = on_placed
	_on_cancelled_callback = on_cancelled
	_drag_data = {tower_id = tower_id}
	_start_drag(DragSource.PLACE_TOWER)

func _end_drag(global_pos: Vector2) -> void:
	match _drag_source:
		DragSource.PLACE_TOWER:
			_try_place_new_tower(global_pos)
		DragSource.MAP_TOWER:
			_try_move_tower(global_pos)
	_cleanup_drag()

func _try_place_new_tower(global_pos: Vector2) -> void:
	var grid_pos := _world_to_grid(global_pos)
	if not _is_valid_grid_pos(grid_pos) or not _is_grid_available(grid_pos):
		if _on_cancelled_callback.is_valid():
			_on_cancelled_callback.call()
		return
	if _on_placed_callback.is_valid():
		_on_placed_callback.call(grid_pos)
```

- [ ] **Step 3: 简化 _cancel_drag()**

```gdscript
func _cancel_drag() -> void:
	if _drag_source == DragSource.MAP_TOWER and _drag_original_deploy_id >= 0:
		if _drag_original_deploy_id in _tower_nodes:
			_tower_nodes[_drag_original_deploy_id].modulate.a = 1.0
	elif _drag_source == DragSource.PLACE_TOWER:
		if _on_cancelled_callback.is_valid():
			_on_cancelled_callback.call()
	_cleanup_drag()
```

- [ ] **Step 4: 简化 _try_move_or_undeploy_tower() 为 _try_move_tower()**

由于不再有 undeploy（收回背包），拖拽到面板区域不再触发收回。只支持移动和取消：

```gdscript
func _try_move_tower(global_pos: Vector2) -> void:
	var deploy_id: int = _drag_data.deploy_id
	var grid_pos := _world_to_grid(global_pos)
	if _is_valid_grid_pos(grid_pos) and _is_grid_available(grid_pos):
		if GameData.move_tower(deploy_id, grid_pos):
			_tower_nodes[deploy_id].position = _grid_to_world(grid_pos)
			_tower_nodes[deploy_id].modulate.a = 1.0
			return
	# 移动失败，恢复原位
	if deploy_id in _tower_nodes:
		_tower_nodes[deploy_id].modulate.a = 1.0
```

- [ ] **Step 5: 更新 initialize()**

移除 `_shop_overlay` 参数和 bag_item_drag_started 连接：

```gdscript
func initialize(tower_container: Node2D, player: Node2D) -> void:
	_tower_container = tower_container
	_player = player
```

注意：main.gd 中的 `_drag_manager.initialize()` 调用也需要同步更新（去掉第三个参数）。

- [ ] **Step 6: Commit**

```bash
git add scripts/systems/drag_manager.gd && git commit -m "refactor: DragManager 移除背包拖拽，新增塔放置模式"
```

---

### Task 5: 更新 main.gd 和 EventBus

**Files:**
- Modify: `scripts/ui/main.gd`
- Modify: `scripts/core/event_bus.gd`

- [ ] **Step 1: 更新 main.gd**

更新 `_drag_manager.initialize()` 调用——去掉 `_shop_overlay` 参数：

```gdscript
_drag_manager.initialize(_tower_container, $Player)
```

删除 `_shop_overlay.drag_manager = _drag_manager` 这行（如果 ShopOverlay 仍需要引用 drag_manager，保留）。

实际上 ShopOverlay 需要 drag_manager 来触发塔放置。所以保留注入但改为：
```gdscript
_shop_overlay.drag_manager = _drag_manager
```

- [ ] **Step 2: 清理 EventBus（如有必要）**

检查 `item_deployed` 和 `item_undeployed` 信号——如果不再有 deploy/undeploy 操作（已被 buy_and_equip 替代），这两个信号可能需要保留（buy_and_equip 中仍 emit item_purchased，功能已覆盖）。

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/main.gd scripts/core/event_bus.gd && git commit -m "refactor: main.gd 适配新的 DragManager 初始化"
```

---

## Chunk 2: 更新测试

### Task 6: 更新测试文件

**Files:**
- Modify: `tests/unit/test_game_data_economy.gd` — 移除 bag 引用，改用 buy_and_equip_weapon/buy_and_place_tower
- Modify: `tests/unit/test_merge_system.gd` — 移除 bag 引用，合成品在 deployed 中
- Modify: `tests/unit/test_shop_manager.gd` — 移除 can_buy/bag 引用，改用 buy_weapon/confirm_tower_purchase
- Modify: `tests/unit/test_drag_manager.gd` — 移除 BAG_TOWER/BAG_WEAPON 引用
- Modify: `tests/unit/test_shop_overlay.gd` — 移除背包显示测试（如有）

- [ ] **Step 1: 更新 test_game_data_economy.gd**

- 替换所有 `GameData.bag.append(...)` → `GameData.deployed_weapons.append(...)` 或 `deployed_towers.append(...)`
- 删除 `sell_from_bag` 测试
- 删除 `deploy_weapon`/`undeploy_weapon`/`deploy_tower`/`undeploy_tower` 测试
- 新增 `buy_and_equip_weapon` 和 `buy_and_place_tower` 测试
- 更新合成测试：合成品在 deployed 中而非 bag 中

- [ ] **Step 2: 更新 test_merge_system.gd**

- 合成输入改为 deployed_weapons/deployed_towers
- 合成结果检查改为 deployed 中
- 删除所有 `bag` 引用

- [ ] **Step 3: 更新 test_shop_manager.gd**

- `buy_item` → `buy_weapon` / `confirm_tower_purchase`
- 删除 `can_buy` 引用，改为 `can_deploy`
- 删除 bag 相关断言

- [ ] **Step 4: 更新 test_drag_manager.gd**

- 删除 BAG_TOWER/BAG_WEAPON 相关测试
- 更新为 PLACE_TOWER/MAP_TOWER

- [ ] **Step 5: 更新 test_shop_overlay.gd（如有 bag 引用）**

- 移除背包显示测试

- [ ] **Step 6: Commit**

```bash
git add tests/ && git commit -m "test: 更新测试适配移除背包后的系统"
```

---

### Task 7: 运行测试验证

- [ ] **Step 1: 运行全部测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 2: 修复任何失败**

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "test: 修复移除背包后的测试问题"
```
