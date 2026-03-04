# 角色系统实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 Utoland 游戏添加多角色选择功能，支持轻度差异化角色（数值差异）

**Architecture:** 配置驱动架构，在 GameConfig 中定义角色数据，通过 GameData.init_character() 初始化角色属性，player.gd 直接使用最终属性值。添加角色选择界面插入到游戏流程中。

**Tech Stack:** Godot 4.6, GDScript, 配置驱动设计

---

## 任务 1：添加角色配置

**Files:**
- Modify: `game_config.gd:113` (在 PLAYER 配置后添加)

**Step 1: 添加 CHARACTERS 配置**

在 `game_config.gd` 的 `PLAYER` 配置后添加：

```gdscript
# 角色配置
const CHARACTERS = {
	"warrior": {
		"name": "战士",
		"description": "高生命值，低速度",
		"max_hp": 150.0,
		"speed": 180.0,
		"damage_mult": 1.2,
		"attack_speed_mult": 1.0,
		"move_speed_mult": 0.9,
		"hp_regen": 0.0
	},
	"ranger": {
		"name": "游侠",
		"description": "低生命值，高速度",
		"max_hp": 80.0,
		"speed": 250.0,
		"damage_mult": 0.9,
		"attack_speed_mult": 1.1,
		"move_speed_mult": 1.25,
		"hp_regen": 0.0
	},
	"tank": {
		"name": "坦克",
		"description": "超高生命值，极低速度",
		"max_hp": 200.0,
		"speed": 150.0,
		"damage_mult": 0.8,
		"attack_speed_mult": 0.9,
		"move_speed_mult": 0.75,
		"hp_regen": 1.0
	}
}
```

**Step 2: 验证配置**

使用 MCP 工具验证语法：

```bash
# 检查文件语法
cat game_config.gd | grep -A 20 "CHARACTERS"
```

Expected: 显示完整的 CHARACTERS 配置，无语法错误

**Step 3: Commit**

```bash
git add game_config.gd
git commit -m "feat: 添加角色配置到 GameConfig"
```

---

## 任务 2：修改 GameData 支持角色系统

**Files:**
- Modify: `scripts/game_data.gd:1-33`

**Step 1: 添加 selected_character 字段**

在 `game_data.gd` 的第 3 行后添加：

```gdscript
var selected_character: String = "warrior"  # 默认角色
```

**Step 2: 添加 init_character 方法**

在 `game_data.gd` 的 `reset()` 方法前添加：

```gdscript
func init_character(character_id: String) -> void:
	selected_character = character_id
	var char_config = GameConfig.CHARACTERS[character_id]

	player_stats = {
		"max_hp": char_config["max_hp"],
		"speed": char_config["speed"],
		"hp_regen": char_config["hp_regen"],
		"damage_mult": char_config["damage_mult"],
		"attack_speed_mult": char_config["attack_speed_mult"],
		"move_speed_mult": char_config["move_speed_mult"],
		"tower_mult": 1.0
	}
```

**Step 3: 修改 _ready 方法**

将原有的 `player_stats` 初始化删除，改为调用 `init_character()`：

```gdscript
func _ready():
	init_character(selected_character)
```

**Step 4: 修改 reset 方法**

将 `reset()` 方法改为：

```gdscript
func reset():
	init_character(selected_character)
	coins = GameConfig.PLAYER["initial_coins"]
	current_wave = 0
	tower_inventory = []
	purchased_towers = []
	pending_heal = 0
```

**Step 5: 验证修改**

检查修改后的文件：

```bash
cat scripts/game_data.gd
```

Expected:
- 有 `selected_character` 字段
- 有 `init_character()` 方法
- `_ready()` 调用 `init_character()`
- `reset()` 调用 `init_character()`

**Step 6: Commit**

```bash
git add scripts/game_data.gd
git commit -m "feat: GameData 支持角色初始化"
```

---

## 任务 3：修改 player.gd 使用新的属性系统

**Files:**
- Modify: `scripts/player.gd:25`

**Step 1: 修改速度读取逻辑**

找到 `player.gd` 第 25 行：

```gdscript
# 之前
speed = GameConfig.PLAYER["initial_speed"] * GameData.player_stats["move_speed_mult"]
```

改为：

```gdscript
# 之后
speed = GameData.player_stats["speed"]
```

**Step 2: 验证修改**

```bash
grep -n "speed = " scripts/player.gd | head -5
```

Expected: 第 25 行显示 `speed = GameData.player_stats["speed"]`

**Step 3: 测试运行**

使用 MCP 工具运行主场景：

