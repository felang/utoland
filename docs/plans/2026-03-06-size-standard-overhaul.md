# 尺寸标准重定义（640x360 / 30 PPU / 40x30网格）Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将项目统一迁移到新尺寸标准：基准分辨率 640x360、PPU=30、地图网格 30x30、地图总尺寸 40 列 x 30 行。

**Architecture:** 采用“配置中心驱动 + 场景运行时对齐”方案：先在 `GameConfig` 中定义统一尺寸常量，再让 `placement`、`enemy_spawner`、`map_boundary` 从配置读取边界与网格，移除核心流程中的尺寸硬编码。最后通过 GUT 回归测试验证网格吸附、边界和地图尺寸规则。

**Tech Stack:** Godot 4.6, GDScript, GUT

---

## 实施原则（执行时必须遵守）

- 使用 @superpowers:test-driven-development：每个行为先写失败测试，再做最小实现。
- 使用 @superpowers:verification-before-completion：每个任务结束前执行对应验证命令并核对输出。
- 避免一次性大改：按任务小步提交，保持可回滚。
- DRY/YAGNI：仅改尺寸标准相关代码，不做额外功能扩展。

---

### Task 1: 建立全局尺寸常量（单一事实来源）

**Files:**
- Modify: `game_config.gd:165-182`（MAPS 区域附近）
- Test (Create): `tests/unit/test_game_config_dimensions.gd`

**Step 1: Write the failing test**

在 `tests/unit/test_game_config_dimensions.gd` 新建测试，先断言新常量存在且值正确（当前会失败，因为常量未定义）：

```gdscript
extends GutTest

func test_world_size_constants_are_defined():
	assert_eq(GameConfig.BASE_VIEWPORT_WIDTH, 640)
	assert_eq(GameConfig.BASE_VIEWPORT_HEIGHT, 360)
	assert_eq(GameConfig.PPU, 30)
	assert_eq(GameConfig.GRID_SIZE, 30)
	assert_eq(GameConfig.MAP_COLS, 40)
	assert_eq(GameConfig.MAP_ROWS, 30)
	assert_eq(GameConfig.MAP_PIXEL_WIDTH, 1200)
	assert_eq(GameConfig.MAP_PIXEL_HEIGHT, 900)

func test_map_half_extents_are_correct():
	assert_eq(GameConfig.MAP_HALF_WIDTH, 600)
	assert_eq(GameConfig.MAP_HALF_HEIGHT, 450)
```

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: FAIL，提示 `GameConfig` 缺少上述常量。

**Step 3: Write minimal implementation**

在 `game_config.gd` 增加尺寸常量（建议放在文件顶部，紧跟 DEBUG 常量后）：

```gdscript
# 全局尺寸标准
const BASE_VIEWPORT_WIDTH = 640
const BASE_VIEWPORT_HEIGHT = 360
const PPU = 30
const GRID_SIZE = 30

const MAP_COLS = 40
const MAP_ROWS = 30
const MAP_PIXEL_WIDTH = MAP_COLS * GRID_SIZE   # 1200
const MAP_PIXEL_HEIGHT = MAP_ROWS * GRID_SIZE  # 900
const MAP_HALF_WIDTH = MAP_PIXEL_WIDTH / 2     # 600
const MAP_HALF_HEIGHT = MAP_PIXEL_HEIGHT / 2   # 450
```

**Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: PASS，`test_game_config_dimensions.gd` 通过。

**Step 5: Commit**

```bash
git add game_config.gd tests/unit/test_game_config_dimensions.gd
git commit -m "feat: 增加全局尺寸与地图网格常量"
```

---

### Task 2: 切换项目基准分辨率到 640x360

**Files:**
- Modify: `project.godot:27-31`
- Test (Modify): `tests/unit/test_game_config_dimensions.gd`

**Step 1: Write the failing test**

在 `test_game_config_dimensions.gd` 增加视口与配置一致性断言（先失败）：

```gdscript
func test_viewport_matches_new_standard():
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 640)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 360)
```

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: FAIL，当前 `project.godot` 仍是 1920x1080。

**Step 3: Write minimal implementation**

修改 `project.godot`：

```ini
window/size/viewport_width=640
window/size/viewport_height=360
window/size/mode=2
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

> 仅替换宽高；其余拉伸策略保持现有行为，避免引入额外 UI 风险。

**Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: PASS，视口测试通过。

**Step 5: Commit**

```bash
git add project.godot tests/unit/test_game_config_dimensions.gd
git commit -m "feat: 切换项目基准分辨率为640x360"
```

---

### Task 3: 网格吸附与布置边界改为配置驱动（30x30 + 40x30）

**Files:**
- Modify: `scripts/ui/placement.gd:3, 75-97`
- Test (Create): `tests/unit/test_placement_grid_rules.gd`

**Step 1: Write the failing test**

新建 `tests/unit/test_placement_grid_rules.gd`，先写对 30 网格与地图边界的断言：

```gdscript
extends GutTest

