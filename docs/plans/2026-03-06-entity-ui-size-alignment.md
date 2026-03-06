# 实体与 UI 尺寸对齐（基于 640x360 / 30 网格）Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将游戏内实体与 UI 尺寸统一到新标准（640x360 视口、30x30 网格、1200x900 地图），消除旧尺寸（32/48/超大 UI 面板）导致的比例与布局不一致问题。

**Architecture:** 采用“测试锁定目标尺寸 → 最小改动更新场景文件 → 回归验证”的方案。实体尺寸以网格单位对齐（1 格=30px），UI 尺寸以 640x360 逻辑分辨率为基准重排，优先修改 `.tscn` 的静态尺寸，避免引入额外运行时复杂逻辑。

**Tech Stack:** Godot 4.6, GDScript, GUT

---

## 实施原则（执行时必须遵守）

- 使用 @superpowers:test-driven-development：每个任务先写失败测试，再做最小实现。
- 使用 @superpowers:verification-before-completion：每个任务结束必须运行验证命令并核对输出。
- 使用 @superpowers:using-git-worktrees：在独立 worktree 执行，避免污染当前开发现场。
- DRY/YAGNI：只处理“实体尺寸 + UI 尺寸对齐”，不做玩法平衡重构。

---

## 目标尺寸基线（本计划锁定）

### 实体尺寸（像素）

- 玩家：30x30
- 普通敌人：30x30
- 快速敌人：30x30
- 坦克敌人：45x45
- 射手塔：30x30
- 墙塔：30x30
- 减速塔：30x30
- 子弹：6x6
- 金币：碰撞半径 6（视觉 12x12）

### UI 尺寸（像素，基于 640x360）

- 通用主按钮：160x36
- 次级按钮：120x32
- 地图卡按钮：240x140
- 卡片间距：20
- 结果页中心容器：320x220
- 商店中心容器：560x300

---

### Task 1: 锁定实体尺寸规则（先测试）

**Files:**
- Create: `tests/unit/test_entity_scene_dimensions.gd`
- Modify: `tests/unit/test_game_config_dimensions.gd`

**Step 1: Write the failing test**

在 `tests/unit/test_entity_scene_dimensions.gd` 新建以下测试（当前会失败，因为场景还是 32/48/8）：

```gdscript
extends GutTest

func test_player_size_matches_30_grid():
	var scene = load("res://scenes/player.tscn").instantiate()
	add_child_autofree(scene)
	var shape: RectangleShape2D = scene.get_node("CollisionShape2D").shape
	assert_eq(shape.size, Vector2(30, 30))

func test_enemy_sizes_match_new_standard():
	var normal = load("res://scenes/enemies/enemy_normal.tscn").instantiate()
	add_child_autofree(normal)
	assert_eq(normal.get_node("CollisionShape2D").shape.size, Vector2(30, 30))

	var fast = load("res://scenes/enemies/enemy_fast.tscn").instantiate()
	add_child_autofree(fast)
	assert_eq(fast.get_node("CollisionShape2D").shape.size, Vector2(30, 30))

	var tank = load("res://scenes/enemies/enemy_tank.tscn").instantiate()
	add_child_autofree(tank)
	assert_eq(tank.get_node("CollisionShape2D").shape.size, Vector2(45, 45))

func test_tower_sizes_match_new_standard():
	var shooter = load("res://scenes/towers/tower_shooter.tscn").instantiate()
	add_child_autofree(shooter)
	assert_eq(shooter.get_node("CollisionShape2D").shape.size, Vector2(30, 30))

	var wall = load("res://scenes/towers/tower_wall.tscn").instantiate()
	add_child_autofree(wall)
	assert_eq(wall.get_node("CollisionShape2D").shape.size, Vector2(30, 30))

	var slow = load("res://scenes/towers/tower_slow.tscn").instantiate()
	add_child_autofree(slow)
	assert_eq(slow.get_node("CollisionShape2D").shape.size, Vector2(30, 30))

func test_bullet_and_coin_sizes_match_new_standard():
	var bullet = load("res://scenes/bullet.tscn").instantiate()
	add_child_autofree(bullet)
	assert_eq(bullet.get_node("CollisionShape2D").shape.size, Vector2(6, 6))

	var coin = load("res://scenes/coin.tscn").instantiate()
	add_child_autofree(coin)
	assert_eq(coin.get_node("CollisionShape2D").shape.radius, 6.0)
```

