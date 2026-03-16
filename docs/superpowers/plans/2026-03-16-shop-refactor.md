# 商店阶段重构 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重构商店 UI 为卡片式四选购买，购买即部署（武器即时装备可见，塔拖拽放置），新增回收区卖出机制，修复人口满时合成可购买的逻辑。

**Architecture:** 在现有 ShopOverlay + ShopManager + DragManager 基础上改造。卡片 UI 用代码在 `shop_overlay.gd` 中构建（PanelContainer + TextureRect + Label）。`can_buy_item()` 替换三层 `can_deploy()` 检查。WeaponManager 新增热更新方法。DragManager 扩展武器拖拽和回收区检测。

**Tech Stack:** GDScript, Godot 4.6, GUT 测试框架

---

## Chunk 1: GameData.can_buy_item + 验证层修复

### Task 1: GameData 新增 can_buy_item 方法

**Files:**
- Modify: `scripts/core/game_data.gd:140-150`
- Test: `tests/unit/test_game_data.gd` (新建)

- [ ] **Step 1: 创建测试文件，写 can_buy_item 的失败测试**

```gdscript
# tests/unit/test_game_data.gd
extends GutTest

func before_each() -> void:
	GameData.reset()
	GameData.deployed_weapons = []
	GameData.deployed_towers = []
	GameData.player_level = 1  # 人口上限 2
	GameData.coins = 100

# ===== can_buy_item =====

func test_can_buy_item_true_when_population_available() -> void:
	# 人口 0/2，可以购买
	assert_true(GameData.can_buy_item("bow", 1))

func test_can_buy_item_false_when_pop_full_no_merge() -> void:
	# 人口 2/2，没有同类可合成
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0), deploy_id = 1})
	assert_false(GameData.can_buy_item("shuriken", 1))

func test_can_buy_item_true_when_pop_full_but_merge_possible() -> void:
	# 人口 2/2，但已有 2 个同 id 同 level，买第 3 个触发合成
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_weapons.append({id = "bow", level = 1})
	assert_true(GameData.can_buy_item("bow", 1))

func test_can_buy_item_false_when_pop_full_only_1_match() -> void:
	# 人口 2/2，只有 1 个同类，不够合成
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0), deploy_id = 1})
	assert_false(GameData.can_buy_item("bow", 1))

func test_can_buy_item_tower_merge_possible() -> void:
	# 人口 2/2，已有 2 个同 id 塔
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0), deploy_id = 1})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(1, 0), deploy_id = 2})
	assert_true(GameData.can_buy_item("pea_shooter", 1))
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_game_data.gd`
Expected: FAIL — `can_buy_item` 方法不存在

- [ ] **Step 3: 实现 can_buy_item**

在 `scripts/core/game_data.gd` 的 `can_deploy()` 方法后（约 150 行）添加：

```gdscript
## 判断是否可以购买指定物品（考虑合成释放人口）
func can_buy_item(item_id: String, item_level: int) -> bool:
	if can_deploy():
		return true
	# 人口满，检查是否能触发合成（已有 ≥2 个同 id 同 level）
	var count: int = 0
	for w in deployed_weapons:
		if w.id == item_id and w.level == item_level:
			count += 1
	for t in deployed_towers:
		if t.id == item_id and t.level == item_level:
			count += 1
	return count >= 2
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_game_data.gd`
Expected: 5 tests PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/core/game_data.gd tests/unit/test_game_data.gd
git commit -m "feat: GameData.can_buy_item 支持人口满时合成可购买判断"
```

### Task 2: 三层验证替换 can_deploy → can_buy_item

**Files:**
- Modify: `scripts/core/game_data.gd:171,185`
- Modify: `scripts/systems/shop_manager.gd:70`
- Test: `tests/unit/test_shop_manager.gd`
- Test: `tests/unit/test_game_data.gd`

- [ ] **Step 1: 写 ShopManager 合成可购买的测试**

在 `tests/unit/test_shop_manager.gd` 末尾追加：

```gdscript
# ===== 人口满时合成可购买 =====

func test_buy_weapon_succeeds_when_pop_full_but_merge_possible() -> void:
	GameData.player_level = 1  # 人口上限 2
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.coins = 9999
	GameData.shop_slots = [
		{id = "bow", type = "weapon", cost = 3},
		{}, {}, {}
	]
	var result: bool = _shop.buy_weapon(0)
	assert_true(result, "人口满但可合成时应允许购买")
	# 合成后应只剩 1 个 Lv2
	assert_eq(GameData.deployed_weapons.size(), 1)
	assert_eq(GameData.deployed_weapons[0].level, 2)

