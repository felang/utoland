# 修复塔布置系统 Bug 实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标**: 修复两个关键的塔布置 Bug：(1) 初始布置的多个塔在进入游戏时只显示一个；(2) 波次间商店购买后的布置阶段重置了已有的塔

**架构**: 问题根源在于 `main.gd` 在恢复塔后立即清空 `tower_inventory`，以及 `placement.gd` 在开始战斗时重置 `tower_inventory` 而不是追加新塔

**技术栈**: Godot 4.6, GDScript

---

## 问题分析

### Bug 1: 初始布置多个塔只显示一个

**根本原因**:
- `placement.gd:106` 在开始战斗时执行 `GameData.tower_inventory = []`，清空了所有已布置的塔
- 用户在初始布置阶段放置了两个射手塔
- 点击"开始战斗"后，`start_battle()` 重新扫描场景中的塔并保存到 `tower_inventory`
- 但由于某种原因（可能是节点名称问题或扫描时机问题），只保存了一个塔的数据
- 进入 `main.tscn` 后，`main.gd:5-20` 只恢复了一个塔

**相关代码**:
- `scripts/placement.gd:103-121` - `start_battle()` 函数
- `scripts/main.gd:3-23` - 塔恢复逻辑

### Bug 2: 波次间布置重置已有塔

**根本原因**:
- 第一波战斗结束后，进入商店购买塔
- 商店将购买的塔类型保存到 `GameData.purchased_towers`
- 进入布置场景 `placement.tscn`
- `placement.gd:106` 执行 `GameData.tower_inventory = []`，**清空了之前所有已布置的塔**
- 用户只能看到空场景，之前布置的塔全部消失

**相关代码**:
- `scripts/placement.gd:103-121` - `start_battle()` 函数
- `scripts/main.gd:3-23` - 塔恢复逻辑

---

## 解决方案

### 核心修复策略

1. **修改 `main.gd`**: 恢复塔后**不要清空** `tower_inventory`，保留已布置的塔数据
2. **修改 `placement.gd`**:
   - 在 `_ready()` 中恢复之前布置的塔（从 `tower_inventory` 读取）
   - 在 `start_battle()` 中**追加**新布置的塔，而不是重置整个列表

### 数据流修正

**修正前**:
```
布置场景 → 保存塔到 tower_inventory → 战斗场景 → 恢复塔 → 清空 tower_inventory
→ 商店 → 布置场景 → 重置 tower_inventory = [] (丢失所有塔!)
```

**修正后**:
```
布置场景 → 保存塔到 tower_inventory → 战斗场景 → 恢复塔 → 保留 tower_inventory
→ 商店 → 布置场景 → 恢复已有塔 + 追加新塔 → 战斗场景 → 恢复所有塔
```

---

## 实施任务

### Task 1: 修复 main.gd 的塔恢复逻辑

**文件**:
- 修改: `scripts/main.gd:3-23`

**步骤 1: 移除清空 tower_inventory 的代码**

当前代码在恢复塔后立即清空列表，导致数据丢失。

修改 `scripts/main.gd`:

```gdscript
extends Node2D

func _ready():
	# 恢复布置的塔
	for tower_data in GameData.tower_inventory:
		var tower_type = tower_data["type"]
		var tower_pos = tower_data["position"]

		var tower_scene = null
		if tower_type == "shooter":
			tower_scene = preload("res://scenes/towers/tower_shooter.tscn")
		elif tower_type == "wall":
			tower_scene = preload("res://scenes/towers/tower_wall.tscn")
		elif tower_type == "slow":
			tower_scene = preload("res://scenes/towers/tower_slow.tscn")

		if tower_scene:
			var tower = tower_scene.instantiate()
			tower.global_position = tower_pos
			add_child(tower)

	# 不再清空 tower_inventory，保留已布置的塔数据供下次布置场景使用
```

**步骤 2: 验证修改**

手动检查代码：
- 确认删除了 `GameData.tower_inventory.clear()` 这一行
- 确认添加了注释说明为什么不清空

**步骤 3: 提交**

```bash
git add scripts/main.gd
git commit -m "fix: 保留 tower_inventory 数据，避免波次间丢失已布置的塔"
```

---

### Task 2: 修复 placement.gd 的塔保存逻辑

**文件**:
- 修改: `scripts/placement.gd:17-29, 103-121`

**步骤 1: 在 _ready() 中恢复已有的塔**

在布置场景启动时，需要恢复之前已经布置的塔，让玩家看到它们。