func test_grid_snap_uses_30_cell_size():
	var placement = preload("res://scripts/ui/placement.gd").new()
	assert_eq(placement.get_grid_position(Vector2(0, 0)), Vector2(15, 15))
	assert_eq(placement.get_grid_position(Vector2(44, 44)), Vector2(45, 45))

func test_can_place_rejects_outside_map_half_extents():
	var placement = preload("res://scripts/ui/placement.gd").new()
	# 需要把实例挂到树上并补齐最小依赖后再调用 can_place_at
	# 断言 x > 600 或 y > 450 时返回 false
	pass_test("实现后替换为真实断言")
```

> 注意：第二个测试先以最小可运行结构搭建场景树，确保 `placement.$Player` 可访问。

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: FAIL，当前网格是 32 且边界是 1300/1000。

**Step 3: Write minimal implementation**

把 `placement.gd` 的尺寸硬编码改为读取 `GameConfig`：

```gdscript
const GRID_SIZE = GameConfig.GRID_SIZE

func can_place_at(pos: Vector2) -> bool:
	if abs(pos.x) > GameConfig.MAP_HALF_WIDTH or abs(pos.y) > GameConfig.MAP_HALF_HEIGHT:
		return false
	...

func get_grid_position(pos: Vector2) -> Vector2:
	return Vector2(
		floor(pos.x / GRID_SIZE) * GRID_SIZE + GRID_SIZE / 2,
		floor(pos.y / GRID_SIZE) * GRID_SIZE + GRID_SIZE / 2
	)
```

**Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: PASS，网格与边界规则测试通过。

**Step 5: Commit**

```bash
git add scripts/ui/placement.gd tests/unit/test_placement_grid_rules.gd
git commit -m "refactor: 布置场景网格和边界改为配置驱动"
```

---

### Task 4: 敌人生成边界改为地图常量（移除 -1250/-950 等魔法数）

**Files:**
- Modify: `scripts/systems/enemy_spawner.gd:7-12`
- Test (Create): `tests/unit/test_enemy_spawner_bounds.gd`

**Step 1: Write the failing test**

新建 `tests/unit/test_enemy_spawner_bounds.gd`：

```gdscript
extends GutTest

func test_spawner_bounds_follow_game_config():
	var spawner = preload("res://scripts/systems/enemy_spawner.gd").new()
	assert_eq(spawner.map_min_x, -GameConfig.MAP_HALF_WIDTH)
	assert_eq(spawner.map_max_x, GameConfig.MAP_HALF_WIDTH)
	assert_eq(spawner.map_min_y, -GameConfig.MAP_HALF_HEIGHT)
	assert_eq(spawner.map_max_y, GameConfig.MAP_HALF_HEIGHT)
```

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: FAIL，当前仍是 -1250~1250 / -950~950。

**Step 3: Write minimal implementation**

修改 `enemy_spawner.gd` 顶部边界变量：

```gdscript
var map_min_x = -GameConfig.MAP_HALF_WIDTH
var map_max_x = GameConfig.MAP_HALF_WIDTH
var map_min_y = -GameConfig.MAP_HALF_HEIGHT
var map_max_y = GameConfig.MAP_HALF_HEIGHT
```

`min_distance_from_player` 暂不重平衡，仅保留现有值，避免超出“尺寸标准迁移”范围。

**Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: PASS，敌人生成边界测试通过。

**Step 5: Commit**

```bash
git add scripts/systems/enemy_spawner.gd tests/unit/test_enemy_spawner_bounds.gd
git commit -m "refactor: 敌人生成边界改为读取地图尺寸配置"
```

---

### Task 5: 重设地图边界场景到 1200x900 地图

**Files:**
- Modify: `scenes/map_boundary.tscn:3-75`
- Modify: `scenes/main.tscn:13-15`（玩家出生点）
- Modify: `scenes/placement.tscn:14-20, 23`（背景锚点与玩家出生点）
- Test (Modify): `tests/integration/test_enemy_spawning.gd`

**Step 1: Write the failing test**

在 `tests/integration/test_enemy_spawning.gd` 增加新边界断言：

```gdscript
func test_spawn_position_is_inside_new_map_bounds():
	var spawner = preload("res://scripts/systems/enemy_spawner.gd").new()
	for i in range(20):
		var pos = spawner.get_random_spawn_position()
		assert_lte(abs(pos.x), GameConfig.MAP_HALF_WIDTH)
		assert_lte(abs(pos.y), GameConfig.MAP_HALF_HEIGHT)