func test_confirm_tower_purchase_succeeds_when_pop_full_but_merge_possible() -> void:
	GameData.player_level = 1  # 人口上限 2
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0), deploy_id = 1})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(1, 0), deploy_id = 2})
	GameData.coins = 9999
	GameData.shop_slots = [
		{id = "pea_shooter", type = "tower", cost = 3},
		{}, {}, {}
	]
	var deploy_id: int = _shop.confirm_tower_purchase(0, Vector2i(2, 0))
	assert_gt(deploy_id, 0, "人口满但可合成时应允许购买塔")
	assert_eq(GameData.deployed_towers.size(), 1)
	assert_eq(GameData.deployed_towers[0].level, 2)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_shop_manager.gd`
Expected: 新增的 2 个测试 FAIL（`can_deploy()` 阻止购买）

- [ ] **Step 3: 修改 ShopManager._validate_slot**

`scripts/systems/shop_manager.gd:66-73`，将 `_validate_slot` 中的 `can_deploy()` 替换：

```gdscript
func _validate_slot(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= GameData.shop_slots.size():
		return {}
	var slot: Dictionary = GameData.shop_slots[slot_index]
	if slot.is_empty():
		return {}
	if GameData.coins < slot.cost:
		return {}
	if not GameData.can_buy_item(slot.id, 1):
		return {}
	return slot
```

- [ ] **Step 4: 修改 GameData.buy_and_equip_weapon**

`scripts/core/game_data.gd:170-171`，替换：

```gdscript
func buy_and_equip_weapon(weapon_id: String, cost: int) -> bool:
	if not can_buy_item(weapon_id, 1):
		return false
```

- [ ] **Step 5: 修改 GameData.buy_and_place_tower**

`scripts/core/game_data.gd:184-185`，替换：

```gdscript
func buy_and_place_tower(tower_id: String, cost: int, grid_pos: Vector2i) -> int:
	if not can_buy_item(tower_id, 1):
		return 0
```

- [ ] **Step 6: 运行全部测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit`
Expected: 所有测试 PASS（包括原有的 `test_buy_weapon_fails_when_population_full` 仍然 PASS，因为那里 bow + pea_shooter 不同 id 无法合成）

- [ ] **Step 7: 提交**

```bash
git add scripts/core/game_data.gd scripts/systems/shop_manager.gd tests/unit/test_shop_manager.gd
git commit -m "feat: 三层验证替换 can_deploy 为 can_buy_item，支持合成购买"
```

## Chunk 2: WeaponManager 热更新

### Task 3: WeaponManager 新增 add_weapon / remove_weapon

**Files:**
- Modify: `scripts/entities/weapons/weapon_manager.gd`
- Test: `tests/unit/test_weapon_manager.gd` (新建)

- [ ] **Step 1: 写测试**

```gdscript
# tests/unit/test_weapon_manager.gd
extends GutTest

var _wm: WeaponManager
var _owner: Node2D

func before_each() -> void:
	GameData.reset()
	_owner = Node2D.new()
	add_child(_owner)
	_wm = WeaponManager.new()
	_owner.add_child(_wm)

func after_each() -> void:
	_owner.queue_free()

func test_add_weapon_creates_weapon_node() -> void:
	var count_before: int = _wm._weapons.size()
	_wm.add_weapon("bow", 1)
	assert_eq(_wm._weapons.size(), count_before + 1)
	assert_eq(_wm._weapon_sprites.size(), count_before + 1)

func test_remove_weapon_removes_weapon_node() -> void:
	_wm.add_weapon("bow", 1)
	_wm.add_weapon("shuriken", 1)
	assert_eq(_wm._weapons.size(), 2)
	_wm.remove_weapon(0)
	assert_eq(_wm._weapons.size(), 1)
	assert_eq(_wm._weapon_sprites.size(), 1)

func test_remove_weapon_invalid_index_does_nothing() -> void:
	_wm.add_weapon("bow", 1)
	_wm.remove_weapon(99)
	assert_eq(_wm._weapons.size(), 1)

func test_refresh_weapons_syncs_with_deployed() -> void:
	GameData.deployed_weapons = [
		{id = "bow", level = 1},
		{id = "shuriken", level = 1}
	]
	_wm.refresh_weapons()
	assert_eq(_wm._weapons.size(), 2)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_weapon_manager.gd`
Expected: FAIL — `add_weapon`、`remove_weapon`、`refresh_weapons` 方法不存在

- [ ] **Step 3: 实现方法**

在 `scripts/entities/weapons/weapon_manager.gd` 中追加（`initialize` 之后）：

```gdscript
## 热更新：添加单个武器（商店购买后立即调用）
func add_weapon(weapon_id: String, level: int) -> void:
	if not GameConfig.weapons.has(weapon_id):
		push_error("WeaponManager: 未知武器 id: " + weapon_id)
		return
	var data: WeaponData = GameConfig.weapons[weapon_id]
	var weapon: Weapon = _add_weapon(data, weapon_id)
	if weapon:
		weapon.set_level(level)
		_apply_passive_to_weapon(weapon)

## 热更新：移除指定索引的武器（卖出时调用）
func remove_weapon(index: int) -> void:
	if index < 0 or index >= _weapons.size():
		return
	_weapons[index].queue_free()
	_weapons.remove_at(index)
	_weapon_sprites[index].queue_free()
	_weapon_sprites.remove_at(index)
	_sprite_rot_offsets.remove_at(index)

## 完全重建：清除所有武器并从 deployed_weapons 重新初始化
func refresh_weapons() -> void:
	# 清除现有
	for w in _weapons:
		w.queue_free()
	_weapons.clear()
	for s in _weapon_sprites:
		s.queue_free()
	_weapon_sprites.clear()
	_sprite_rot_offsets.clear()
	# 重建
	initialize(GameData.deployed_weapons)
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_weapon_manager.gd`
Expected: 4 tests PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/entities/weapons/weapon_manager.gd tests/unit/test_weapon_manager.gd
git commit -m "feat: WeaponManager add_weapon/remove_weapon/refresh_weapons 热更新"
```

## Chunk 3: DragManager 扩展（回收区 + 武器拖拽 + 塔升级）

### Task 4: DragManager 新增回收区检测和塔升级

**Files:**
- Modify: `scripts/systems/drag_manager.gd`
- Test: `tests/unit/test_drag_manager.gd`

- [ ] **Step 1: 写回收区和塔升级的测试**

在 `tests/unit/test_drag_manager.gd` 末尾追加：

```gdscript
# ===== 回收区 =====

func test_set_recycle_area() -> void:
	var area := Control.new()
	area.position = Vector2(100, 100)
	area.size = Vector2(50, 50)
	add_child(area)
	_drag_manager.set_recycle_area(area)
	assert_not_null(_drag_manager._recycle_area)
	area.queue_free()

func test_is_over_recycle_area() -> void:
	var area := Control.new()
	area.global_position = Vector2(100, 100)
	area.size = Vector2(50, 50)
	add_child(area)
	_drag_manager.set_recycle_area(area)
	assert_true(_drag_manager.is_over_recycle_area(Vector2(125, 125)))
	assert_false(_drag_manager.is_over_recycle_area(Vector2(0, 0)))
	area.queue_free()

# ===== 塔升级 =====

func test_upgrade_tower_node() -> void:
	var deploy_id := 1
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = deploy_id})
	_drag_manager.spawn_tower_node(deploy_id, "pea_shooter", 1, Vector2i(5, 5))
	assert_true(deploy_id in _drag_manager._tower_nodes)
	# 升级：删旧塔、创建新等级塔
	_drag_manager.upgrade_tower_node(deploy_id, "pea_shooter", 2, Vector2i(5, 5))
	assert_true(deploy_id in _drag_manager._tower_nodes)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_drag_manager.gd`
Expected: FAIL — 新方法不存在

- [ ] **Step 3: 实现方法**

在 `scripts/systems/drag_manager.gd` 中添加：

变量区新增：
```gdscript
var _recycle_area: Control = null
```

方法区新增：
```gdscript
func set_recycle_area(area: Control) -> void:
	_recycle_area = area