```
mcp__gdai-mcp__play_scene
projectPath: /Users/langtao/utoland
scenePath: res://scenes/main.tscn
```

Expected: 游戏正常运行，玩家速度为 180（战士默认速度）

**Step 4: 查看调试输出**

```
mcp__gdai-mcp__get_godot_errors
```

Expected: 无错误，玩家正常移动

**Step 5: 停止场景**

```
mcp__gdai-mcp__stop_running_scene
```

**Step 6: Commit**

```bash
git add scripts/player.gd
git commit -m "refactor: player.gd 使用 player_stats 中的最终速度值"
```

---

## 任务 4：创建角色选择场景

**Files:**
- Create: `scenes/ui/character_select.tscn`
- Create: `scripts/character_select.gd`

**Step 1: 创建角色选择脚本**

创建 `scripts/character_select.gd`：

```gdscript
extends Control

@onready var warrior_button: Button = $VBoxContainer/WarriorButton
@onready var ranger_button: Button = $VBoxContainer/RangerButton
@onready var tank_button: Button = $VBoxContainer/TankButton
@onready var description_label: Label = $DescriptionLabel

var selected_character_id: String = ""

func _ready():
	warrior_button.pressed.connect(_on_character_selected.bind("warrior"))
	ranger_button.pressed.connect(_on_character_selected.bind("ranger"))
	tank_button.pressed.connect(_on_character_selected.bind("tank"))

	# 显示默认描述
	_show_character_info("warrior")

func _on_character_selected(character_id: String):
	if selected_character_id == character_id:
		# 再次点击确认选择
		GameData.init_character(character_id)
		get_tree().change_scene_to_file("res://scenes/ui/weapon_select.tscn")
	else:
		# 第一次点击显示信息
		selected_character_id = character_id
		_show_character_info(character_id)

func _show_character_info(character_id: String):
	var char_config = GameConfig.CHARACTERS[character_id]
	var info_text = "%s\n\n%s\n\n生命值: %.0f\n速度: %.0f\n伤害倍率: %.1fx\n攻速倍率: %.1fx" % [
		char_config["name"],
		char_config["description"],
		char_config["max_hp"],
		char_config["speed"],
		char_config["damage_mult"],
		char_config["attack_speed_mult"]
	]
	description_label.text = info_text
```

**Step 2: 创建角色选择场景**

使用 MCP 工具创建场景：

```
mcp__gdai-mcp__create_scene
projectPath: /Users/langtao/utoland
scenePath: res://scenes/ui/character_select.tscn
rootNodeType: Control
```

**Step 3: 添加 UI 节点**

手动编辑 `scenes/ui/character_select.tscn`，或使用编辑器添加以下节点结构：

```
Control (character_select)
├── Label (标题)
│   - text: "选择角色"
│   - position: (400, 50)
├── VBoxContainer
│   - position: (300, 150)
│   - spacing: 20
│   ├── Button (WarriorButton)
│   │   - text: "战士"
│   │   - custom_minimum_size: (200, 50)
│   ├── Button (RangerButton)
│   │   - text: "游侠"
│   │   - custom_minimum_size: (200, 50)
│   └── Button (TankButton)
│       - text: "坦克"
│       - custom_minimum_size: (200, 50)
└── Label (DescriptionLabel)
    - position: (600, 150)
    - custom_minimum_size: (400, 300)
    - autowrap_mode: AUTOWRAP_WORD
```

**Step 4: 附加脚本到场景**

```
mcp__gdai-mcp__attach_script
projectPath: /Users/langtao/utoland
scenePath: res://scenes/ui/character_select.tscn
nodePath: .
scriptPath: res://scripts/character_select.gd
```

**Step 5: 测试角色选择界面**

```
mcp__gdai-mcp__play_scene
projectPath: /Users/langtao/utoland
scenePath: res://scenes/ui/character_select.tscn
```

Expected:
- 显示三个角色按钮
- 点击按钮显示角色信息
- 再次点击跳转到武器选择

**Step 6: 查看调试输出**

```
mcp__gdai-mcp__get_godot_errors
```

Expected: 无错误

**Step 7: 停止场景**

```
mcp__gdai-mcp__stop_running_scene
```

**Step 8: Commit**

```bash
git add scenes/ui/character_select.tscn scripts/character_select.gd
git commit -m "feat: 添加角色选择界面"
```

---

## 任务 5：修改开始菜单跳转到角色选择

**Files:**
- Modify: `scripts/start_menu.gd`

**Step 1: 查看当前跳转逻辑**