```

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: FAIL（在修改前，边界与场景墙体定义不一致，测试或运行行为不稳定）。

**Step 3: Write minimal implementation**

将 `map_boundary.tscn` 的墙体几何改成基于 1200x900（中心原点）：

- 横墙长度约 `MAP_PIXEL_WIDTH + 2*WALL_THICKNESS`
- 竖墙高度约 `MAP_PIXEL_HEIGHT + 2*WALL_THICKNESS`
- 位置改为接近 `±(MAP_HALF_WIDTH + WALL_THICKNESS/2)`、`±(MAP_HALF_HEIGHT + WALL_THICKNESS/2)`

建议本次固定使用：

```text
WALL_THICKNESS = 30
Top/Bottom wall shape width = 1260, height = 30
Left/Right wall shape width = 30, height = 960
Top y = -465, Bottom y = 465
Left x = -615, Right x = 615
```

同时将玩家初始位置统一到地图中心，避免超边界：

- `scenes/main.tscn` Player `position = Vector2(0, 0)`
- `scenes/placement.tscn` Player `position = Vector2(0, 0)`
- `scenes/placement.tscn` BackgroundSprite `position = Vector2(0, 0)`

**Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: PASS，敌人位置边界测试通过。

**Step 5: Commit**

```bash
git add scenes/map_boundary.tscn scenes/main.tscn scenes/placement.tscn tests/integration/test_enemy_spawning.gd
git commit -m "feat: 地图边界重设为40x30网格对应1200x900"
```

---

### Task 6: 清理尺寸硬编码并补充文档说明

**Files:**
- Modify: `scripts/ui/placement.gd`（确认不再出现 32/1300/1000）
- Modify: `scripts/systems/enemy_spawner.gd`（确认不再出现 1250/950）
- Modify: `docs/design/dev-workflow.md`（新增尺寸标准小节）

**Step 1: Write the failing test**

在 `tests/unit/test_game_config_dimensions.gd` 增加“配置一致性”行为测试（先失败）：

```gdscript
func test_new_dimension_standard_values_are_stable():
	assert_eq(GameConfig.GRID_SIZE, GameConfig.PPU)
	assert_eq(GameConfig.MAP_PIXEL_WIDTH, 40 * 30)
	assert_eq(GameConfig.MAP_PIXEL_HEIGHT, 30 * 30)
```

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: 若前序未完全对齐，会失败；用于锁定标准。

**Step 3: Write minimal implementation**

在 `docs/design/dev-workflow.md` 增加“尺寸标准”段落，明确：

```markdown
### 尺寸标准（全局统一）
- 基准分辨率：640 x 360
- 显示放大：3x 对应 1080p
- PPU：30
- 网格单元：30 x 30 像素
- 地图尺寸：40 列 x 30 行（1200 x 900 像素）
- 地图中心：世界坐标原点 (0, 0)
```

**Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: PASS，全部尺寸标准测试通过。

**Step 5: Commit**

```bash
git add docs/design/dev-workflow.md tests/unit/test_game_config_dimensions.gd scripts/ui/placement.gd scripts/systems/enemy_spawner.gd
git commit -m "docs: 补充并锁定项目尺寸标准定义"
```

---

### Task 7: 最终验证（运行 + 测试 + 基本流程）

**Files:**
- No code changes expected

**Step 1: Run full tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: 全部 PASS。

**Step 2: Run project and verify runtime behavior**

使用 gdai-mcp：
- `run_project` 启动项目
- `get_debug_output` 检查是否有报错

验证要点：
- 窗口逻辑分辨率为 640x360
- `placement` 中塔吸附到 30x30 网格
- 塔不可放置到地图外
- 敌人在地图边界内生成

**Step 3: Final commit (if needed)**

若此任务无新增改动，跳过提交；有修复则单独提交：

```bash
git add <实际修改文件>
git commit -m "fix: 修正尺寸标准迁移后的残留问题"
```

---

## 风险与回滚点

- 风险 1：UI 在 640x360 下显得拥挤（尤其 `scenes/placement.tscn` 按钮区域）。
  - 处理：不改交互逻辑，仅调最小 `custom_minimum_size` 与容器偏移。
- 风险 2：地图变小后战斗节奏变快。
  - 处理：本计划不做数值平衡重构；若需要，后续单开 `feat/combat-rebalance`。
- 回滚策略：每个 Task 独立 commit，可按任务粒度 `git revert <commit>`。

---

## 完成定义（Definition of Done）

- [ ] 项目视口配置改为 640x360
- [ ] `GameConfig` 存在完整尺寸常量（PPU/GRID/MAP）
- [ ] `placement` 网格吸附与边界基于配置
- [ ] `enemy_spawner` 边界基于配置
- [ ] 地图边界场景与 1200x900 对齐
- [ ] 相关 GUT 测试通过
- [ ] 运行项目无报错且核心流程可进入战斗