func is_over_recycle_area(global_pos: Vector2) -> bool:
	if _recycle_area == null:
		return false
	var rect := Rect2(_recycle_area.global_position, _recycle_area.size)
	return rect.has_point(global_pos)

func upgrade_tower_node(deploy_id: int, tower_id: String, new_level: int, grid_pos: Vector2i) -> void:
	_remove_tower_node(deploy_id)
	spawn_tower_node(deploy_id, tower_id, new_level, grid_pos)
```

- [ ] **Step 4: 修改 _try_move_tower 和 _end_drag 支持回收区**

在 `_try_move_tower` 中，检查是否在回收区释放：

```gdscript
func _try_move_tower(global_pos: Vector2) -> void:
	var deploy_id: int = _drag_data.deploy_id
	# 回收区检测
	if is_over_recycle_area(global_pos):
		var refund: int = GameData.sell_from_deployed_tower(deploy_id)
		if refund > 0:
			_remove_tower_node(deploy_id)
			return
	var grid_pos := _world_to_grid(global_pos)
	if _is_valid_grid_pos(grid_pos) and _is_grid_available(grid_pos):
		if GameData.move_tower(deploy_id, grid_pos):
			_tower_nodes[deploy_id].position = _grid_to_world(grid_pos)
			_tower_nodes[deploy_id].modulate.a = 1.0
			return
	if deploy_id in _tower_nodes:
		_tower_nodes[deploy_id].modulate.a = 1.0
