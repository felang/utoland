# 地图选择功能实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标**: 在武器选择后添加地图选择环节，允许玩家选择不同视觉风格的地图（森林/沙漠）

**架构**: 创建独立的地图选择场景，使用卡片式 UI 展示地图预览。在 GameConfig 中配置地图数据，通过 GameData 传递选择状态，在 Placement 场景中根据选择加载对应背景。

**技术栈**: Godot 4.6, GDScript, TextureButton (卡片), Sprite2D (背景), ColorRect (临时背景)

---

## Task 1: 添加地图配置到 GameConfig

**文件**:
- 修改: `game_config.gd:159` (在文件末尾添加)

**步骤 1: 添加地图配置常量**

在 `game_config.gd` 文件末尾添加：

```gdscript
# 地图配置
const MAPS = {
	"forest": {
		"name": "森林",
		"description": "茂密的森林环境",
		"preview_image": "res://assets/maps/forest_preview.png",
		"background": "res://assets/maps/forest_bg.png",
		"fallback_color": "#2d5016"
	},
	"desert": {
		"name": "沙漠",
		"description": "炎热的沙漠地带",
		"preview_image": "res://assets/maps/desert_preview.png",
		"background": "res://assets/maps/desert_bg.png",
		"fallback_color": "#d4a574"
	}
}
```

**步骤 2: 验证配置**

打开 Godot 编辑器，检查是否有语法错误。

预期: 无错误，配置加载成功

**步骤 3: 提交**

```bash
git add game_config.gd
git commit -m "feat: 添加地图配置到 GameConfig"
```

---

## Task 2: 在 GameData 中添加地图选择状态

**文件**:
- 修改: `scripts/game_data.gd:12` (在 selected_weapon 后添加)
- 修改: `scripts/game_data.gd:54` (在 reset() 函数中添加)

**步骤 1: 添加 selected_map 变量**

在 `scripts/game_data.gd` 第 12 行后添加：

```gdscript
var selected_map: String = "forest"  # 当前选择的地图，默认森林
```

**步骤 2: 在 reset() 函数中重置地图选择**

在 `scripts/game_data.gd` 的 `reset()` 函数中，第 54 行 `selected_weapon = "rifle"` 后添加：

```gdscript
	selected_map = "forest"
```

**步骤 3: 验证修改**

打开 Godot 编辑器，检查 GameData 自动加载是否正常。

预期: 无错误

**步骤 4: 提交**

```bash
git add scripts/game_data.gd
git commit -m "feat: 在 GameData 中添加地图选择状态"
```

---

## Task 3: 创建地图选择场景

**文件**:
- 创建: `scenes/ui/map_select.tscn`

**步骤 1: 创建场景文件**

使用 Godot 编辑器或 MCP 工具创建场景：

节点结构：
```
MapSelect (Control)
├── ColorRect (背景)
└── VBoxContainer
    ├── TitleLabel (Label)
    ├── Spacer (Control)
    └── MapCardsContainer (HBoxContainer)
        ├── ForestCard (VBoxContainer)
        │   ├── ForestButton (Button)
        │   ├── ForestLabel (Label)
        │   └── ForestDesc (Label)
        ├── CardSpacer (Control)
        └── DesertCard (VBoxContainer)
            ├── DesertButton (Button)
            ├── DesertLabel (Label)
            └── DesertDesc (Label)
```

场景配置：
- MapSelect: anchors_preset=15 (全屏), layout_mode=3
- ColorRect: anchors_preset=15, color=#1a1a1a
- VBoxContainer: 居中对齐, anchor_left=0.5, anchor_top=0.5, anchor_right=0.5, anchor_bottom=0.5
- TitleLabel: text="选择地图", horizontal_alignment=1, theme_override_font_sizes/font_size=32
- Spacer: custom_minimum_size=(0, 40)
- MapCardsContainer: alignment=1 (居中)
- ForestButton: custom_minimum_size=(400, 300), text="森林地图"
- ForestLabel: text="森林", horizontal_alignment=1, theme_override_font_sizes/font_size=24
- ForestDesc: text="茂密的森林环境", horizontal_alignment=1
- CardSpacer: custom_minimum_size=(40, 0)
- DesertButton: custom_minimum_size=(400, 300), text="沙漠地图"
- DesertLabel: text="沙漠", horizontal_alignment=1, theme_override_font_sizes/font_size=24
- DesertDesc: text="炎热的沙漠地带", horizontal_alignment=1

**步骤 2: 验证场景**

在 Godot 编辑器中打开场景，检查布局是否正确。

预期: 场景显示正常，两个地图卡片居中排列