修改 `scripts/placement.gd` 的 `_ready()` 函数：

```gdscript
func _ready():
	# 恢复之前布置的塔
	for tower_data in GameData.tower_inventory:
		var tower_type = tower_data["type"]
		var tower_pos = tower_data["position"]

		if tower_scenes.has(tower_type):
			var tower = tower_scenes[tower_type].instantiate()
			tower.global_position = tower_pos
			tower.add_to_group("towers")
			add_child(tower)

	# 将商店购买的塔添加到金币中（作为可用资源）
	for tower_type in GameData.purchased_towers:
		GameData.coins += tower_costs[tower_type]
	GameData.purchased_towers.clear()

	# 连接按钮信号
	$UI/TowerButtons/ShooterButton.pressed.connect(func(): select_tower("shooter"))
	$UI/TowerButtons/WallButton.pressed.connect(func(): select_tower("wall"))
	$UI/TowerButtons/SlowButton.pressed.connect(func(): select_tower("slow"))
	$UI/StartBattleButton.pressed.connect(start_battle)

	update_ui()
```

**步骤 2: 修改 start_battle() 为追加模式**

当前代码重置 `tower_inventory`，改为只更新新布置的塔。

修改 `scripts/placement.gd` 的 `start_battle()` 函数：

```gdscript
func start_battle():
	# 收集场景中所有塔的当前位置
	var towers = get_tree().get_nodes_in_group("towers")
	var current_towers = []

	for tower in towers:
		var tower_type = ""
		if tower.name.begins_with("TowerShooter"):
			tower_type = "shooter"
		elif tower.name.begins_with("TowerWall"):
			tower_type = "wall"
		elif tower.name.begins_with("TowerSlow"):
			tower_type = "slow"

		if tower_type != "":
			current_towers.append({
				"type": tower_type,
				"position": tower.global_position
			})

	# 更新 tower_inventory 为当前所有塔（包括之前的和新布置的）
	GameData.tower_inventory = current_towers

	get_tree().change_scene_to_file("res://scenes/main.tscn")
```

**步骤 3: 验证修改**

手动检查代码：
- 确认 `_ready()` 中添加了恢复塔的逻辑
- 确认 `start_battle()` 中收集所有塔而不是重置列表
- 确认逻辑正确处理了塔的类型识别

**步骤 4: 提交**

```bash
git add scripts/placement.gd
git commit -m "fix: 布置场景恢复已有塔并追加新塔，避免重置"
```

---

### Task 3: 手动测试 Bug 1 - 初始布置多个塔

**步骤 1: 启动游戏并测试初始布置**

1. 运行游戏
2. 选择武器（任意）
3. 在初始布置场景放置 2-3 个射手塔
4. 点击"开始战斗"
5. 检查战斗场景中是否显示了所有布置的塔

**预期结果**: 所有初始布置的塔都应该出现在战斗场景中

**步骤 2: 记录测试结果**

如果通过，继续下一个测试。
如果失败，记录问题并分析原因。

---

### Task 4: 手动测试 Bug 2 - 波次间布置保留已有塔

**步骤 1: 测试波次间塔的保留**

1. 继续上一个测试的游戏进度
2. 完成第一波战斗
3. 进入商店，购买一个新塔（如果金币足够）
4. 进入布置场景
5. 检查之前布置的塔是否仍然存在

**预期结果**: 之前布置的所有塔都应该显示在布置场景中

**步骤 2: 测试新塔布置**

1. 在布置场景中放置新购买的塔
2. 点击"开始战斗"
3. 检查战斗场景中是否同时显示了旧塔和新塔

**预期结果**: 所有塔（旧的和新的）都应该出现在战斗场景中

**步骤 3: 记录测试结果**

如果通过，Bug 修复成功。
如果失败，记录问题并分析原因。

---

### Task 5: 完整游戏流程测试

**步骤 1: 完整通关测试**

1. 从开始菜单开始新游戏
2. 选择武器
3. 初始布置 2-3 个塔
4. 完成第 1-3 波战斗
5. 每波之间在商店购买塔并布置
6. 验证每次进入战斗场景时，所有塔都正确显示

**预期结果**:
- 每波战斗开始时，所有之前布置的塔都存在
- 新布置的塔正确添加到场景中
- 塔的位置和类型都正确

**步骤 2: 边界情况测试**

测试以下场景：
1. 初始布置 0 个塔（直接开始战斗）
2. 商店不购买塔（直接进入布置场景）
3. 布置场景不放置新塔（直接开始战斗）