```

- [ ] **Step 5: 新增武器拖拽 DragSource 和处理**

在 `DragSource` 枚举中新增：
```gdscript
enum DragSource { NONE, PLACE_TOWER, MAP_TOWER, WEAPON }
```

新增变量：
```gdscript
var _drag_weapon_index: int = -1
var _on_weapon_sold_callback: Callable
```

新增方法：
```gdscript
func start_weapon_drag(weapon_index: int, on_sold: Callable) -> void:
	if _is_dragging:
		return
	_drag_weapon_index = weapon_index
	_on_weapon_sold_callback = on_sold
	_drag_data = {weapon_index = weapon_index}
	_start_drag(DragSource.WEAPON)

func _try_sell_weapon(global_pos: Vector2) -> void:
	if is_over_recycle_area(global_pos) and _drag_weapon_index >= 0:
		if _on_weapon_sold_callback.is_valid():
			_on_weapon_sold_callback.call(_drag_weapon_index)
	_drag_weapon_index = -1
	_on_weapon_sold_callback = Callable()
```

在 `_end_drag` 的 match 中添加：
```gdscript
DragSource.WEAPON:
	_try_sell_weapon(global_pos)
```

在 `_cleanup_drag` 中添加：
```gdscript
_drag_weapon_index = -1
_on_weapon_sold_callback = Callable()
```

- [ ] **Step 6: 运行全部 drag_manager 测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_drag_manager.gd`
Expected: 所有测试 PASS

- [ ] **Step 7: 提交**

```bash
git add scripts/systems/drag_manager.gd tests/unit/test_drag_manager.gd
git commit -m "feat: DragManager 回收区检测、塔升级、武器拖拽卖出"
```

## Chunk 4: ShopOverlay 卡片 UI 重构

### Task 5: 重构 shop_overlay.tscn 场景结构

**Files:**
- Modify: `scenes/ui/shop_overlay.tscn`

- [ ] **Step 1: 重写场景文件**

删除 `BagRow`，将 `ShopRow` 中的 4 个 `Button` 改为 `PanelContainer`（卡片容器），按钮移到 `ShopRow`，新增回收区控件。布局改为两行：TopRow（信息栏）和 BottomRow（卡片 + 操作按钮）。

新的场景树结构：
```
ShopOverlay (CanvasLayer, layer=10)
└── ShopPanel (PanelContainer, bottom-anchored)
    └── VBoxContainer
        ├── TopRow (HBoxContainer) — 信息栏
        │   ├── CoinsLabel
        │   ├── LevelLabel
        │   ├── PopLabel
        │   └── WaveLabel
        └── BottomRow (HBoxContainer) — 操作栏
            ├── CardContainer (HBoxContainer)
            │   ├── ShopCard0 (PanelContainer)
            │   │   └── VBoxContainer
            │   │       ├── Icon (TextureRect, 32x32)
            │   │       ├── NameLabel (Label)
            │   │       └── PriceLabel (Label)
            │   ├── ShopCard1 ...
            │   ├── ShopCard2 ...
            │   └── ShopCard3 ...
            ├── ButtonContainer (VBoxContainer)
            │   ├── RefreshButton
            │   └── LevelUpButton
            ├── RecycleArea (PanelContainer)
            │   └── RecycleLabel (Label, "回收")
            └── StartButton
```

由于场景结构较复杂，使用代码在 `_setup_ui()` 中动态创建卡片节点更灵活，场景文件只保留骨架结构。

