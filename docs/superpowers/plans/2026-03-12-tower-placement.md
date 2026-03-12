# Tower Placement System Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore tower placement into the game loop with a unified preparation screen (placement + shop tabs), left sidebar UI, and drag/click tower placement on a grid map.

**Architecture:** Refactor existing `placement.tscn`/`placement.gd` into a unified preparation scene with tab-switching sidebar. Split into three scripts: `placement.gd` (main controller), `placement_panel.gd` (tower placement sidebar), `shop_panel.gd` (shop sidebar). Reuse existing `ShopItemGenerator` and `ShopEffectApplier`. Change game flow to route through placement before every battle wave.

**Tech Stack:** Godot 4.6, GDScript, GUT testing framework

**Spec:** `docs/superpowers/specs/2026-03-12-tower-placement-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Rewrite | `scripts/ui/placement.gd` | Main controller: scene init, tab switching, camera, grid, start battle |
| Create | `scripts/ui/placement_panel.gd` | Tower placement sidebar: cards, click/drag, place/remove |
| Create | `scripts/ui/shop_panel.gd` | Shop sidebar: item generation, buy, refresh |
| Rewrite | `scenes/levels/placement.tscn` | Scene structure with SidePanel + tabs |
| Modify | `scripts/systems/wave_manager.gd:61` | Change `go_to(SHOP)` → `go_to(PLACEMENT)` |
| Modify | `scripts/ui/map_select.gd:117` | Change `go_to(MAIN)` → `go_to(PLACEMENT)` |
| Modify | `scripts/ui/main.gd` | Restore towers from `GameData.tower_inventory` in `_ready()` |
| Modify | `scripts/systems/shop_item_generator.gd:13-20,65-66` | Remove tower effect type filter |
| Modify | `scripts/core/scene_manager.gd:7` | Remove `shop` entry from SCENES |
| Modify | `scripts/core/enums.gd:17` | Remove `SHOP` constant from Scene |
| Create | `tests/unit/test_placement_panel.gd` | Placement panel unit tests |
| Create | `tests/unit/test_shop_panel.gd` | Shop panel unit tests |
| Modify | `tests/unit/test_placement_grid_rules.gd` | Adapt to new placement.gd API |
| Modify | `tests/unit/test_shop_manager_logic.gd` | Verify tower filter removed |

---

## Chunk 1: Flow Routing & Shop Filter Removal

These are small, low-risk changes that redirect the game flow and re-enable tower shop items.

### Task 1: Remove tower effect type filter from ShopItemGenerator

**Files:**
- Modify: `scripts/systems/shop_item_generator.gd:13-20,65-66`
- Test: `tests/unit/test_shop_manager_logic.gd`

- [ ] **Step 1: Write failing test — tower items appear in generated shop**

Add to `tests/unit/test_shop_manager_logic.gd`:

```gdscript
func test_tower_effect_items_not_filtered():
	var result := generator.generate_items(
		5, PackedStringArray(), 0.0,
		[false, false, false, false], [], [])
	# 确保生成池包含塔相关物品（不再过滤）
	var all_items: Array = GameConfig.items.values()
	var tower_items: Array = all_items.filter(func(it: ShopItemData) -> bool:
		return it.effect_type in [
			Enums.ItemEffect.TOWER_STAT,
			Enums.ItemEffect.TOWER_LINK,
			Enums.ItemEffect.WAVE_HEAL_TOWERS,
			Enums.ItemEffect.TOWER_REGEN,
			Enums.ItemEffect.SYMBIOSIS,
			Enums.ItemEffect.WAR_MACHINE,
		])
	assert_gt(tower_items.size(), 0, "GameConfig 应有塔相关物品")
```

- [ ] **Step 2: Run test to verify it passes (this test validates config, should pass already)**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_shop_manager_logic.gd`

- [ ] **Step 3: Remove tower filter from ShopItemGenerator**

In `scripts/systems/shop_item_generator.gd`:

Delete lines 12-20 (the `TOWER_EFFECT_TYPES` constant) and lines 65-66 (the filter check):

```gdscript
# DELETE these lines:
# 塔相关 effect_type 黑名单（幸存者模式下过滤）
const TOWER_EFFECT_TYPES: Array = [
	Enums.ItemEffect.TOWER_STAT,
	Enums.ItemEffect.TOWER_LINK,
	Enums.ItemEffect.WAVE_HEAL_TOWERS,
	Enums.ItemEffect.TOWER_REGEN,
	Enums.ItemEffect.SYMBIOSIS,
	Enums.ItemEffect.WAR_MACHINE,
]

# DELETE these lines inside generate_items():
		if item.effect_type in TOWER_EFFECT_TYPES:
			continue
```

- [ ] **Step 4: Run all shop tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_shop_manager_logic.gd`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add scripts/systems/shop_item_generator.gd tests/unit/test_shop_manager_logic.gd
git commit -m "feat: 移除商店塔相关物品过滤，恢复塔升级物品"
```

### Task 2: Change game flow routing

**Files:**
- Modify: `scripts/ui/map_select.gd:117`
- Modify: `scripts/systems/wave_manager.gd:61`
- Modify: `scripts/core/scene_manager.gd:7`