```bash
grep -n "weapon_select" scripts/start_menu.gd
```

**Step 2: 修改跳转目标**

将跳转目标从 `weapon_select.tscn` 改为 `character_select.tscn`：

```gdscript
# 找到类似这样的代码
get_tree().change_scene_to_file("res://scenes/ui/weapon_select.tscn")

# 改为
get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")
```

**Step 3: 测试完整流程**

```
mcp__gdai-mcp__play_scene
projectPath: /Users/langtao/utoland
scenePath: res://scenes/ui/start_menu.tscn
```

Expected:
- 点击"开始游戏"跳转到角色选择
- 选择角色后跳转到武器选择

**Step 4: 查看调试输出**

```
mcp__gdai-mcp__get_godot_errors
```

Expected: 无错误

**Step 5: 停止场景**

```
mcp__gdai-mcp__stop_running_scene
```

**Step 6: Commit**

```bash
git add scripts/start_menu.gd
git commit -m "feat: 开始菜单跳转到角色选择界面"
```

---

## 任务 6：修改商店系统的速度升级

**Files:**
- Modify: `scripts/shop_manager.gd`

**Step 1: 查找速度升级逻辑**

```bash
grep -n "move_speed_mult" scripts/shop_manager.gd
```

**Step 2: 修改速度升级为固定值**

找到类似这样的代码：

```gdscript
# 之前
GameData.player_stats["move_speed_mult"] += 0.1
```

改为：

```gdscript
# 之后
GameData.player_stats["speed"] += 20.0
```

**Step 3: 更新商店显示文本**

如果有显示"移动速度 +10%"的文本，改为"移动速度 +20"

**Step 4: 验证修改**

```bash
grep -n "speed" scripts/shop_manager.gd | grep -v "attack_speed"
```

Expected: 显示修改后的速度升级逻辑

**Step 5: Commit**

```bash
git add scripts/shop_manager.gd
git commit -m "refactor: 商店速度升级改为固定值"
```

---

## 任务 7：完整流程测试

**Files:**
- Test: 完整游戏流程

**Step 1: 测试战士角色完整流程**

```
mcp__gdai-mcp__play_scene
projectPath: /Users/langtao/utoland
scenePath: res://scenes/ui/start_menu.tscn
```

操作流程：
1. 开始游戏 → 选择战士 → 选择武器
2. 布置塔 → 战斗 → 商店购买速度升级
3. 继续战斗至少 3 波

**Step 2: 查看调试输出**

```
mcp__gdai-mcp__get_godot_errors
```

Expected:
- 战士初始速度 180
- 购买速度升级后速度增加 20
- 无错误日志

**Step 3: 停止并测试游侠**

```
mcp__gdai-mcp__stop_running_scene
```

重复步骤 1-2，选择游侠角色

Expected:
- 游侠初始速度 250
- 速度明显快于战士

**Step 4: 停止并测试坦克**

```
mcp__gdai-mcp__stop_running_scene
```

重复步骤 1-2，选择坦克角色

Expected:
- 坦克初始速度 150
- 速度明显慢于战士
- 有生命回复效果

**Step 5: 记录测试结果**

创建测试报告：

```bash
echo "# 角色系统测试报告

## 战士
- 初始速度: 180 ✓
- 速度升级: +20 ✓
- 游戏流程: 正常 ✓

## 游侠
- 初始速度: 250 ✓
- 速度差异: 明显 ✓
- 游戏流程: 正常 ✓

## 坦克
- 初始速度: 150 ✓
- 生命回复: 有效 ✓
- 游戏流程: 正常 ✓
" > test_report.txt
```

**Step 6: Commit 测试报告**

```bash
git add test_report.txt
git commit -m "test: 角色系统完整流程测试通过"
```

---

## 任务 8：更新文档

**Files:**
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/GAME_DESIGN.md`
- Modify: `docs/CONFIGURATION.md`
- Modify: `CLAUDE.md`

**Step 1: 更新 ARCHITECTURE.md**

在"核心系统"部分添加角色系统说明：

```markdown
### 角色系统

**配置**: `GameConfig.CHARACTERS`
**状态**: `GameData.selected_character`, `GameData.init_character()`

角色提供基础属性（生命值、速度、伤害倍率等），通过 `init_character()` 初始化到 `player_stats`。商店升级在角色基础上叠加。

**当前角色**:
- 战士: 平衡型，高血量高伤害
- 游侠: 敏捷型，高速度高攻速
- 坦克: 肉盾型，超高血量自带回血
```

**Step 2: 更新 GAME_DESIGN.md**

在"游戏系统"部分添加角色系统：

```markdown
### 角色系统