实际 `.tscn` 保留：ShopPanel → VBoxContainer → TopRow + BottomRow（HBoxContainer），其余由代码创建。

- [ ] **Step 2: 提交场景修改**

```bash
git add scenes/ui/shop_overlay.tscn
git commit -m "refactor: shop_overlay.tscn 删除 BagRow，改为两行布局骨架"
```

### Task 6: 重写 shop_overlay.gd 卡片逻辑

**Files:**
- Modify: `scripts/ui/shop_overlay.gd`
- Test: `tests/unit/test_shop_overlay.gd`

- [ ] **Step 1: 重写 shop_overlay.gd**

完整重写 `scripts/ui/shop_overlay.gd`：

```gdscript
extends CanvasLayer
## 底部商店面板覆盖层 — 卡片式 UI

signal start_battle_pressed

const SLIDE_DURATION := 0.3
const CARD_ICON_SIZE := Vector2(32, 32)

var _shop_manager: ShopManager
var _panel: PanelContainer
var _slide_original_y: float = 0.0

# 信息栏
var _coins_label: Label
var _level_label: Label
var _pop_label: Label
var _wave_label: Label

# 操作按钮
var _level_up_button: Button
var _refresh_button: Button
var _start_button: Button

# 卡片
var _card_containers: Array[PanelContainer] = []
var _card_icons: Array[TextureRect] = []
var _card_names: Array[Label] = []
var _card_prices: Array[Label] = []
var _card_buttons: Array[Button] = []  # 覆盖在卡片上的透明按钮

# 回收区
var _recycle_area: PanelContainer

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

func _setup_ui() -> void:
	_panel = $ShopPanel
	_slide_original_y = _panel.position.y

	# 信息栏
	_coins_label = $ShopPanel/VBoxContainer/TopRow/CoinsLabel
	_level_label = $ShopPanel/VBoxContainer/TopRow/LevelLabel
	_pop_label = $ShopPanel/VBoxContainer/TopRow/PopLabel
	_wave_label = $ShopPanel/VBoxContainer/TopRow/WaveLabel

	# BottomRow
	var bottom_row: HBoxContainer = $ShopPanel/VBoxContainer/BottomRow

	# 动态创建 4 张卡片
	var card_container := HBoxContainer.new()
	card_container.name = "CardContainer"
	card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_container.add_theme_constant_override("separation", 4)
	bottom_row.add_child(card_container)

	for i in range(4):
		var card := _create_card(i)
		card_container.add_child(card)

	# 按钮容器
	var btn_container := VBoxContainer.new()
	btn_container.name = "ButtonContainer"
	bottom_row.add_child(btn_container)

	_refresh_button = Button.new()
	_refresh_button.text = "刷新 $2"
	_refresh_button.pressed.connect(_on_refresh_pressed)
	btn_container.add_child(_refresh_button)

	_level_up_button = Button.new()
	_level_up_button.text = "Lv↑"
	_level_up_button.pressed.connect(_on_level_up_pressed)
	btn_container.add_child(_level_up_button)

	# 回收区
	_recycle_area = PanelContainer.new()
	_recycle_area.name = "RecycleArea"
	_recycle_area.custom_minimum_size = Vector2(50, 50)
	var recycle_label := Label.new()
	recycle_label.text = "回收"
	recycle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recycle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_recycle_area.add_child(recycle_label)
	bottom_row.add_child(_recycle_area)

	# 开战按钮
	_start_button = Button.new()
	_start_button.text = "开战"
	_start_button.pressed.connect(_on_start_pressed)
	bottom_row.add_child(_start_button)

func _create_card(index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "ShopCard%d" % index
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(60, 80)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = CARD_ICON_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
	vbox.add_child(price_label)
	_card_prices.append(price_label)

	# 透明点击按钮覆盖整个卡片
	var btn := Button.new()
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.anchors_preset = Control.PRESET_FULL_RECT
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
	_update_level_up_button()

func _update_info_bar() -> void:
	_coins_label.text = "$%d" % GameData.coins
	_level_label.text = "Lv.%d" % GameData.player_level
	var pop_current: int = GameData.deployed_weapons.size() + GameData.deployed_towers.size()
	var pop_max: int = GameConfig.shop_config.population_per_level[GameData.player_level - 1]
	_pop_label.text = "人口 %d/%d" % [pop_current, pop_max]
	_wave_label.text = "Wave %d" % GameData.current_wave

func _update_cards() -> void:
	var is_placing: bool = _pending_tower_slot_index >= 0
	for i in range(4):
		if i < GameData.shop_slots.size() and not GameData.shop_slots[i].is_empty():
			var slot_data: Dictionary = GameData.shop_slots[i]
			var item_data: Resource = _get_item_data(slot_data.id)

			# 图标
			if item_data and item_data.icon_path != "" and ResourceLoader.exists(item_data.icon_path):
				_card_icons[i].texture = load(item_data.icon_path)
			else:
				_card_icons[i].texture = null

			# 名称
			_card_names[i].text = item_data.display_name if item_data else slot_data.id

			# 价格
			_card_prices[i].text = "$%d" % slot_data.cost

			# 禁用判断
			var can_buy: bool = GameData.coins >= slot_data.cost and GameData.can_buy_item(slot_data.id, 1)
			_card_buttons[i].disabled = not can_buy or is_placing

			# 放置中状态
			if is_placing and i == _pending_tower_slot_index:
				_card_names[i].text = "放置中"
				_card_buttons[i].disabled = true

			# 卡片视觉
			_card_containers[i].modulate = Color.WHITE if (can_buy and not is_placing) else Color(0.5, 0.5, 0.5)
		else:
			_card_icons[i].texture = null
			_card_names[i].text = "已售出"
			_card_prices[i].text = ""
			_card_buttons[i].disabled = true
			_card_containers[i].modulate = Color(0.5, 0.5, 0.5)

func _update_level_up_button() -> void:
	var max_level: int = GameConfig.shop_config.level_up_costs.size() + 1
	if GameData.player_level >= max_level:
		_level_up_button.text = "满级"
		_level_up_button.disabled = true
	else:
		var cost: int = GameConfig.shop_config.level_up_costs[GameData.player_level - 1]
		_level_up_button.text = "Lv↑ $%d" % cost
		_level_up_button.disabled = GameData.coins < cost

func _on_shop_slot_pressed(slot_index: int) -> void:
	var slot: Dictionary = GameData.shop_slots[slot_index]
	if slot.is_empty():
		return
	if slot.type == "weapon":
		var success: bool = _shop_manager.buy_weapon(slot_index)
		if success:
			_handle_merge_weapon_cleanup()
			_update_ui()
	elif slot.type == "tower":
		var tower_slot: Dictionary = _shop_manager.get_tower_slot(slot_index)
		if not tower_slot.is_empty():
			_pending_tower_slot_index = slot_index
			_update_cards()  # 立即更新为"放置中"状态，禁用其他卡片和开战按钮
			_start_button.disabled = true
			drag_manager.start_tower_placement(
				tower_slot.id,
				_on_tower_placed,
				_on_tower_placement_cancelled
			)

func _on_tower_placed(grid_pos: Vector2i) -> void:
	if _pending_tower_slot_index < 0:
		return
	var slot: Dictionary = GameData.shop_slots[_pending_tower_slot_index]
	var tower_id: String = slot.id if not slot.is_empty() else ""
	var snapshot: Array = GameData.deployed_towers.duplicate(true)
	var deploy_id: int = _shop_manager.confirm_tower_purchase(_pending_tower_slot_index, grid_pos)
	if deploy_id > 0:
		drag_manager.spawn_tower_node(deploy_id, tower_id, 1, grid_pos)
		_handle_merge_tower_cleanup(snapshot)
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
	GameData.buy_level_up()
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

func _handle_merge_weapon_cleanup() -> void:
	if weapon_manager:
		weapon_manager.refresh_weapons()

func _handle_merge_tower_cleanup(snapshot: Array) -> void:
	if drag_manager == null:
		return
	var current_ids: Array[int] = []
	var current_map: Dictionary = {}  # deploy_id → entry
	for entry in GameData.deployed_towers:
		current_ids.append(entry.deploy_id)
		current_map[entry.deploy_id] = entry

	# 移除被合成消耗的塔节点
	var consumed_ids: Array[int] = []
	for entry in snapshot:
		if entry.deploy_id not in current_ids:
			consumed_ids.append(entry.deploy_id)
	if consumed_ids.size() > 0:
		drag_manager.remove_tower_nodes(consumed_ids)

	# 升级存活塔的视觉
	for entry in GameData.deployed_towers:
		# 检查是否有等级变化（合成产物）
		for old_entry in snapshot:
			if old_entry.deploy_id == entry.deploy_id and old_entry.level != entry.level:
				drag_manager.upgrade_tower_node(entry.deploy_id, entry.id, entry.level, entry.grid_pos)
				break

func _on_weapon_sold(weapon_index: int) -> void:
	var refund: int = GameData.sell_from_deployed_weapon(weapon_index)
	if refund > 0 and weapon_manager:
		weapon_manager.remove_weapon(weapon_index)
	_update_ui()

func get_recycle_area() -> Control:
	return _recycle_area

func _get_item_data(item_id: String) -> Resource:
	if GameConfig.weapons.has(item_id):
		return GameConfig.weapons[item_id]
	if GameConfig.towers.has(item_id):
		return GameConfig.towers[item_id]
	return null
```