- [ ] **Step 1: Change map_select to route to placement**

In `scripts/ui/map_select.gd`, line 117, change:
```gdscript
# OLD:
SceneManager.go_to(Enums.Scene.MAIN)
# NEW:
SceneManager.go_to(Enums.Scene.PLACEMENT)
```

- [ ] **Step 2: Change wave_manager to route to placement after wave**

In `scripts/systems/wave_manager.gd`, line 61, change:
```gdscript
# OLD:
SceneManager.go_to(Enums.Scene.SHOP)
# NEW:
SceneManager.go_to(Enums.Scene.PLACEMENT)
```

- [ ] **Step 3: Remove shop entry from SceneManager**

In `scripts/core/scene_manager.gd`, delete line 7:
```gdscript
# DELETE:
"shop": "res://scenes/ui/shop.tscn",
```

- [ ] **Step 4: Remove SHOP constant from Enums**

In `scripts/core/enums.gd`, delete line 17:
```gdscript
# DELETE:
const SHOP = "shop"
```

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/map_select.gd scripts/systems/wave_manager.gd scripts/core/scene_manager.gd scripts/core/enums.gd
git commit -m "feat: 游戏流程改为经过 placement 场景（map_select→placement→main→placement）"
```

### Task 3: Add tower restoration in main.gd

**Files:**
- Modify: `scripts/ui/main.gd`

- [ ] **Step 1: Add tower restoration logic in _ready()**

In `scripts/ui/main.gd`, add after `_load_map()` call (line 4):

```gdscript
func _ready() -> void:
	_load_map()
	_restore_towers()
	# 暂停覆盖层
	var pause_overlay = load("res://scripts/ui/pause_overlay.gd").new()
	add_child(pause_overlay)
	# 调试面板
	var debug_panel = load("res://scripts/ui/debug_panel.gd").new()
	add_child(debug_panel)

func _restore_towers() -> void:
	for tower_entry in GameData.tower_inventory:
		var tower_type: String = tower_entry["type"]
		var tower_pos: Vector2 = tower_entry["position"]
		var tower: Node2D = SceneFactory.create_tower(tower_type)
		if tower:
			tower.global_position = tower_pos
			tower.add_to_group(Enums.Group.TOWERS)
			add_child(tower)
```

- [ ] **Step 2: Commit**

```bash
git add scripts/ui/main.gd
git commit -m "feat: main 场景启动时从 GameData.tower_inventory 还原塔"
```

---

## Chunk 2: Placement Scene UI Rebuild

Rebuild the placement scene with the new left-sidebar layout and tab switching.

### Task 4: Rewrite placement.tscn scene structure

**Files:**
- Rewrite: `scenes/levels/placement.tscn`

- [ ] **Step 1: Rebuild placement.tscn with new UI layout**

Use Godot MCP tools to rebuild the scene. The scene structure should be:

```
Placement (Node2D, script: placement.gd)
├── Background (Node2D, z_index=-100)
│   └── BackgroundSprite (Sprite2D, centered=true)
├── Player (CharacterBody2D, instance: player.tscn)
├── MapBoundary (instance: map_boundary.tscn)
└── UI (CanvasLayer)
    └── SidePanel (VBoxContainer, anchor: left full height, 120px wide, mouse_filter=STOP)
        ├── TabBar (HBoxContainer)
        │   ├── PlacementTab (Button, text="布置", toggle_mode=true, button_pressed=true)
        │   └── ShopTab (Button, text="商店", toggle_mode=true)
        ├── CoinsLabel (Label, text="金币: 0")
        ├── PlacementContent (VBoxContainer)
        │   └── TowerList (VBoxContainer)
        ├── ShopContent (VBoxContainer, visible=false)
        │   ├── ShopItemList (VBoxContainer)
        │   └── RefreshButton (Button, text="刷新 (5)")
        └── StartBattleButton (Button, text="开始战斗")
```

Key properties:
- SidePanel: `anchor_left=0, anchor_top=0, anchor_right=0, anchor_bottom=1`, `offset_right=120`, `mouse_filter=Control.MOUSE_FILTER_STOP`
- PlacementTab/ShopTab: both `toggle_mode=true`, grouped via ButtonGroup
- ShopContent: `visible=false` initially (hidden on first wave)

Build this using gdai-mcp `create_scene`, `add_node`, `update_property`, `attach_script` tools. Or edit the .tscn file directly matching existing patterns.

- [ ] **Step 2: Commit**

```bash
git add scenes/levels/placement.tscn
git commit -m "refactor: 重构 placement.tscn 为左侧栏+Tab 布局"
```

### Task 5: Rewrite placement.gd main controller

**Files:**
- Rewrite: `scripts/ui/placement.gd`

- [ ] **Step 1: Write placement.gd**

```gdscript
extends Node2D

const GRID_SIZE = GameConfig.GRID_SIZE
const CAMERA_PAN_SPEED = 600.0
const ZOOM_STEP = 1.15
const ZOOM_MIN = Vector2(0.25, 0.25)
const ZOOM_MAX = Vector2(2.0, 2.0)
const PLACEMENT_ZOOM_INIT = Vector2(0.375, 0.375)
const SIDEBAR_WIDTH = 120.0

