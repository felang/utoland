# Bug 修复经验总结

## 2026-03-04: 塔布置系统 Bug 修复

### 问题描述
- Bug 1: 初始布置3个塔，只显示1个
- Bug 2: 波次间塔数据丢失

### 关键教训

#### 1. 优先使用 GDAI MCP 工具进行调试

**错误做法**:
```
1. 添加 print() 调试日志
2. 让用户手动运行游戏
3. 让用户复制粘贴控制台输出
4. 来回多次沟通
```

**正确做法**:
```
1. 使用 mcp__gdai-mcp__create_scene 创建测试场景
2. 编写自动化测试脚本模拟游戏流程
3. 使用 mcp__gdai-mcp__play_scene 运行测试
4. 使用 mcp__gdai-mcp__get_godot_errors 查看输出
5. 立即看到问题根因
```

**效果对比**:
- 手动测试: 需要用户参与，效率低，信息不完整
- 自动化测试: 完全自主，快速迭代，输出完整

#### 2. 通过测试发现真正的根因

**表面现象**: 只有第一个塔被识别

**通过测试发现的真相**:
```
步骤2: 手动添加3个射手塔到场景
  添加塔 1: 位置=(100.0, 100.0), 节点名称=TowerShooter
  添加塔 2: 位置=(200.0, 100.0), 节点名称=@StaticBody2D@3
  添加塔 3: 位置=(300.0, 100.0), 节点名称=@StaticBody2D@4
```

**根本原因**: Godot 自动重命名节点，导致基于节点名称的识别失败

**如果没有测试**: 可能会误以为是数据保存问题，走错方向

#### 3. 测试驱动的修复流程

**步骤**:
1. 创建测试脚本复现问题
2. 运行测试，确认问题存在
3. 分析测试输出，找到根因
4. 修改代码
5. 重新运行测试，验证修复
6. 清理测试文件

**优势**:
- 快速迭代（秒级反馈）
- 确保修复有效
- 避免引入新问题

### 技术要点

#### Godot 节点命名机制
- 同一场景多次实例化时，Godot 会自动重命名
- 第一个: `TowerShooter`
- 第二个: `@StaticBody2D@3`
- 第三个: `@StaticBody2D@4`

**解决方案**: 使用属性而非节点名称
```gdscript
# 错误
if tower.name.begins_with("TowerShooter"):
    tower_type = "shooter"

# 正确
if "tower_type" in tower:
    tower_type = tower.tower_type
```

#### 数据持久化模式
```gdscript
# placement.gd _ready()
for tower_data in GameData.tower_inventory:
    # 恢复已有的塔
    var tower = tower_scenes[tower_data["type"]].instantiate()
    tower.global_position = tower_data["position"]
    add_child(tower)

# placement.gd start_battle()
var current_towers = []
for tower in get_tree().get_nodes_in_group("towers"):
    # 收集所有塔（包括旧的和新的）
    current_towers.append({
        "type": tower.tower_type,
        "position": tower.global_position
    })
GameData.tower_inventory = current_towers
```

### 工具使用技巧

#### 创建简单的测试场景
```gdscript
extends Node

func _ready():
    print("测试开始")

    # 模拟游戏逻辑
    var tower_scene = load("res://scenes/towers/tower_shooter.tscn")
    for i in range(3):
        var tower = tower_scene.instantiate()
        tower.global_position = Vector2(100 + i * 100, 100)
        print("塔", i+1, "节点名称:", tower.name)

    print("测试完成")
    get_tree().quit()
```

#### 查看调试输出
```python
mcp__gdai-mcp__get_godot_errors(num_lines=100)
```

### 总结

**核心原则**:
1. **自动化优先**: 能用工具解决的不要手动
2. **测试驱动**: 先写测试，再修复
3. **深入分析**: 通过测试输出找到真正的根因
4. **快速迭代**: 利用自动化测试快速验证

**时间对比**:
- 传统方式: 可能需要数小时的来回沟通
- GDAI MCP 方式: 30分钟内定位并修复

**适用场景**:
- Godot 项目的任何 Bug 调试
- 需要查看运行时状态的问题
- 需要验证修复效果的场景
