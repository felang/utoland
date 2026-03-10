# TileMap 地图系统实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 TileMapLayer 替换当前纯色背景，实现像素风格地图渲染，支持多地图场景动态加载。

**Architecture:** 每个地图（forest/desert）独立一个 .tscn 场景文件，内含两层 TileMapLayer（地面层 + 装饰层）。MapData 新增 `map_scene` 字段，main.gd 在 `_ready()` 中根据 `GameData.selected_map` 动态实例化并插入场景底层。TileSet 在 Godot 编辑器中可视化配置，图块大小 32×32，地图覆盖 40×30 格（1280×960 px）。

**Tech Stack:** Godot 4.6, GDScript, TileMapLayer, TileSet (.tres)

---

## 前置条件（手动操作，开始编码前完成）

- [ ] 从 itch.io（或其他来源）下载像素风格地图 tileset PNG（32×32 像素图块）
  - 推荐搜索："pixel tileset free 32x32 forest"
  - 需要两套素材：森林风格、沙漠风格（或先只做森林）
- [ ] 将素材放入：`assets/tilesets/forest_tileset.png`（沙漠：`assets/tilesets/desert_tileset.png`）
- [ ] 创建目录：`mkdir -p assets/tilesets/`

---

## Chunk 1: 代码变更（MapData + main.gd）

### Task 1: MapData 新增 map_scene 字段

**Files:**
- Modify: `scripts/resources/map_data.gd`
- Modify: `resources/maps/forest.tres`
- Modify: `resources/maps/desert.tres`
- Test: `tests/unit/test_map_waves.gd`（在现有文件追加）

- [ ] **Step 1: 写失败测试**

在 `tests/unit/test_map_waves.gd` 末尾追加：

```gdscript
func test_map_data_has_map_scene_field():
	var md := MapData.new()
	assert_true("map_scene" in md, "MapData 应有 map_scene 字段")
	assert_eq(md.map_scene, "", "map_scene 默认值应为空字符串")
```

- [ ] **Step 2: 运行测试确认失败**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | grep -A2 "test_map_data_has_map_scene"
```

预期：FAIL（字段不存在）

- [ ] **Step 3: 在 MapData 添加字段**

`scripts/resources/map_data.gd`，在 `wave_count` 行后追加：

```gdscript
@export var map_scene: String = ""  # 指向对应地图场景，如 res://scenes/levels/maps/forest.tscn
```

- [ ] **Step 4: 运行测试确认通过**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | grep -E "(PASS|FAIL|test_map_data)"
```

预期：PASS

- [ ] **Step 5: 更新 forest.tres 填入 map_scene**

`resources/maps/forest.tres`，在 `[resource]` 块末尾追加：

```
map_scene = "res://scenes/levels/maps/forest.tscn"
```

- [ ] **Step 6: 更新 desert.tres 填入 map_scene**

`resources/maps/desert.tres`，在 `[resource]` 块末尾追加：

```
map_scene = "res://scenes/levels/maps/desert.tscn"
```

- [ ] **Step 6.5: 写验证测试（确认 .tres 值已正确写入）**

> 注意：此时 `scenes/levels/maps/` 目录尚不存在（将在 Chunk 2 创建）。测试仅验证 `.tres` 中 `map_scene` 字段有值，**不验证文件是否存在**（文件存在性测试在 Chunk 2 的 Task 5 中进行）。

在 `tests/unit/test_map_waves.gd` 末尾追加：

```gdscript
func test_forest_map_scene_configured():
	var md: MapData = GameConfig.maps.get("forest")
	assert_not_null(md, "forest MapData 应存在")
	assert_ne(md.map_scene, "", "forest.tres 应配置 map_scene 路径")

func test_desert_map_scene_configured():
	var md: MapData = GameConfig.maps.get("desert")
	assert_not_null(md, "desert MapData 应存在")
	assert_ne(md.map_scene, "", "desert.tres 应配置 map_scene 路径")
```

运行测试确认通过：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | grep -E "(PASS|FAIL|test_.*map_scene)"
```

预期：PASS

- [ ] **Step 7: 提交**

```bash
git add scripts/resources/map_data.gd resources/maps/forest.tres resources/maps/desert.tres tests/unit/test_map_waves.gd
git commit -m "feat: MapData 新增 map_scene 字段"
```

---

### Task 2: main.gd 动态加载地图场景

**Files:**
- Modify: `scripts/ui/main.gd`

> 注意：`main.gd` 的动态场景加载依赖 Godot 场景树，无法在 headless GUT 环境中进行有意义的单元测试。跳过 TDD 步骤，改为编辑器手动验证。数据层（MapData.map_scene 字段和 .tres 值）已在 Task 1 中通过测试覆盖。

- [ ] **Step 1: 在 main.gd 的 _ready() 首行插入 _load_map() 调用**

在 `scripts/ui/main.gd` 中，将 `func _ready() -> void:` 的第一行改为调用 `_load_map()`：

Edit `scripts/ui/main.gd`，将：
```gdscript
func _ready() -> void:
	# 暂停覆盖层
```
改为：
```gdscript
func _ready() -> void:
	_load_map()
	# 暂停覆盖层
```

- [ ] **Step 2: 在 main.gd 末尾追加 _load_map() 方法**

在 `scripts/ui/main.gd` 末尾追加：

```gdscript
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
	move_child(map_instance, 0)  # 确保地图在最底层