@onready var _placement_content: VBoxContainer = $UI/SidePanel/PlacementContent
@onready var _shop_content: VBoxContainer = $UI/SidePanel/ShopContent
@onready var _placement_tab: Button = $UI/SidePanel/TabBar/PlacementTab
@onready var _shop_tab: Button = $UI/SidePanel/TabBar/ShopTab
@onready var _coins_label: Label = $UI/SidePanel/CoinsLabel
@onready var _start_button: Button = $UI/SidePanel/StartBattleButton
@onready var background_sprite: Sprite2D = $Background/BackgroundSprite

var _placement_camera: Camera2D = null
var _grid_overlay: Node2D = null
var _range_indicator: RangeIndicator = null
var _placement_panel: Node = null
var _shop_panel: Node = null

signal coins_changed

func _ready() -> void:
	_load_map_background()

	# 网格覆层
	_grid_overlay = preload("res://scripts/ui/grid_overlay.gd").new()
	_grid_overlay.z_index = -50
	add_child(_grid_overlay)

	# 范围指示器
	_range_indicator = RangeIndicator.new()
	_range_indicator.z_index = -40
	add_child(_range_indicator)

	# 恢复之前布置的塔
	for tower_data in GameData.tower_inventory:
		var tower_type: String = tower_data["type"]
		var tower_pos: Vector2 = tower_data["position"]
		var tower: Node2D = SceneFactory.create_tower(tower_type)
		if tower:
			tower.global_position = tower_pos
			tower.add_to_group(Enums.Group.TOWERS)
			add_child(tower)

	# 将商店购买的塔转为金币
	for tower_type in GameData.purchased_towers:
		GameData.coins += SceneFactory.get_tower_cost(tower_type)
	GameData.purchased_towers.clear()

	# 初始化布置面板
	_placement_panel = preload("res://scripts/ui/placement_panel.gd").new()
	_placement_content.add_child(_placement_panel)
	_placement_panel.initialize(self, _range_indicator)

	# 初始化商店面板（非首波才可见）
	_shop_panel = preload("res://scripts/ui/shop_panel.gd").new()
	_shop_content.add_child(_shop_panel)
	_shop_panel.initialize(self)

	# Tab 切换
	_placement_tab.pressed.connect(func(): _switch_tab(true))
	_shop_tab.pressed.connect(func(): _switch_tab(false))

	# 首波隐藏商店 Tab
	if GameData.current_wave == 0:
		_shop_tab.visible = false
		_switch_tab(true)
	else:
		_shop_tab.visible = true
		_switch_tab(false)  # 非首波默认商店 Tab

	# 开始战斗按钮
	_start_button.pressed.connect(_start_battle)

	# 冻结玩家
	$Player.set_physics_process(false)

	# 布置相机
	_placement_camera = Camera2D.new()
	_placement_camera.zoom = PLACEMENT_ZOOM_INIT
	_placement_camera.position_smoothing_enabled = false
	_placement_camera.limit_left = -int(GameConfig.MAP_HALF_WIDTH)
	_placement_camera.limit_right = int(GameConfig.MAP_HALF_WIDTH)
	_placement_camera.limit_top = -int(GameConfig.MAP_HALF_HEIGHT)
	_placement_camera.limit_bottom = int(GameConfig.MAP_HALF_HEIGHT)
	add_child(_placement_camera)
	_placement_camera.make_current()

	update_coins_display()

func _process(delta: float) -> void:
	if _placement_camera:
		var pan := Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down")
		)
		_placement_camera.position += pan * CAMERA_PAN_SPEED * delta

func _input(event: InputEvent) -> void:
	# 检查鼠标是否在侧栏区域
	if event is InputEventMouse:
		var viewport_pos: Vector2 = event.position
		if viewport_pos.x < SIDEBAR_WIDTH:
			return

	# 滚轮缩放
	if event is InputEventMouseButton and event.pressed and _placement_camera:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_placement_camera.zoom = (_placement_camera.zoom * ZOOM_STEP).clamp(ZOOM_MIN, ZOOM_MAX)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_placement_camera.zoom = (_placement_camera.zoom / ZOOM_STEP).clamp(ZOOM_MIN, ZOOM_MAX)
			get_viewport().set_input_as_handled()
			return

	# ESC 处理
	if event.is_action_pressed("ui_cancel"):
		if _placement_panel and _placement_panel.has_preview():
			_placement_panel.cancel_placement()
		else:
			# 暂停菜单（复用 PauseOverlay 通过 pause_mode）
			get_tree().paused = not get_tree().paused
		get_viewport().set_input_as_handled()
		return

func _switch_tab(is_placement: bool) -> void:
	_placement_content.visible = is_placement
	_shop_content.visible = not is_placement
	_placement_tab.button_pressed = is_placement
	_shop_tab.button_pressed = not is_placement

func update_coins_display() -> void:
	_coins_label.text = "金币: %d" % GameData.coins
	coins_changed.emit()

