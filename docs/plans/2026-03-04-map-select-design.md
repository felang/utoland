# 地图选择功能设计文档

**日期**: 2026-03-04
**功能**: 在武器选择后、塔布置前添加地图选择环节
**类型**: 纯视觉差异的地图选择系统

---

## 需求概述

为游戏添加地图选择功能，允许玩家在进入战斗前选择不同视觉风格的地图。地图之间仅有视觉差异，不影响游戏机制和难度。

**核心需求**：
- 2-3 个地图供选择（初期实现 2 个：森林、沙漠）
- 纯视觉差异，不影响游戏玩法
- 卡片预览式选择界面
- 流程位置：武器选择后 → 地图选择 → 塔布置

---

## 场景流程设计

### 更新后的游戏流程

```
Start Menu
  ↓
Character Select
  ↓
Weapon Select
  ↓
Map Select (新增)
  ↓
Placement
  ↓
Combat
  ↓
Shop
  ↓
(循环 Placement → Combat → Shop)
  ↓
Result
```

### 场景跳转修改

**修改点 1**: `scripts/weapon_select.gd`
- 原跳转目标: `res://scenes/placement.tscn`
- 新跳转目标: `res://scenes/ui/map_select.tscn`

**修改点 2**: `scripts/map_select.gd` (新建)
- 跳转目标: `res://scenes/placement.tscn`

---

## 数据层设计

### GameConfig 地图配置

在 `game_config.gd` 中添加：

```gdscript
# 地图配置
const MAPS = {
	"forest": {
		"name": "森林",
		"description": "茂密的森林环境",
		"preview_image": "res://assets/maps/forest_preview.png",
		"background": "res://assets/maps/forest_bg.png"
	},
	"desert": {
		"name": "沙漠",
		"description": "炎热的沙漠地带",
		"preview_image": "res://assets/maps/desert_preview.png",
		"background": "res://assets/maps/desert_bg.png"
	}
}
```

**字段说明**：
- `name`: 地图显示名称
- `description`: 地图描述文字
- `preview_image`: 选择界面预览图路径
- `background`: 游戏场景背景图路径

**扩展性**：
- 预留可选字段：`difficulty_modifier`（难度系数）、`music`（背景音乐）等
- 未来可轻松添加第 3、4 个地图

### GameData 状态管理

在 `scripts/game_data.gd` 中添加：

```gdscript
var selected_map: String = "forest"  # 当前选择的地图，默认森林
```

在 `reset()` 函数中添加：

```gdscript
func reset() -> void:
	# ... 现有代码
	selected_map = "forest"  # 重置为默认地图
```

---

## UI 设计

### 地图选择场景布局

```
┌─────────────────────────────────────────────┐
│              选择地图 (Title)                │
│                                             │
│    ┌──────────────┐      ┌──────────────┐  │
│    │              │      │              │  │
│    │    森林      │      │    沙漠      │  │
│    │  [预览图]    │      │  [预览图]    │  │
│    │              │      │              │  │
│    └──────────────┘      └──────────────┘  │
│    茂密的森林环境         炎热的沙漠地带    │
│                                             │
└─────────────────────────────────────────────┘
```

### 节点结构

**场景**: `scenes/ui/map_select.tscn`

```
MapSelect (Control)
├── VBoxContainer
│   ├── TitleLabel (Label) - "选择地图"
│   ├── Spacer (Control) - 间距
│   └── MapCardsContainer (HBoxContainer)
│       ├── ForestCard (VBoxContainer)
│       │   ├── ForestButton (TextureButton) - 预览图按钮
│       │   ├── ForestLabel (Label) - "森林"
│       │   └── ForestDesc (Label) - "茂密的森林环境"
│       ├── Spacer (Control) - 卡片间距
│       └── DesertCard (VBoxContainer)
│           ├── DesertButton (TextureButton)
│           ├── DesertLabel (Label) - "沙漠"
│           └── DesertDesc (Label) - "炎热的沙漠地带"
```

### UI 规格

**卡片尺寸**：
- 预览图按钮: 400x300 像素
- 卡片间距: 40 像素
- 标题字体大小: 32
- 描述字体大小: 16

**布局**：
- 整体居中对齐
- 卡片水平排列
- 标题在顶部，描述在底部

**交互**：
- 点击任意卡片 → 保存选择 → 跳转到 Placement
- 可选：悬停效果（卡片轻微放大 1.05 倍）

---

## 背景加载系统

### Placement 场景修改

**节点结构更新**：

```
Placement (Node2D)
├── Background (Sprite2D) - 新增背景节点
├── MapBoundary
├── Player
└── UI
```

**Background 节点配置**：
- Position: (960, 540) - 屏幕中心
- Z Index: -100 - 确保在所有元素后面
- Centered: true

### 背景加载逻辑

在 `scripts/placement.gd` 的 `_ready()` 中添加：