并在 `tests/unit/test_game_config_dimensions.gd` 增加实体尺寸常量稳定性断言：

```gdscript
func test_entity_dimension_constants_are_stable():
	assert_eq(GameConfig.ENTITY_SIZE_STANDARD, 30)
	assert_eq(GameConfig.ENTITY_SIZE_TANK, 45)
	assert_eq(GameConfig.BULLET_SIZE, 6)
	assert_eq(GameConfig.COIN_RADIUS, 6)
```

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: FAIL，提示实体尺寸与期望不一致，且 `GameConfig` 尚无新常量。

**Step 3: Write minimal implementation**

先在 `game_config.gd` 增加实体尺寸常量：

```gdscript
# 实体尺寸标准（像素）
const ENTITY_SIZE_STANDARD = GRID_SIZE      # 30
const ENTITY_SIZE_TANK = int(GRID_SIZE * 1.5)  # 45
const BULLET_SIZE = int(GRID_SIZE * 0.2)    # 6
const COIN_RADIUS = int(GRID_SIZE * 0.2)    # 6
```

> 放置位置：`GRID_SIZE` 与地图尺寸常量定义之后。

**Step 4: Run test to verify it still fails (red remains for scenes)**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: 仅常量相关断言通过；实体场景尺寸断言继续 FAIL（符合 TDD 预期）。

**Step 5: Commit**

```bash
git add game_config.gd tests/unit/test_game_config_dimensions.gd tests/unit/test_entity_scene_dimensions.gd
git commit -m "test: 锁定实体尺寸对齐目标"
```

---

### Task 2: 对齐所有战斗实体场景尺寸到新标准

**Files:**
- Modify: `scenes/player.tscn`
- Modify: `scenes/enemies/enemy_normal.tscn`
- Modify: `scenes/enemies/enemy_fast.tscn`
- Modify: `scenes/enemies/enemy_tank.tscn`
- Modify: `scenes/towers/tower_shooter.tscn`
- Modify: `scenes/towers/tower_wall.tscn`
- Modify: `scenes/towers/tower_slow.tscn`
- Modify: `scenes/bullet.tscn`
- Modify: `scenes/coin.tscn`
- Test: `tests/unit/test_entity_scene_dimensions.gd`

**Step 1: Write the failing test (already done in Task 1, reuse failing case)**

保持 Task 1 的失败测试不变，不新增测试。

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: FAIL，失败点集中在实体场景尺寸。

**Step 3: Write minimal implementation**

按以下规则更新各 `.tscn`：

- 所有 `size = Vector2(32, 32)` 改为 `Vector2(30, 30)`
- 坦克 `size = Vector2(48, 48)` 改为 `Vector2(45, 45)`
- 墙塔 `size = Vector2(48, 48)` 改为 `Vector2(30, 30)`
- 子弹 `size = Vector2(8, 8)` 改为 `Vector2(6, 6)`
- 金币 `radius = 8.0` 改为 `6.0`

并同步 visual 偏移（核心示例）：

```text
30x30: left/top = -15, right/bottom = 15
45x45: left/top = -22.5, right/bottom = 22.5
6x6: left/top = -3, right/bottom = 3
coin 12x12: left/top = -6, right/bottom = 6
```

**Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: `test_entity_scene_dimensions.gd` PASS，无新增尺寸相关失败。

**Step 5: Commit**

```bash
git add scenes/player.tscn scenes/enemies/enemy_normal.tscn scenes/enemies/enemy_fast.tscn scenes/enemies/enemy_tank.tscn scenes/towers/tower_shooter.tscn scenes/towers/tower_wall.tscn scenes/towers/tower_slow.tscn scenes/bullet.tscn scenes/coin.tscn
git commit -m "feat: 对齐战斗实体尺寸到30网格标准"
```

---

### Task 3: 锁定 UI 尺寸目标（先测试）

**Files:**
- Create: `tests/unit/test_ui_scene_dimensions.gd`

**Step 1: Write the failing test**

新建 `tests/unit/test_ui_scene_dimensions.gd`：