func get_grid_position(pos: Vector2) -> Vector2:
	return Vector2(
		floor(pos.x / GRID_SIZE) * GRID_SIZE + GRID_SIZE / 2.0,
		floor(pos.y / GRID_SIZE) * GRID_SIZE + GRID_SIZE / 2.0
	)

func can_place_at(pos: Vector2) -> bool:
	if abs(pos.x) > GameConfig.MAP_HALF_WIDTH or abs(pos.y) > GameConfig.MAP_HALF_HEIGHT:
		return false
	var towers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.TOWERS)
	for tower in towers:
		if tower.global_position.distance_to(pos) < GRID_SIZE:
			return false
	var player = $Player
	if player.global_position.distance_to(pos) < GRID_SIZE:
		return false
	return true

func find_tower_at(pos: Vector2) -> Node2D:
	var towers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.TOWERS)
	var closest: Node2D = null
	var min_dist: float = GRID_SIZE / 2.0
	for tower in towers:
		var dist: float = tower.global_position.distance_to(pos)
		if dist < min_dist:
			min_dist = dist
			closest = tower
	return closest

func _start_battle() -> void:
	var towers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.TOWERS)
	var current_towers: Array[Dictionary] = []
	for tower in towers:
		var tower_type: String = ""
		if "tower_type" in tower:
			tower_type = tower.tower_type
		if tower_type != "":
			current_towers.append({
				"type": tower_type,
				"position": tower.global_position
			})
	GameData.tower_inventory = current_towers
	SceneManager.go_to(Enums.Scene.MAIN)

func _load_map_background() -> void:
	var map_id: String = GameData.selected_map
	if not GameConfig.maps.has(map_id):
		push_warning("未知地图: " + map_id + ", 使用默认地图")
		map_id = Enums.Map.FOREST
		GameData.selected_map = map_id
	var md: MapData = GameConfig.maps[map_id]
	var bg_path: String = md.background
	if ResourceLoader.exists(bg_path):
		var bg_texture: Resource = load(bg_path)
		if bg_texture and background_sprite:
			background_sprite.texture = bg_texture
		else:
			_use_fallback_background(map_id)
	else:
		_use_fallback_background(map_id)

func _use_fallback_background(map_id: String) -> void:
	if background_sprite:
		background_sprite.queue_free()
	var map_size: Vector2 = Vector2(GameConfig.MAP_PIXEL_WIDTH, GameConfig.MAP_PIXEL_HEIGHT)
	var color_rect: ColorRect = ColorRect.new()
	color_rect.size = map_size
	color_rect.position = -map_size / 2
	var md: MapData = GameConfig.maps[map_id]
	color_rect.color = Color(md.fallback_color)
	$Background.add_child(color_rect)
```

- [ ] **Step 2: Commit**

```bash
git add scripts/ui/placement.gd
git commit -m "refactor: 重写 placement.gd 为主控脚本（Tab切换、相机、网格、输入路由）"
```

### Task 6: Create placement_panel.gd

**Files:**
- Create: `scripts/ui/placement_panel.gd`

- [ ] **Step 1: Write placement_panel.gd**

```gdscript
extends Node
## 布置侧栏：塔卡片管理、点击/拖放、放置/移除逻辑

const DRAG_THRESHOLD: float = 5.0

var _main: Node2D = null  # placement.gd 主控引用
var _range_indicator: RangeIndicator = null
var _preview_tower: Node2D = null
var _selected_tower_type: String = ""
var _selected_placed_tower: Node2D = null
var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_tower_type: String = ""
var _tower_buttons: Dictionary = {}

func initialize(main: Node2D, range_indicator: RangeIndicator) -> void:
	_main = main
	_range_indicator = range_indicator
	_create_tower_cards()
	_update_buttons()
	_main.coins_changed.connect(_update_buttons)

func _create_tower_cards() -> void:
	var tower_types: Array = [Enums.TowerId.SHOOTER, Enums.TowerId.WALL, Enums.TowerId.SLOW]
	var tower_names: Dictionary = {
		Enums.TowerId.SHOOTER: "射手塔",
		Enums.TowerId.WALL: "墙塔",
		Enums.TowerId.SLOW: "减速塔",
	}
	for tower_type in tower_types:
		var cost: int = SceneFactory.get_tower_cost(tower_type)
		var card := _create_card(tower_type, tower_names[tower_type], cost)
		get_parent().get_node("TowerList").add_child(card)
		_tower_buttons[tower_type] = card

func _create_card(tower_type: String, display_name: String, cost: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(108, 60)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var name_label := Label.new()
	name_label.text = display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(name_label)

	var cost_label := Label.new()
	cost_label.text = "%d 金" % cost
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 10)
	cost_label.add_theme_color_override("font_color", Color("#e0c040"))
	vbox.add_child(cost_label)

	# 点击和拖放事件
	card.gui_input.connect(func(event: InputEvent): _on_card_input(event, tower_type))

	return card