```gdscript
func _ready():
	load_map_background()
	# ... 现有初始化逻辑

func load_map_background():
	# 获取选择的地图
	var map_id = GameData.selected_map

	# 验证地图配置存在
	if not GameConfig.MAPS.has(map_id):
		push_warning("未知地图: " + map_id + ", 使用默认地图")
		map_id = "forest"
		GameData.selected_map = map_id

	# 加载背景图
	var map_config = GameConfig.MAPS[map_id]
	var bg_path = map_config["background"]

	if ResourceLoader.exists(bg_path):
		var bg_texture = load(bg_path)
		$Background.texture = bg_texture
	else:
		push_warning("背景图不存在: " + bg_path + ", 使用纯色背景")
		# 降级方案：使用纯色背景
		use_fallback_background(map_id)

func use_fallback_background(map_id: String):
	# 临时方案：使用 ColorRect 作为纯色背景
	var color_rect = ColorRect.new()
	color_rect.size = Vector2(1920, 1080)
	color_rect.position = Vector2(0, 0)
	color_rect.z_index = -100

	if map_id == "forest":
		color_rect.color = Color("#2d5016")  # 深绿色
	elif map_id == "desert":
		color_rect.color = Color("#d4a574")  # 沙黄色
	else:
		color_rect.color = Color("#333333")  # 默认灰色

	add_child(color_rect)
	move_child(color_rect, 0)  # 移到最底层
```

---

## 资源需求

### 图片资源清单

**预览图**（用于地图选择界面）：
1. `assets/maps/forest_preview.png` - 森林预览图
   - 尺寸: 400x300 像素
   - 格式: PNG

2. `assets/maps/desert_preview.png` - 沙漠预览图
   - 尺寸: 400x300 像素
   - 格式: PNG

**背景图**（用于游戏场景）：
3. `assets/maps/forest_bg.png` - 森林背景图
   - 尺寸: 1920x1080 像素（或更大）
   - 格式: PNG 或 JPG

4. `assets/maps/desert_bg.png` - 沙漠背景图
   - 尺寸: 1920x1080 像素（或更大）
   - 格式: PNG 或 JPG

### 临时方案

**如果暂无美术资源**，使用纯色背景：
- 森林: `#2d5016` (深绿色)
- 沙漠: `#d4a574` (沙黄色)

**预览图临时方案**：
- 使用纯色 TextureRect + 文字标识
- 或使用 Godot 内置的占位符纹理

---

## 错误处理

### 配置验证

**地图 ID 验证**：
```gdscript
if not GameConfig.MAPS.has(map_id):
	push_warning("未知地图: " + map_id)
	map_id = "forest"  # 回退到默认地图
```

**资源加载验证**：
```gdscript
if ResourceLoader.exists(bg_path):
	var bg_texture = load(bg_path)
else:
	push_warning("背景图不存在: " + bg_path)
	use_fallback_background(map_id)
```

### 边界情况

1. **地图配置缺失**: 回退到 "forest" 默认地图
2. **背景图加载失败**: 使用纯色背景降级方案
3. **预览图加载失败**: 显示占位符或纯色块
4. **游戏重置**: `GameData.reset()` 时重置为默认地图

---

## 实现文件清单

### 新建文件

1. `scenes/ui/map_select.tscn` - 地图选择场景
2. `scripts/map_select.gd` - 地图选择逻辑脚本
3. `assets/maps/` - 地图资源目录（需创建）

### 修改文件

1. `game_config.gd` - 添加 MAPS 配置
2. `scripts/game_data.gd` - 添加 selected_map 变量和重置逻辑
3. `scripts/weapon_select.gd` - 修改跳转目标
4. `scenes/placement.tscn` - 添加 Background 节点
5. `scripts/placement.gd` - 添加背景加载逻辑

---

## 测试要点

### 功能测试

1. **流程测试**: 角色选择 → 武器选择 → 地图选择 → 塔布置，流程完整
2. **地图切换**: 选择不同地图，背景正确显示
3. **默认行为**: 首次进入游戏，默认显示森林地图
4. **重置测试**: 游戏结束后重新开始，地图重置为默认

### 错误处理测试

1. **配置缺失**: 删除地图配置，验证回退逻辑
2. **资源缺失**: 删除背景图，验证降级方案
3. **无效选择**: 手动设置无效 map_id，验证验证逻辑

### UI 测试

1. **布局**: 不同分辨率下卡片布局正确
2. **交互**: 点击卡片响应正常
3. **视觉**: 预览图显示清晰，文字可读

---

## 未来扩展

### 第 3 个地图

添加新地图只需：
1. 在 `GameConfig.MAPS` 中添加配置
2. 在 `map_select.tscn` 中添加新卡片
3. 准备对应的预览图和背景图

### 可选功能

1. **地图解锁系统**: 某些地图需要完成特定条件才能解锁
2. **地图难度**: 不同地图有不同的难度系数
3. **地图特效**: 天气效果、粒子系统等
4. **背景音乐**: 每个地图有独特的背景音乐
5. **地图统计**: 记录每个地图的游戏次数、胜率等

---

## 设计原则

1. **配置驱动**: 所有地图数据集中在 GameConfig，便于管理
2. **状态管理**: 使用 GameData 单例存储选择状态
3. **错误容错**: 完善的验证和降级方案
4. **扩展性**: 易于添加新地图，预留扩展字段
5. **一致性**: UI 风格与现有选择界面保持一致

---

## 实施优先级

**Phase 1 - 核心功能**:
1. 创建地图选择场景和脚本
2. 添加配置和状态管理
3. 修改场景跳转逻辑
4. 实现背景加载系统

**Phase 2 - 资源准备**:
1. 准备临时纯色背景
2. 创建占位符预览图
3. 测试完整流程

**Phase 3 - 美术资源**:
1. 替换为正式美术资源
2. 优化 UI 视觉效果
3. 添加交互动画（可选）

---

**设计完成日期**: 2026-03-04
**设计状态**: 已批准，待实施