- [ ] **Step 2: 更新 shop_overlay.tscn 匹配新结构**

重写 `scenes/ui/shop_overlay.tscn`，只保留骨架（TopRow 信息栏 + BottomRow 空容器），卡片和按钮由代码创建：

```tscn
[gd_scene format=3 uid="uid://dkqv7xm2w3a8p"]

[ext_resource type="Script" path="res://scripts/ui/shop_overlay.gd" id="1_shop"]

[node name="ShopOverlay" type="CanvasLayer"]
layer = 10
script = ExtResource("1_shop")

[node name="ShopPanel" type="PanelContainer" parent="."]
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -140.0
grow_horizontal = 2
grow_vertical = 0

[node name="VBoxContainer" type="VBoxContainer" parent="ShopPanel"]
layout_mode = 2
theme_override_constants/separation = 4

[node name="TopRow" type="HBoxContainer" parent="ShopPanel/VBoxContainer"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="CoinsLabel" type="Label" parent="ShopPanel/VBoxContainer/TopRow"]
layout_mode = 2
text = "$0"

[node name="LevelLabel" type="Label" parent="ShopPanel/VBoxContainer/TopRow"]
layout_mode = 2
text = "Lv.1"

[node name="PopLabel" type="Label" parent="ShopPanel/VBoxContainer/TopRow"]
layout_mode = 2
text = "人口 0/2"

[node name="WaveLabel" type="Label" parent="ShopPanel/VBoxContainer/TopRow"]
layout_mode = 2
text = "Wave 0"

[node name="BottomRow" type="HBoxContainer" parent="ShopPanel/VBoxContainer"]
layout_mode = 2
theme_override_constants/separation = 4
```