**预期结果**: 所有边界情况都应该正常工作，不崩溃

**步骤 3: 记录测试结果**

如果所有测试通过，修复完成。
如果有问题，记录并分析。

---

### Task 6: 更新已知问题文档

**文件**:
- 修改: `docs/known-issues.md`

**步骤 1: 添加已修复问题记录**

在 `docs/known-issues.md` 的开头添加"已修复问题"部分：

```markdown
# 已知问题清单

**最后更新**: 2026-03-04
**项目**: Utoland
**版本**: MVP v0.3.1

---

## 已修复问题

### 1. 初始布置多个塔只显示一个 ✅
**修复日期**: 2026-03-04
**优先级**: Critical

**问题描述**:
在初始布置场景放置多个塔后，进入战斗场景时只显示一个塔。

**根本原因**:
`placement.gd` 的 `start_battle()` 函数在保存塔数据时存在逻辑错误，导致只保存了部分塔的信息。

**修复方案**:
修改 `start_battle()` 函数，正确收集场景中所有塔的数据并保存到 `GameData.tower_inventory`。

**相关提交**: [提交哈希]

---

### 2. 波次间布置重置已有塔 ✅
**修复日期**: 2026-03-04
**优先级**: Critical

**问题描述**:
完成第一波战斗后，在商店购买塔并进入布置场景时，之前布置的所有塔都消失了。

**根本原因**:
1. `main.gd` 在恢复塔后清空了 `tower_inventory`
2. `placement.gd` 在开始战斗时重置 `tower_inventory` 而不是追加新塔

**修复方案**:
1. 移除 `main.gd` 中清空 `tower_inventory` 的代码
2. 在 `placement.gd` 的 `_ready()` 中恢复已有的塔
3. 修改 `start_battle()` 为收集所有塔而不是重置列表

**相关提交**: [提交哈希]

---

## Important 级别
```

**步骤 2: 提交文档更新**

```bash
git add docs/known-issues.md
git commit -m "docs: 记录已修复的塔布置 Bug"
```

---

### Task 7: 更新项目状态文档

**文件**:
- 修改: `docs/project-status.md`

**步骤 1: 更新版本号和修复记录**

修改 `docs/project-status.md` 的开头：

```markdown
# Utoland 项目状态

**最后更新**: 2026-03-04
**当前版本**: MVP v0.3.1
**项目类型**: 2D 塔防 + 生存射击游戏

---

## 最近更新

### v0.3.1 (2026-03-04)
**修复内容**:
- ✅ 修复初始布置多个塔只显示一个的问题
- ✅ 修复波次间布置重置已有塔的问题

**影响**:
- 塔布置系统现在正确保留和恢复所有已布置的塔
- 玩家可以在多个波次间累积建造防御塔
- 游戏核心循环现在完全可玩

---
```

**步骤 2: 提交文档更新**

```bash
git add docs/project-status.md
git commit -m "docs: 更新项目状态到 v0.3.1"
```

---

## 测试检查清单

- [ ] Bug 1: 初始布置 2-3 个塔，进入战斗后所有塔都显示
- [ ] Bug 2: 第一波后购买塔，布置场景显示之前的塔
- [ ] Bug 2: 布置新塔后，战斗场景显示所有塔（旧+新）
- [ ] 边界: 初始不布置塔，游戏正常运行
- [ ] 边界: 商店不购买塔，布置场景正常
- [ ] 边界: 布置场景不放新塔，战斗场景正常
- [ ] 完整: 完成 3 波战斗，每波都正确显示所有塔

---

## 风险评估

**低风险**:
- 修改仅涉及塔的保存和恢复逻辑
- 不影响其他游戏系统
- 修改点明确，易于回滚

**潜在问题**:
- 如果塔的节点名称不符合预期（不以 "TowerShooter" 等开头），可能无法正确识别类型
- 建议后续改进：在塔脚本中添加 `tower_type` 属性（见 `known-issues.md` #4）

---

## 完成标准

1. ✅ 所有代码修改已提交
2. ✅ 手动测试通过所有检查清单项
3. ✅ 文档已更新
4. ✅ 无新引入的 Bug
5. ✅ 游戏可以正常完成多波战斗

---

## 相关文档

- `docs/known-issues.md` - 已知问题清单
- `docs/project-status.md` - 项目状态
- `scripts/main.gd` - 主场景控制器
- `scripts/placement.gd` - 布置系统
- `scripts/game_data.gd` - 全局游戏数据