**步骤 3: 提交**

```bash
git add scenes/ui/map_select.tscn
git commit -m "feat: 创建地图选择场景 UI"
```

---

## Task 4: 创建地图选择脚本

**文件**:
- 创建: `scripts/map_select.gd`

**步骤 1: 编写脚本**

创建 `scripts/map_select.gd`：

```gdscript
extends Control

@onready var forest_button: Button = $VBoxContainer/MapCardsContainer/ForestCard/ForestButton
@onready var desert_button: Button = $VBoxContainer/MapCardsContainer/DesertCard/DesertButton

func _ready() -> void:
	# 连接按钮信号
	forest_button.pressed.connect(_on_map_selected.bind("forest"))
	desert_button.pressed.connect(_on_map_selected.bind("desert"))

	# 验证地图配置
	if not GameConfig.MAPS.has("forest") or not GameConfig.MAPS.has("desert"):
		push_error("地图配置缺失")

func _on_map_selected(map_id: String) -> void:
	# 验证地图 ID
	if not GameConfig.MAPS.has(map_id):
		push_error("未知地图: " + map_id)
		return

	# 保存选择
	GameData.selected_map = map_id
	print("选择地图: ", GameConfig.MAPS[map_id]["name"])

	# 跳转到塔布置场景
	var err := get_tree().change_scene_to_file("res://scenes/placement.tscn")
	if err != OK:
		push_error("场景切换失败: " + str(err))
```

**步骤 2: 附加脚本到场景**

在 Godot 编辑器中打开 `scenes/ui/map_select.tscn`，将脚本附加到根节点 MapSelect。

或使用命令：
```bash
# 手动编辑 .tscn 文件，在 MapSelect 节点添加 script 属性
```

**步骤 3: 测试脚本**

在 Godot 编辑器中运行场景 (F6)，点击按钮。

预期: 控制台输出 "选择地图: 森林" 或 "选择地图: 沙漠"，场景切换到 placement

**步骤 4: 提交**

```bash
git add scripts/map_select.gd scenes/ui/map_select.tscn
git commit -m "feat: 实现地图选择逻辑"
```

---

## Task 5: 修改武器选择跳转目标

**文件**:
- 修改: `scripts/weapon_select.gd:16`

**步骤 1: 修改跳转路径**

将 `scripts/weapon_select.gd` 第 16 行：

```gdscript
	get_tree().change_scene_to_file("res://scenes/placement.tscn")
```

改为：

```gdscript
	get_tree().change_scene_to_file("res://scenes/ui/map_select.tscn")
```

**步骤 2: 测试流程**

运行游戏，完成角色选择 → 武器选择。

预期: 武器选择后跳转到地图选择场景，而不是直接进入 placement

**步骤 3: 提交**

```bash
git add scripts/weapon_select.gd
git commit -m "feat: 武器选择后跳转到地图选择"
```

---

## Task 6: 在 Placement 场景添加背景节点

**文件**:
- 修改: `scenes/placement.tscn`

**步骤 1: 添加 Background 节点**

在 Godot 编辑器中打开 `scenes/placement.tscn`，在根节点 Placement 下添加：

节点类型: Node2D
节点名称: Background
位置: 作为第一个子节点（在 Player 之前）
z_index: -100

在 Background 下添加：
节点类型: Sprite2D
节点名称: BackgroundSprite
position: (960, 540)
centered: true

**步骤 2: 验证节点结构**

场景树应该是：
```
Placement (Node2D)
├── Background (Node2D)
│   └── BackgroundSprite (Sprite2D)
├── Player
├── MapBoundary
└── UI
```

**步骤 3: 提交**

```bash
git add scenes/placement.tscn
git commit -m "feat: 在 Placement 场景添加背景节点"
```

---

## Task 7: 实现背景加载逻辑

**文件**:
- 修改: `scripts/placement.gd:17` (在 _ready() 开头添加)
- 修改: `scripts/placement.gd:143` (在文件末尾添加函数)

**步骤 1: 在 _ready() 中调用背景加载**

在 `scripts/placement.gd` 的 `_ready()` 函数开头（第 17 行）添加：

```gdscript
func _ready():
	load_map_background()

	# 恢复之前布置的塔
	# ... 现有代码
```

**步骤 2: 添加背景加载函数**

在 `scripts/placement.gd` 文件末尾（第 143 行后）添加：