- [ ] **Step 3: 更新 test_shop_overlay.gd**

```gdscript
# tests/unit/test_shop_overlay.gd
extends GutTest

var _overlay: CanvasLayer

func before_each() -> void:
	GameData.reset()
	GameData.coins = 100
	GameData.player_level = 1
	GameData.deployed_weapons = []
	GameData.deployed_towers = []
	_overlay = load("res://scenes/ui/shop_overlay.tscn").instantiate()
	add_child(_overlay)

func after_each() -> void:
	_overlay.queue_free()

func test_refresh_shop_populates_cards() -> void:
	_overlay.refresh_shop()
	assert_eq(GameData.shop_slots.size(), 4)
	# 至少有一个卡片名称不为"已售出"
	var has_item := false
	for label in _overlay._card_names:
		if label.text != "已售出":
			has_item = true
			break
	assert_true(has_item, "刷新后应有可购买的卡片")

func test_start_battle_signal() -> void:
	var signal_emitted := false
	_overlay.start_battle_pressed.connect(func(): signal_emitted = true)
	_overlay._on_start_pressed()
	assert_true(signal_emitted)

func test_card_disabled_when_insufficient_coins() -> void:
	GameData.coins = 0
	_overlay.refresh_shop()
	for btn in _overlay._card_buttons:
		if not GameData.shop_slots[_overlay._card_buttons.find(btn)].is_empty():
			assert_true(btn.disabled, "金币不足时卡片应禁用")

func test_recycle_area_exists() -> void:
	assert_not_null(_overlay.get_recycle_area())
```

- [ ] **Step 4: 运行测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_shop_overlay.gd`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/ui/shop_overlay.gd scenes/ui/shop_overlay.tscn tests/unit/test_shop_overlay.gd
git commit -m "feat: ShopOverlay 卡片 UI 重构，回收区，两行布局"
```

## Chunk 5: main.gd 集成和清理

### Task 7: main.gd 清理和集成

**Files:**
- Modify: `scripts/ui/main.gd`