玩家可以在游戏开始时选择角色，不同角色有不同的基础属性。

#### 角色列表

**战士**
- 生命值: 150
- 速度: 180
- 伤害倍率: 1.2x
- 定位: 平衡型，适合新手

**游侠**
- 生命值: 80
- 速度: 250
- 伤害倍率: 0.9x
- 攻速倍率: 1.1x
- 定位: 敏捷型，高风险高回报

**坦克**
- 生命值: 200
- 速度: 150
- 伤害倍率: 0.8x
- 生命回复: 1.0/5秒
- 定位: 肉盾型，容错率高
```

**Step 3: 更新 CONFIGURATION.md**

添加 CHARACTERS 配置说明：

```markdown
### CHARACTERS - 角色配置

定义可选角色及其基础属性。

**配置结构**:
```gdscript
const CHARACTERS = {
    "character_id": {
        "name": String,           # 显示名称
        "description": String,    # 角色描述
        "max_hp": float,          # 初始生命值
        "speed": float,           # 移动速度
        "damage_mult": float,     # 伤害倍率
        "attack_speed_mult": float, # 攻速倍率
        "move_speed_mult": float,   # 速度倍率（保留用于未来）
        "hp_regen": float         # 生命回复（每5秒）
    }
}
```

**当前角色**: warrior, ranger, tank
```

**Step 4: 更新 CLAUDE.md**

在"核心架构"部分添加角色系统：

```markdown
**角色系统**：
- `GameConfig.CHARACTERS` - 角色配置
- `GameData.selected_character` - 当前选择
- `GameData.init_character()` - 初始化角色属性
```

在"场景流程"中更新：

```
开始菜单 → 角色选择 → 武器选择 → 布置场景 → 战斗场景 → 商店 → ...
```

**Step 5: 验证文档更新**

```bash
grep -n "角色" docs/ARCHITECTURE.md docs/GAME_DESIGN.md docs/CONFIGURATION.md CLAUDE.md
```

Expected: 所有文档都包含角色系统相关内容

**Step 6: Commit**

```bash
git add docs/ARCHITECTURE.md docs/GAME_DESIGN.md docs/CONFIGURATION.md CLAUDE.md
git commit -m "docs: 更新文档添加角色系统说明"
```

---

## 任务 9：最终验证和清理

**Files:**
- Test: 所有功能

**Step 1: 完整回归测试**

测试以下场景：
1. 三个角色各玩一局完整游戏（10波）
2. 验证武器系统不受影响
3. 验证塔布置系统不受影响
4. 验证商店系统正常工作

**Step 2: 检查代码质量**

```bash
# 检查是否有硬编码的角色属性
grep -r "150.0\|180.0\|250.0" scripts/ --include="*.gd" | grep -v "game_config\|character_select"
```

Expected: 只在 game_config.gd 和 character_select.gd 中出现

**Step 3: 删除测试文件**

```bash
rm test_report.txt
git add test_report.txt
git commit -m "chore: 删除临时测试文件"
```

**Step 4: 创建最终总结**

```bash
echo "角色系统实施完成

✓ 添加 3 个角色（战士、游侠、坦克）
✓ 角色选择界面
✓ 属性系统重构（倍率 → 最终值）
✓ 商店系统调整
✓ 文档更新
✓ 完整测试通过

下一步：
- 添加角色图标
- 角色平衡调整
- 更多角色
" > IMPLEMENTATION_SUMMARY.md

git add IMPLEMENTATION_SUMMARY.md
git commit -m "docs: 角色系统实施总结"
```

---

## 验证清单

完成所有任务后，确认以下内容：

- [ ] `GameConfig.CHARACTERS` 配置正确
- [ ] `GameData.init_character()` 正常工作
- [ ] 角色选择界面功能完整
- [ ] 三个角色属性差异明显
- [ ] 商店升级正确应用
- [ ] 场景流程正确（开始菜单 → 角色选择 → 武器选择 → ...）
- [ ] 无错误日志
- [ ] 文档已更新
- [ ] 所有修改已提交

---

## 注意事项

1. **使用 MCP 工具测试**：每个任务完成后都要用 MCP 工具运行测试，不要依赖手动测试
2. **频繁提交**：每个任务完成后立即提交，保持提交历史清晰
3. **遵循规则**：参考 `.claude/rules/` 中的开发规范
4. **类型注解**：所有新代码必须使用类型注解
5. **配置驱动**：不要硬编码数值，从 GameConfig 读取