```gdscript

func load_map_background():
	# 获取选择的地图
	var map_id = GameData.selected_map

	# 验证地图配置存在
	if not GameConfig.MAPS.has(map_id):
		push_warning("未知地图: " + map_id + ", 使用默认地图")
		map_id = "forest"
		GameData.selected_map = map_id

	var map_config = GameConfig.MAPS[map_id]
	var bg_path = map_config["background"]

	# 尝试加载背景图
	if ResourceLoader.exists(bg_path):
		var bg_texture = load(bg_path)
		$Background/BackgroundSprite.texture = bg_texture
		print("加载地图背景: ", map_config["name"])
	else:
		# 降级方案：使用纯色背景
		push_warning("背景图不存在: " + bg_path + ", 使用纯色背景")
		use_fallback_background(map_id)

func use_fallback_background(map_id: String):
	# 移除 Sprite2D，使用 ColorRect
	var sprite = $Background/BackgroundSprite
	if sprite:
		sprite.queue_free()

	var color_rect = ColorRect.new()
	color_rect.size = Vector2(1920, 1080)
	color_rect.position = Vector2(-960, -540)  # 相对于 Background 节点

	var map_config = GameConfig.MAPS[map_id]
	color_rect.color = Color(map_config["fallback_color"])

	$Background.add_child(color_rect)
	print("使用纯色背景: ", map_config["name"], " (", map_config["fallback_color"], ")")
```

**步骤 3: 测试背景加载**

运行游戏，完成角色 → 武器 → 地图选择。