```gdscript
extends GutTest

func _control_size(node: Control) -> Vector2:
	return Vector2(node.offset_right - node.offset_left, node.offset_bottom - node.offset_top)

func test_map_select_cards_fit_640x360():
	var scene = load("res://scenes/ui/map_select.tscn").instantiate()
	add_child_autofree(scene)
	var forest_btn: Button = scene.get_node("VBoxContainer/MapCardsContainer/ForestCard/ForestButton")
	var desert_btn: Button = scene.get_node("VBoxContainer/MapCardsContainer/DesertCard/DesertButton")
	assert_eq(forest_btn.custom_minimum_size, Vector2(240, 140))
	assert_eq(desert_btn.custom_minimum_size, Vector2(240, 140))

func test_result_panel_and_buttons_fit_640x360():
	var scene = load("res://scenes/ui/result.tscn").instantiate()
	add_child_autofree(scene)
	var panel: Control = scene.get_node("VBoxContainer")
	assert_eq(_control_size(panel), Vector2(320, 220))
	assert_eq(scene.get_node("VBoxContainer/RestartButton").custom_minimum_size, Vector2(160, 36))
	assert_eq(scene.get_node("VBoxContainer/QuitButton").custom_minimum_size, Vector2(160, 36))

func test_shop_main_panel_fits_640x360():
	var scene = load("res://scenes/ui/shop.tscn").instantiate()
	add_child_autofree(scene)
	var panel: Control = scene.get_node("VBoxContainer")
	assert_eq(_control_size(panel), Vector2(560, 300))

func test_start_menu_button_uses_standard_size():
	var scene = load("res://scenes/ui/start_menu.tscn").instantiate()
	add_child_autofree(scene)
	var start_btn: Button = scene.get_node("VBoxContainer/StartButton")
	assert_eq(start_btn.custom_minimum_size, Vector2(160, 36))
```

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: FAIL，`map_select/shop/result/start_menu` 仍是旧尺寸。

**Step 3: Write minimal implementation scaffold**

在 `game_config.gd` 增加 UI 尺寸常量（用于文档化和后续脚本引用）：

```gdscript
# UI 尺寸标准（640x360 逻辑分辨率）
const UI_BUTTON_SIZE = Vector2(160, 36)
const UI_BUTTON_SMALL_SIZE = Vector2(120, 32)
const UI_MAP_CARD_SIZE = Vector2(240, 140)
const UI_RESULT_PANEL_SIZE = Vector2(320, 220)
const UI_SHOP_PANEL_SIZE = Vector2(560, 300)
const UI_CARD_GAP = 20
```

**Step 4: Run test to verify it still fails (red remains for scenes)**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: UI 常量引入成功，但场景尺寸测试仍 FAIL。

**Step 5: Commit**

```bash
git add game_config.gd tests/unit/test_ui_scene_dimensions.gd
git commit -m "test: 锁定UI尺寸对齐目标"
```

---

### Task 4: 更新 UI 场景尺寸与布局（最小改动）

**Files:**
- Modify: `scenes/ui/start_menu.tscn`
- Modify: `scenes/ui/weapon_select.tscn`
- Modify: `scenes/character_selection.tscn`
- Modify: `scenes/ui/map_select.tscn`
- Modify: `scenes/ui/shop.tscn`
- Modify: `scenes/ui/result.tscn`
- Modify: `scenes/placement.tscn`
- Test: `tests/unit/test_ui_scene_dimensions.gd`

**Step 1: Write the failing test (reuse Task 3 tests)**

不新增测试，复用已失败用例。

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: FAIL。

**Step 3: Write minimal implementation**

按以下目标更新 `.tscn`：

1) `scenes/ui/start_menu.tscn`
- `TitleLabel.theme_override_font_sizes/font_size`: 48 -> 32
- `StartButton.custom_minimum_size`: `Vector2(160, 36)`
- `VBoxContainer` 改为约 `320x140`（offset `-160,-70` 到 `160,70`）

2) `scenes/ui/weapon_select.tscn`
- 两个武器按钮改为 `Vector2(160, 36)`
- `VBoxContainer` 高度按按钮数量微调（避免挤压）

3) `scenes/character_selection.tscn`
- `CharacterContainer` 宽度从 600 缩到 480（offset `-240` 到 `240`）
- 三个角色按钮设置 `custom_minimum_size = Vector2(140, 36)`

4) `scenes/ui/map_select.tscn`
- 根容器 `VBoxContainer` 改为 `560x300`（offset `-280,-150` 到 `280,150`）
- `ForestButton/DesertButton`: `Vector2(240, 140)`
- `CardSpacer`: `Vector2(20, 0)`
- 标题字号 32 -> 28，子标题 24 -> 18