- [ ] **Step 1: 删除调试代码，注入 weapon_manager 引用**

```gdscript
extends Node2D

enum Phase { SHOP, BATTLE }

var current_phase: Phase = Phase.SHOP
var _tower_container: Node2D = null
var _shop_overlay: CanvasLayer = null
var _drag_manager: Node = null

func _ready() -> void:
	_tower_container = Node2D.new()
	_tower_container.name = "TowerContainer"
	add_child(_tower_container)

	_load_map()

	# ShopOverlay
	_shop_overlay = $ShopOverlay
	_shop_overlay.start_battle_pressed.connect(_on_start_battle)

	# DragManager
	_drag_manager = $DragManager
	_drag_manager.initialize(_tower_container, $Player)
	_shop_overlay.drag_manager = _drag_manager

	# WeaponManager 注入（Player 的子节点）
	var player: Node2D = $Player
	if player.has_node("WeaponManager"):
		_shop_overlay.weapon_manager = player.get_node("WeaponManager")

	# 回收区注入
	_drag_manager.set_recycle_area(_shop_overlay.get_recycle_area())

	# 暂停覆盖层
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
	AudioManager.play_bgm("placement")
	$HUD.set_battle_phase(false)

func _enter_battle_phase() -> void:
	current_phase = Phase.BATTLE
	_shop_overlay.slide_out()
	AudioManager.play_bgm("battle")
	$HUD.set_battle_phase(true)
	$WaveManager.start_next_wave()

func _on_start_battle() -> void:
	if current_phase == Phase.SHOP:
		_enter_battle_phase()

func _on_wave_transition_ready() -> void:
	_enter_shop_phase()

func _load_map() -> void:
	var map_data: MapData = GameConfig.maps.get(GameData.selected_map)
	if map_data == null or map_data.map_scene.is_empty():
		push_warning("地图场景未配置，跳过加载: " + GameData.selected_map)
		return
	if not ResourceLoader.exists(map_data.map_scene):
		push_warning("地图场景文件不存在: " + map_data.map_scene)
		return
	var map_instance = load(map_data.map_scene).instantiate()
	add_child(map_instance)
	move_child(map_instance, 0)

func _on_coins_generated(amount: int, _pos: Vector2) -> void:
	var player: Node2D = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	if player and player.has_method("add_coins"):
		player.add_coins(amount)
	else:
		GameData.coins += amount
```

- [ ] **Step 2: 运行全部测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit`
Expected: 所有测试 PASS

- [ ] **Step 3: 提交**

```bash
git add scripts/ui/main.gd
git commit -m "refactor: main.gd 删除调试代码，注入 weapon_manager 和回收区"
```

### Task 8: 清理 EventBus 废弃信号

**Files:**
- Modify: `scripts/core/event_bus.gd`

- [ ] **Step 1: 检查 item_deployed 和 item_undeployed 信号是否有引用**

搜索项目中是否有代码连接或发射这两个信号。如果没有引用则删除。

- [ ] **Step 2: 删除废弃信号**

```gdscript
# 删除这两行
signal item_deployed(item: Dictionary)
signal item_undeployed(item: Dictionary)
```

- [ ] **Step 3: 运行全部测试确认无破坏**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit`
Expected: 所有测试 PASS

- [ ] **Step 4: 提交**

```bash
git add scripts/core/event_bus.gd
git commit -m "chore: 清理 EventBus 废弃信号 item_deployed/item_undeployed"
```

## Chunk 6: 端到端验证

### Task 9: 全量测试 + 编辑器验证

- [ ] **Step 1: 运行全部单元测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 所有测试 PASS

- [ ] **Step 2: 在 Godot 编辑器中运行项目**

通过 MCP 的 `play_scene` 工具运行 main 场景，验证：
1. 商店面板显示 4 张卡片（有图标、名称、价格）
2. 点击武器卡片 → 武器出现在角色身上旋转
3. 点击塔卡片 → 进入放置模式 → 放置成功后扣金币
4. 塔放置中其他卡片和开战按钮禁用
5. 拖拽塔到回收区 → 卖出返金
6. 人口满时能合成的卡片仍可购买
7. 刷新、升级、开战按钮正常

- [ ] **Step 3: 修复发现的问题**

根据测试和编辑器验证结果修复问题。

- [ ] **Step 4: 最终提交**

```bash
git add -A
git commit -m "fix: 商店重构端到端验证修复"
```