func _on_card_input(event: InputEvent, tower_type: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cost: int = SceneFactory.get_tower_cost(tower_type)
		if GameData.coins < cost:
			return
		_drag_start_pos = event.global_position
		_drag_tower_type = tower_type

	elif event is InputEventMouseMotion and _drag_tower_type != "":
		if not _is_dragging:
			var dist: float = event.global_position.distance_to(_drag_start_pos)
			if dist > DRAG_THRESHOLD:
				_is_dragging = true
				# 拖放开始：创建预览（与点击选中共用同一套预览逻辑）
				_select_tower(_drag_tower_type)

	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_dragging and _preview_tower:
			# 拖放松开：尝试放置
			_place_tower()
		elif not _is_dragging and _drag_tower_type != "":
			# 短点击：选中模式（预览跟随鼠标，左键再点放置）
			_select_tower(_drag_tower_type)
		_drag_tower_type = ""
		_is_dragging = false

func _select_tower(type: String) -> void:
	_deselect_tower()
	var cost: int = SceneFactory.get_tower_cost(type)
	if GameData.coins < cost:
		return
	_selected_tower_type = type
	_cancel_preview()
	_preview_tower = SceneFactory.create_tower(type)
	if _preview_tower:
		_preview_tower.modulate = Color(1, 1, 1, 0.5)
		_main.add_child(_preview_tower)
		var td: TowerData = GameConfig.towers[type]
		_range_indicator.set_range(td.attack_range)

func _process(_delta: float) -> void:
	if _preview_tower and _main:
		var grid_pos: Vector2 = _main.get_grid_position(_main.get_global_mouse_position())
		_preview_tower.global_position = grid_pos
		_range_indicator.global_position = grid_pos
		if _main.can_place_at(grid_pos):
			_preview_tower.modulate = Color(1, 1, 1, 0.5)
		else:
			_preview_tower.modulate = Color(1, 0.3, 0.3, 0.5)

func _input(event: InputEvent) -> void:
	# 侧栏区域不处理地图交互
	if event is InputEventMouse:
		var viewport_pos: Vector2 = event.position
		if viewport_pos.x < _main.SIDEBAR_WIDTH:
			return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _preview_tower:
				_place_tower()
			else:
				var clicked: Node2D = _main.find_tower_at(_main.get_global_mouse_position())
				if clicked:
					_select_placed_tower(clicked)
				else:
					_deselect_tower()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if _preview_tower:
				cancel_placement()
			else:
				_remove_tower_at(_main.get_global_mouse_position())

func _place_tower() -> void:
	if not _preview_tower:
		return
	if not _main.can_place_at(_preview_tower.global_position):
		return
	var cost: int = SceneFactory.get_tower_cost(_selected_tower_type)
	GameData.coins -= cost
	_preview_tower.modulate = Color(1, 1, 1, 1)
	_preview_tower.add_to_group(Enums.Group.TOWERS)
	_preview_tower = null
	_selected_tower_type = ""
	_range_indicator.hide_range()
	AudioManager.play("tower_place")
	_main.update_coins_display()

func _remove_tower_at(pos: Vector2) -> void:
	var tower: Node2D = _main.find_tower_at(pos)
	if not tower:
		return
	var cost: int = SceneFactory.get_tower_cost(tower.tower_type)
	GameData.coins += cost
	tower.queue_free()
	_deselect_tower()
	AudioManager.play("tower_remove")
	_main.update_coins_display()

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

func cancel_placement() -> void:
	_cancel_preview()
	_selected_tower_type = ""
	_range_indicator.hide_range()

func has_preview() -> bool:
	return _preview_tower != null

func _cancel_preview() -> void:
	if _preview_tower:
		_preview_tower.queue_free()
		_preview_tower = null

func _update_buttons() -> void:
	for tower_type in _tower_buttons:
		var card: PanelContainer = _tower_buttons[tower_type]
		var cost: int = SceneFactory.get_tower_cost(tower_type)
		var can_afford: bool = GameData.coins >= cost
		card.modulate.a = 1.0 if can_afford else 0.5
```

- [ ] **Step 2: Commit**

```bash
git add scripts/ui/placement_panel.gd
git commit -m "feat: 创建 placement_panel.gd 布置侧栏（塔卡片、点击/拖放、放置/移除）"
```

### Task 7: Create shop_panel.gd

**Files:**
- Create: `scripts/ui/shop_panel.gd`

- [ ] **Step 1: Write shop_panel.gd**

```gdscript
extends Node
## 商店侧栏：物品生成、购买、刷新

const REFRESH_COSTS: Array = [0, 5, 5, 5, 5, 8, 8, 8, 8, 12, 12]

var _main: Node2D = null
var _generator := ShopItemGenerator.new()
var _effect_applier := ShopEffectApplier.new()
var shop_items: Array[ShopItemData] = []
var shop_prices: Array[int] = []
var _item_nodes: Array = []

func initialize(main: Node2D) -> void:
	_main = main
	_generate_shop()
	_create_item_cards()
	_main.coins_changed.connect(_update_display)

func _generate_shop() -> void:
	var wave := GameData.current_wave + 1
	var affinity_tags := _get_affinity_tags()
	var affinity_discount := _get_affinity_discount()
	var locked: Array[bool] = [false, false, false, false]
	var result := _generator.generate_items(wave, affinity_tags, affinity_discount,
		locked, shop_items, shop_prices)
	shop_items = result["items"]
	shop_prices = result["prices"]

func _create_item_cards() -> void:
	var item_list: VBoxContainer = get_parent().get_node("ShopItemList")
	for child in item_list.get_children():
		child.queue_free()
	_item_nodes.clear()

	for i in range(shop_items.size()):
		var card := _create_item_card(i)
		item_list.add_child(card)
		_item_nodes.append(card)

	# 刷新按钮
	var refresh_btn: Button = get_parent().get_node("RefreshButton")
	refresh_btn.pressed.connect(_on_refresh_pressed)
	_update_refresh_button(refresh_btn)

func _create_item_card(index: int) -> PanelContainer:
	var item: ShopItemData = shop_items[index]
	var price: int = shop_prices[index]

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(108, 50)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# 稀有度颜色条
	var rarity_color: Color = UIConstants.get_rarity_color(item.rarity)
	var style := UIConstants.create_panel_stylebox(
		UIConstants.COLOR_BG_PANEL_ALPHA, UIConstants.CORNER_RADIUS_PANEL,
		rarity_color, 2
	)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	card.add_child(vbox)

	var name_label := Label.new()
	name_label.text = item.display_name
	name_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = item.description
	desc_label.add_theme_font_size_override("font_size", 8)
	desc_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_SECONDARY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	var price_label := Label.new()
	price_label.text = "%d 金" % price
	price_label.add_theme_font_size_override("font_size", 9)
	price_label.add_theme_color_override("font_color", Color("#e0c040"))
	vbox.add_child(price_label)

	# 点击购买
	card.gui_input.connect(func(event: InputEvent): _on_item_clicked(event, index))

	return card

func _on_item_clicked(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_buy_item(index)

func _buy_item(index: int) -> void:
	if index >= shop_items.size():
		return
	var item: ShopItemData = shop_items[index]
	var price: int = shop_prices[index]
	if GameData.coins < price:
		return
	if not _generator.can_buy(item):
		return
	GameData.coins -= price
	GameData.purchased_items[item.id] = GameData.purchased_items.get(item.id, 0) + 1
	GameData.record_item_purchased(item.id)
	_effect_applier.apply_effect(item)
	AudioManager.play("shop_buy")
	if _main:
		_main.update_coins_display()

func _on_refresh_pressed() -> void:
	var cost := _get_refresh_cost()
	if GameData.coins < cost:
		return
	GameData.coins -= cost
	_generate_shop()
	_recreate_item_cards()
	if _main:
		_main.update_coins_display()

func _recreate_item_cards() -> void:
	var item_list: VBoxContainer = get_parent().get_node("ShopItemList")
	for child in item_list.get_children():
		child.queue_free()
	_item_nodes.clear()
	for i in range(shop_items.size()):
		var card := _create_item_card(i)
		item_list.add_child(card)
		_item_nodes.append(card)

func _update_display() -> void:
	# 更新卡片可购买状态
	for i in range(min(shop_items.size(), _item_nodes.size())):
		var price: int = shop_prices[i]
		var can_afford: bool = GameData.coins >= price
		var can_buy: bool = _generator.can_buy(shop_items[i])
		_item_nodes[i].modulate.a = 1.0 if (can_afford and can_buy) else 0.5
	var refresh_btn: Button = get_parent().get_node("RefreshButton")
	_update_refresh_button(refresh_btn)

func _update_refresh_button(btn: Button) -> void:
	var cost := _get_refresh_cost()
	btn.text = "刷新 (%d)" % cost
	btn.disabled = GameData.coins < cost

func _get_refresh_cost() -> int:
	var wave := GameData.current_wave + 1
	if wave >= REFRESH_COSTS.size():
		return REFRESH_COSTS[-1]
	return REFRESH_COSTS[wave]

func _get_affinity_tags() -> PackedStringArray:
	var char_id := GameData.current_character
	if not GameConfig.characters.has(char_id):
		return PackedStringArray()
	return GameConfig.characters[char_id].affinity_tags

func _get_affinity_discount() -> float:
	var char_id := GameData.current_character
	if not GameConfig.characters.has(char_id):
		return 0.0
	return GameConfig.characters[char_id].affinity_discount
```

- [ ] **Step 2: Commit**

```bash
git add scripts/ui/shop_panel.gd
git commit -m "feat: 创建 shop_panel.gd 商店侧栏（物品生成、购买、刷新）"
```

---

## Chunk 3: Tests

### Task 8: Update existing placement tests

**Files:**
- Modify: `tests/unit/test_placement_grid_rules.gd`

- [ ] **Step 1: Update tests for new placement.gd API**

The key API changes are:
- `_get_grid_position()` → `get_grid_position()` (now public)
- `_can_place_at()` → `can_place_at()` (now public)
- `_find_tower_at()` → `find_tower_at()` (now public)
- `_select_placed_tower()` is now on `_placement_panel`
- `_deselect_tower()` is now on `_placement_panel`
- `_remove_tower_at()` is now on `_placement_panel`
- `_range_indicator` is now public
- `_selected_placed_tower` is now on `_placement_panel`

Update the test file:

```gdscript
extends GutTest

var placement: Node2D
var _original_selected_map: String
var _original_coins: int

func before_each():
	_original_selected_map = GameData.selected_map
	_original_coins = GameData.coins

	GameData.tower_inventory.clear()
	GameData.purchased_towers.clear()
	GameData.coins = 100

	var placement_scene = load("res://scenes/levels/placement.tscn")
	placement = placement_scene.instantiate()
	add_child_autofree(placement)

func after_each():
	GameData.selected_map = _original_selected_map
	GameData.coins = _original_coins

func test_get_grid_position_uses_game_config_grid_size():
	var gs = float(GameConfig.GRID_SIZE)
	assert_eq(placement.get_grid_position(Vector2(0, 0)), Vector2(gs / 2.0, gs / 2.0))
	assert_eq(
		placement.get_grid_position(Vector2(44, 44)),
		Vector2(floor(44.0 / gs) * gs + gs / 2.0, floor(44.0 / gs) * gs + gs / 2.0)
	)

func test_can_place_at_rejects_position_outside_map_extents():
	var outside_x = Vector2(GameConfig.MAP_HALF_WIDTH + GameConfig.GRID_SIZE, 0)
	var outside_y = Vector2(0, GameConfig.MAP_HALF_HEIGHT + GameConfig.GRID_SIZE)
	assert_false(placement.can_place_at(outside_x))
	assert_false(placement.can_place_at(outside_y))

func test_can_place_at_allows_position_on_map_boundary():
	var boundary_position = Vector2(GameConfig.MAP_HALF_WIDTH - 1.0, 0)
	assert_true(placement.can_place_at(boundary_position))

func test_find_tower_at_returns_closest_tower():
	var tower = SceneFactory.create_tower(Enums.TowerId.SHOOTER)
	tower.global_position = Vector2(105, 105)
	tower.add_to_group(Enums.Group.TOWERS)
	placement.add_child(tower)
	var found = placement.find_tower_at(Vector2(110, 110))
	assert_eq(found, tower, "应找到最近的塔")

func test_find_tower_at_returns_null_when_too_far():
	var tower = SceneFactory.create_tower(Enums.TowerId.SHOOTER)
	tower.global_position = Vector2(105, 105)
	tower.add_to_group(Enums.Group.TOWERS)
	placement.add_child(tower)
	var found = placement.find_tower_at(Vector2(300, 300))
	assert_null(found, "距离太远应返回 null")

func test_first_wave_hides_shop_tab():
	GameData.current_wave = 0
	# 重新实例化
	var p = load("res://scenes/levels/placement.tscn").instantiate()
	add_child_autofree(p)
	var shop_tab: Button = p.get_node("UI/SidePanel/TabBar/ShopTab")
	assert_false(shop_tab.visible, "首波应隐藏商店 Tab")

func test_non_first_wave_shows_shop_tab():
	GameData.current_wave = 1
	var p = load("res://scenes/levels/placement.tscn").instantiate()
	add_child_autofree(p)
	var shop_tab: Button = p.get_node("UI/SidePanel/TabBar/ShopTab")
	assert_true(shop_tab.visible, "非首波应显示商店 Tab")
```

- [ ] **Step 2: Run tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_placement_grid_rules.gd`
Expected: All pass

- [ ] **Step 3: Commit**

```bash
git add tests/unit/test_placement_grid_rules.gd
git commit -m "test: 更新 placement 测试适配新公开 API 和 Tab 切换"
```

### Task 9: Create placement_panel tests

**Files:**
- Create: `tests/unit/test_placement_panel.gd`

- [ ] **Step 1: Write placement_panel tests**

```gdscript
extends GutTest

var placement: Node2D
var _original_coins: int
var _original_map: String

func before_each():
	_original_coins = GameData.coins
	_original_map = GameData.selected_map
	GameData.tower_inventory.clear()
	GameData.purchased_towers.clear()
	GameData.coins = 200

	var placement_scene = load("res://scenes/levels/placement.tscn")
	placement = placement_scene.instantiate()
	add_child_autofree(placement)

func after_each():
	GameData.coins = _original_coins
	GameData.selected_map = _original_map

func test_place_tower_deducts_coins():
	var cost: int = SceneFactory.get_tower_cost(Enums.TowerId.SHOOTER)
	var initial_coins: int = GameData.coins
	# 通过 placement_panel 选中塔
	placement._placement_panel._select_tower(Enums.TowerId.SHOOTER)
	assert_not_null(placement._placement_panel._preview_tower, "应有预览塔")
	# 移动预览到合法位置
	placement._placement_panel._preview_tower.global_position = Vector2(100, 100)
	placement._placement_panel._place_tower()
	assert_eq(GameData.coins, initial_coins - cost, "放置应扣除金币")

func test_remove_tower_refunds_coins():
	GameData.coins = 60
	var tower = SceneFactory.create_tower(Enums.TowerId.SHOOTER)
	tower.global_position = Vector2(105, 105)
	tower.add_to_group(Enums.Group.TOWERS)
	placement.add_child(tower)
	var cost: int = SceneFactory.get_tower_cost(Enums.TowerId.SHOOTER)
	placement._placement_panel._remove_tower_at(Vector2(110, 110))
	assert_eq(GameData.coins, 60 + cost, "移除应退还金币")

func test_cannot_select_tower_when_coins_insufficient():
	GameData.coins = 0
	placement._placement_panel._select_tower(Enums.TowerId.SHOOTER)
	assert_null(placement._placement_panel._preview_tower, "金币不足不应创建预览")

func test_cancel_placement_clears_preview():
	placement._placement_panel._select_tower(Enums.TowerId.SHOOTER)
	assert_true(placement._placement_panel.has_preview())
	placement._placement_panel.cancel_placement()
	assert_false(placement._placement_panel.has_preview())

func test_has_preview_returns_correct_state():
	assert_false(placement._placement_panel.has_preview())
	placement._placement_panel._select_tower(Enums.TowerId.SHOOTER)
	assert_true(placement._placement_panel.has_preview())
```

- [ ] **Step 2: Run tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_placement_panel.gd`
Expected: All pass

- [ ] **Step 3: Commit**

```bash
git add tests/unit/test_placement_panel.gd
git commit -m "test: 添加 placement_panel 单元测试（放置、移除、金币、预览）"
```

### Task 10: Create shop_panel tests

**Files:**
- Create: `tests/unit/test_shop_panel.gd`

- [ ] **Step 1: Write shop_panel tests**

```gdscript
extends GutTest

var _original_coins: int
var _original_wave: int
var _original_character: String
var _original_purchased: Dictionary

func before_each():
	_original_coins = GameData.coins
	_original_wave = GameData.current_wave
	_original_character = GameData.current_character
	_original_purchased = GameData.purchased_items.duplicate()
	GameData.coins = 200
	GameData.current_wave = 1
	GameData.purchased_items = {}

func after_each():
	GameData.coins = _original_coins
	GameData.current_wave = _original_wave
	GameData.current_character = _original_character
	GameData.purchased_items = _original_purchased

func test_shop_panel_generates_items():
	var panel = preload("res://scripts/ui/shop_panel.gd").new()
	# 手动调用生成（跳过 initialize 因为需要场景树）
	panel._generate_shop()
	assert_eq(panel.shop_items.size(), 4, "应生成 4 件物品")
	assert_eq(panel.shop_prices.size(), 4, "应生成 4 个价格")

func test_shop_panel_buy_deducts_coins():
	var panel = preload("res://scripts/ui/shop_panel.gd").new()
	panel._generate_shop()
	var initial_coins: int = GameData.coins
	var price: int = panel.shop_prices[0]
	# 直接调用 _buy_item（_main 为 null 时跳过 UI 更新）
	panel._buy_item(0)
	assert_eq(GameData.coins, initial_coins - price, "购买应扣除金币")

func test_shop_panel_refresh_cost():
	var panel = preload("res://scripts/ui/shop_panel.gd").new()
	GameData.current_wave = 1
	assert_eq(panel._get_refresh_cost(), 5)
	GameData.current_wave = 9
	assert_eq(panel._get_refresh_cost(), 12)
	GameData.current_wave = 20
	assert_eq(panel._get_refresh_cost(), 12, "超出范围应返回最后一个值")
```

- [ ] **Step 2: Run tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_shop_panel.gd`
Expected: All pass

- [ ] **Step 3: Commit**

```bash
git add tests/unit/test_shop_panel.gd
git commit -m "test: 添加 shop_panel 单元测试（物品生成、购买、刷新费用）"
```

### Task 11: Run full test suite and fix any regressions

- [ ] **Step 1: Run all tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: All tests pass (including existing 276+ tests)

- [ ] **Step 2: Fix any failures**

If tests fail, investigate and fix. Common issues:
- Tests that reference `Enums.Scene.SHOP` will fail since it's been removed from `SceneManager.SCENES` — update those tests
- Tests that instantiate `shop.tscn` directly — these should still work since the file exists
- Tests referencing `placement._get_grid_position()` (private) need update to `placement.get_grid_position()` (public)

- [ ] **Step 3: Commit fixes if any**

```bash
git add -A
git commit -m "fix: 修复全量测试回归"
```

---

## Chunk 4: Integration & Polish

### Task 12: Manual integration test via Godot editor

- [ ] **Step 1: Run game and verify flow**

Run the game through Godot editor or MCP `play_scene`. Verify:
1. Start menu → character selection → map select → **placement** (not main)
2. Placement shows left sidebar with tower cards, right side shows map grid
3. First wave: shop tab hidden
4. Click tower card → preview follows mouse on grid → left click places → coins deducted
5. Right click placed tower → removed → coins refunded
6. Click "开始战斗" → main battle starts with towers present
7. Complete wave → returns to placement with shop tab visible
8. Shop tab: items shown, can buy, can refresh
9. Tab switching works, coins shared
10. ESC with no preview → pause menu

- [ ] **Step 2: Fix any issues found during manual testing**

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "feat: 塔放置系统完整集成（布置+商店合并界面）"
```