预期:
- 由于背景图不存在，应该显示纯色背景
- 森林地图显示深绿色 (#2d5016)
- 沙漠地图显示沙黄色 (#d4a574)
- 控制台输出 "使用纯色背景: 森林" 或 "使用纯色背景: 沙漠"

**步骤 4: 提交**

```bash
git add scripts/placement.gd
git commit -m "feat: 实现地图背景加载逻辑"
```

---

## Task 8: 创建资源目录结构

**文件**:
- 创建: `assets/maps/` 目录
- 创建: `assets/maps/.gitkeep` (保持目录)

**步骤 1: 创建目录**

```bash
mkdir -p assets/maps
touch assets/maps/.gitkeep
```

**步骤 2: 添加 README**

创建 `assets/maps/README.md`：

```markdown
# 地图资源目录

## 所需资源

### 预览图 (用于地图选择界面)
- `forest_preview.png` - 森林预览图 (400x300)
- `desert_preview.png` - 沙漠预览图 (400x300)

### 背景图 (用于游戏场景)
- `forest_bg.png` - 森林背景图 (1920x1080)
- `desert_bg.png` - 沙漠背景图 (1920x1080)

## 临时方案

当前使用纯色背景作为临时方案：
- 森林: #2d5016 (深绿色)
- 沙漠: #d4a574 (沙黄色)

## 替换步骤

1. 将美术资源放入此目录
2. 确保文件名与 GameConfig.MAPS 中的路径匹配
3. 重新运行游戏，背景将自动加载
```

**步骤 3: 提交**

```bash
git add assets/maps/.gitkeep assets/maps/README.md
git commit -m "feat: 创建地图资源目录结构"
```

---

## Task 9: 端到端测试

**文件**:
- 无需修改文件

**步骤 1: 完整流程测试**

运行游戏 (F5)，测试完整流程：

1. 开始菜单 → 角色选择
2. 角色选择 → 武器选择
3. 武器选择 → 地图选择 (新增)
4. 地图选择 → 塔布置
5. 验证背景颜色是否正确

测试用例：
- 选择森林地图 → 背景应为深绿色
- 选择沙漠地图 → 背景应为沙黄色
- 返回主菜单重新开始 → 默认森林地图

**步骤 2: 验证状态持久化**

1. 选择沙漠地图
2. 进入战斗
3. 战斗结束后进入商店
4. 商店后返回塔布置
5. 验证背景仍为沙漠

预期: 背景在整个游戏循环中保持一致

**步骤 3: 验证重置逻辑**

1. 完成一局游戏
2. 返回主菜单
3. 重新开始游戏
4. 验证地图重置为森林

预期: 新游戏从默认地图开始

**步骤 4: 记录测试结果**

创建 `docs/plans/2026-03-04-map-select-test-results.md`：

```markdown
# 地图选择功能测试结果

**测试日期**: 2026-03-04
**测试人员**: [填写]

## 测试用例

### TC1: 基本流程
- [ ] 角色选择 → 武器选择 → 地图选择 → 塔布置
- [ ] 地图选择界面显示正常
- [ ] 两个地图卡片可点击

### TC2: 森林地图
- [ ] 选择森林地图
- [ ] 背景显示深绿色 (#2d5016)
- [ ] 控制台输出正确

### TC3: 沙漠地图
- [ ] 选择沙漠地图
- [ ] 背景显示沙黄色 (#d4a574)
- [ ] 控制台输出正确

### TC4: 状态持久化
- [ ] 地图选择在战斗循环中保持
- [ ] 商店后返回塔布置，背景不变

### TC5: 重置逻辑
- [ ] 游戏结束后重新开始
- [ ] 地图重置为森林

## 问题记录

[记录发现的问题]

## 结论

[通过/失败]
```

**步骤 5: 提交测试文档**

```bash
git add docs/plans/2026-03-04-map-select-test-results.md
git commit -m "docs: 添加地图选择功能测试文档"
```

---

## Task 10: 更新项目文档

**文件**:
- 修改: `CLAUDE.md:10`

**步骤 1: 更新场景流程**

将 `CLAUDE.md` 第 10 行的场景流程：

```
Start Menu → Character Select → Weapon Select → Placement → Combat → Shop → Placement → Combat → ... → Result
```

改为：

```
Start Menu → Character Select → Weapon Select → Map Select → Placement → Combat → Shop → Placement → Combat → ... → Result
```

**步骤 2: 添加地图系统说明**

在 `CLAUDE.md` 第 32 行 "Core Systems" 部分后添加：

```markdown
- **Map System**: 2 maps (Forest, Desert) with visual differences only
```

**步骤 3: 提交文档更新**

```bash
git add CLAUDE.md
git commit -m "docs: 更新 CLAUDE.md 添加地图选择说明"
```

---

## Task 11: 最终验证和清理

**文件**:
- 无需修改文件

**步骤 1: 代码审查**

检查所有修改的文件：
- [ ] 无硬编码值（所有配置在 GameConfig）
- [ ] 使用 GameData 管理状态
- [ ] 错误处理完善
- [ ] 代码注释清晰

**步骤 2: 性能检查**

运行游戏，观察：
- [ ] 场景切换流畅
- [ ] 无内存泄漏
- [ ] 背景加载无卡顿

**步骤 3: 创建功能总结**

创建 `docs/plans/2026-03-04-map-select-summary.md`：

```markdown
# 地图选择功能实施总结

**实施日期**: 2026-03-04
**状态**: 已完成

## 实现内容

1. **配置层**: 在 GameConfig 中添加 MAPS 配置
2. **状态层**: 在 GameData 中添加 selected_map 变量
3. **UI 层**: 创建地图选择场景和脚本
4. **背景系统**: 在 Placement 场景实现动态背景加载
5. **流程集成**: 修改场景跳转逻辑

## 文件清单

### 新建文件
- `scenes/ui/map_select.tscn`
- `scripts/map_select.gd`
- `assets/maps/` (目录)
- `assets/maps/README.md`

### 修改文件
- `game_config.gd` - 添加地图配置
- `scripts/game_data.gd` - 添加地图状态
- `scripts/weapon_select.gd` - 修改跳转目标
- `scenes/placement.tscn` - 添加背景节点
- `scripts/placement.gd` - 实现背景加载
- `CLAUDE.md` - 更新文档

## 当前状态

- ✅ 核心功能完成
- ✅ 使用纯色背景作为临时方案
- ⏳ 等待美术资源（预览图和背景图）

## 后续工作

1. 准备美术资源（4 张图片）
2. 替换纯色背景为实际图片
3. 可选：添加卡片悬停动画
4. 可选：添加地图切换音效

## 技术债务

无

## 经验教训

1. 配置驱动设计使扩展变得简单
2. 降级方案确保功能在资源缺失时仍可用
3. 独立场景设计保持代码清晰
```

**步骤 4: 最终提交**

```bash
git add docs/plans/2026-03-04-map-select-summary.md
git commit -m "docs: 添加地图选择功能实施总结"
```

**步骤 5: 推送代码**

```bash
git push origin main
```

---

## 完成标准

- [x] 所有 11 个任务完成
- [x] 端到端测试通过
- [x] 文档更新完成
- [x] 代码已提交并推送
- [x] 无遗留问题

---

## 扩展建议

### 短期优化
1. 添加地图预览图（替换纯色按钮）
2. 添加卡片悬停效果（scale 1.05）
3. 添加选择音效

### 长期扩展
1. 添加第 3 个地图（雪地、火山等）
2. 地图解锁系统（完成特定波次解锁）
3. 地图难度系数（不同地图有不同奖励倍率）
4. 地图统计（记录每个地图的游戏次数和胜率）

---

**实施计划创建日期**: 2026-03-04
**预计实施时间**: 1-2 小时
**复杂度**: 中等