5) `scenes/ui/shop.tscn`
- 根容器 `VBoxContainer` 改为 `560x300`（offset `-280,-150` 到 `280,150`）
- `NameLabel` 宽度 200 -> 180
- `PriceLabel` 宽度 100 -> 80
- 各 `BuyButton` 宽度 100 -> 80
- `RefreshButton/ConfirmButton` 改为 `Vector2(120, 32)`

6) `scenes/ui/result.tscn`
- 根容器 `VBoxContainer` 改为 `320x220`（offset `-160,-110` 到 `160,110`）
- `RestartButton/QuitButton`: `Vector2(160, 36)`

7) `scenes/placement.tscn`
- `ShooterButton/WallButton/SlowButton`: `Vector2(120, 32)`
- `StartBattleButton`: `Vector2(160, 36)`
- 把 `StartBattleButton` 偏移调整到 640x360 可见区域（建议右下角，约 x=460, y=300）

**Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: `test_ui_scene_dimensions.gd` PASS，全量测试无回归。

**Step 5: Commit**

```bash
git add scenes/ui/start_menu.tscn scenes/ui/weapon_select.tscn scenes/character_selection.tscn scenes/ui/map_select.tscn scenes/ui/shop.tscn scenes/ui/result.tscn scenes/placement.tscn
git commit -m "feat: 对齐UI布局尺寸到640x360标准"
```

---

### Task 5: 运行时验证与文档补充

**Files:**
- Modify: `docs/design/dev-workflow.md`
- Optional Modify (if needed): `tests/unit/test_game_config_dimensions.gd`

**Step 1: Write the failing test/checklist gate**

在 `test_game_config_dimensions.gd` 增加一致性断言：

```gdscript
func test_entity_and_ui_size_tokens_are_grid_aligned():
	assert_eq(GameConfig.ENTITY_SIZE_STANDARD, GameConfig.GRID_SIZE)
	assert_eq(GameConfig.BULLET_SIZE, int(GameConfig.GRID_SIZE * 0.2))
	assert_eq(GameConfig.UI_BUTTON_SIZE, Vector2(160, 36))
```

**Step 2: Run test to verify it fails (if token missing or不一致)**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: 若 token 或值不一致则 FAIL。

**Step 3: Write minimal implementation**

在 `docs/design/dev-workflow.md` 的“尺寸标准”后新增小节：

```markdown
### 实体与 UI 尺寸基线（2026-03）
- 1 网格实体：30x30（玩家、普通敌人、塔）
- 大体型敌人：45x45（坦克）
- 子弹：6x6，金币碰撞半径：6
- 主按钮：160x36，次级按钮：120x32
- 地图卡：240x140，商店/主面板：560x300
```

**Step 4: Run verification commands**

Run:
- `godot --headless -s addons/gut/gut_cmdln.gd`
- 使用 gdai-mcp `run_project` 启动并检查关键场景（开始菜单、地图选择、商店、布置、战斗）
- 使用 gdai-mcp `get_debug_output` 检查运行报错

Expected:
- GUT 全 PASS
- UI 在 640x360 逻辑视口内无明显超出
- 布置界面开始战斗按钮可见
- 实体大小与碰撞体视觉一致

**Step 5: Commit**

```bash
git add docs/design/dev-workflow.md tests/unit/test_game_config_dimensions.gd
git commit -m "docs: 补充实体与UI尺寸基线定义"
```

---

## 风险与处理

- 风险 1：墙塔从 48 改到 30 后视觉辨识度下降。
  - 处理：本计划只做尺寸对齐；若需增强区分度，后续单开视觉任务（颜色/描边），不改碰撞尺寸。

- 风险 2：地图选择与商店在低分辨率下文本拥挤。
  - 处理：优先减字号与按钮宽度，不引入复杂响应式脚本。

- 风险 3：`placement.tscn` 的按钮定位仍可能偏离。
  - 处理：以运行时验证为准，必要时仅微调 offset，不改交互逻辑。

---

## 完成定义（Definition of Done）

- [ ] 所有战斗实体尺寸已对齐到新标准（30/45/6/6）
- [ ] `tests/unit/test_entity_scene_dimensions.gd` 通过
- [ ] `tests/unit/test_ui_scene_dimensions.gd` 通过
- [ ] 关键 UI 场景在 640x360 逻辑视口内可用
- [ ] `docs/design/dev-workflow.md` 补充实体/UI 尺寸基线
- [ ] 全量 GUT 测试通过，运行无新增错误