```

- [ ] **Step 3: 在 Godot 编辑器中打开 main.tscn，验证无脚本报错**

（此步骤需要手动验证，或通过 gdai-mcp `play_scene` 工具运行场景）

- [ ] **Step 4: 提交**

```bash
git add scripts/ui/main.gd
git commit -m "feat: main.gd 动态加载地图场景"
```

---

## Chunk 2: 场景创建与编辑器配置

### Task 3: 创建地图场景目录和 forest.tscn

**Files:**
- Create: `scenes/levels/maps/forest.tscn`

> **前置条件**：`assets/tilesets/forest_tileset.png` 必须已存在（见计划开头的前置条件步骤），否则 TileSet 配置无法进行。
>
> 此任务在 Godot 编辑器中完成（或通过 gdai-mcp MCP 工具）。
>
> `resources/maps/forest.tres` 的 `map_scene` 字段已在 Chunk 1 Task 1 中配置，无需在此重复操作。

- [ ] **Step 1: 创建目录**

```bash
mkdir -p scenes/levels/maps
```

- [ ] **Step 2: 在 Godot 编辑器中创建 forest.tscn**

1. FileSystem 面板右键 `scenes/levels/maps/` → New Scene
2. 根节点选 `Node2D`，重命名为 `ForestMap`
3. 保存为 `scenes/levels/maps/forest.tscn`

或通过 gdai-mcp 工具 `create_scene`，然后 `add_node` 添加 TileMapLayer。

- [ ] **Step 3: 添加地面层 TileMapLayer**

1. 在 ForestMap 下添加子节点 `TileMapLayer`，重命名为 `Ground`
2. 设置 position = `Vector2(-640, -480)`（使地图以原点为中心）

> 说明：地图 40×30 格，每格 32px，总尺寸 1280×960。position(-640,-480) 使左上角对齐地图边界原点。

- [ ] **Step 4: 添加装饰层 TileMapLayer**

1. 在 ForestMap 下再添加子节点 `TileMapLayer`，重命名为 `Decoration`
2. 设置 position = `Vector2(-640, -480)`（与 Ground 层一致）

- [ ] **Step 5: 配置 TileSet（在 Ground 层）**

**5a. 创建 TileSet 资源：**
1. 选中 Ground 节点，Inspector 中 TileSet 属性点击 `<New TileSet>`
2. 打开底部 TileSet 面板 → `+` → `Atlas` → 选择 `forest_tileset.png`
3. 设置图块大小为 **32×32**
4. 保存 TileSet 为 `resources/maps/tilesets/forest_tileset.tres`

**5b. 绘制地面图块（内容创作）：**
1. 切换到底部 TileMap 面板
2. 选择地面图块（草地/泥土等基础图块）
3. 使用矩形填充工具刷满整个 40×30 格区域（1280×960 px 范围）

- [ ] **Step 6: 在 Decoration 层配置同一 TileSet（或单独装饰 TileSet）**

1. 选中 Decoration 节点，TileSet 属性选择与 Ground 相同的 TileSet
2. 使用装饰图块（树、石头等）在地图上稀疏绘制

- [ ] **Step 7: 保存场景并提交**

```bash
git add scenes/levels/maps/forest.tscn resources/maps/tilesets/
git commit -m "feat: 添加森林地图场景 (TileMapLayer)"
```

---

### Task 4: 创建 desert.tscn

**Files:**
- Create: `scenes/levels/maps/desert.tscn`

> 流程与 Task 3 相同，替换 tileset 为沙漠素材。

- [ ] **Step 1: 在 Godot 编辑器中创建 desert.tscn**

1. 复制 `scenes/levels/maps/forest.tscn` → 另存为 `desert.tscn`，或重新创建
2. 根节点重命名为 `DesertMap`

- [ ] **Step 2: 配置沙漠 TileSet**

1. Ground 层 TileSet → 使用 `desert_tileset.png`（或与 forest 共用同一张 tileset 但选不同图块）
2. 刷满 40×30 格
3. 保存 TileSet 为 `resources/maps/tilesets/desert_tileset.tres`

- [ ] **Step 3: 保存场景并提交**

```bash
git add scenes/levels/maps/desert.tscn resources/maps/tilesets/
git commit -m "feat: 添加沙漠地图场景 (TileMapLayer)"
```

---

### Task 5: 端到端验证

- [ ] **Step 0: 写场景文件存在性测试（补全 Chunk 1 遗留测试）**

在 `tests/unit/test_map_waves.gd` 末尾追加：

```gdscript
func test_forest_map_scene_file_exists():
	var md: MapData = GameConfig.maps.get("forest")
	# FileAccess.file_exists 支持 res:// 路径，在 headless 模式下直接检查文件系统
	assert_true(FileAccess.file_exists(md.map_scene), "forest 地图场景文件应存在于磁盘")

func test_desert_map_scene_file_exists():
	var md: MapData = GameConfig.maps.get("desert")
	assert_true(FileAccess.file_exists(md.map_scene), "desert 地图场景文件应存在于磁盘")
```

- [ ] **Step 1: 运行完整测试套件**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -gexit
```

预期：全部 PASS，无新增失败

- [ ] **Step 2: 在编辑器中运行主场景，选择森林地图进入战斗**

确认：
- 地图背景显示为 TileMapLayer 渲染的像素图块
- 玩家、敌人正常移动
- 边界碰撞正常（MapBoundary 不受影响）

- [ ] **Step 3: 切换为沙漠地图，重复验证**

- [ ] **Step 4: 最终提交（如有未提交改动）**

```bash
git add -A
git commit -m "chore: TileMap 地图系统完成验证"
```
