# 开发指南

本文档提供 Utoland 项目的开发环境设置、代码规范和常见开发任务指南。

## 目录

- [开发环境设置](#开发环境设置)
- [代码规范](#代码规范)
- [常见开发任务](#常见开发任务)
- [调试技巧](#调试技巧)
- [测试流程](#测试流程)

---

## 开发环境设置

### 必需工具

1. **Godot 4.6**
   - 下载地址: https://godotengine.org/download
   - 版本要求: 4.6.stable.official

2. **Git**
   - 用于版本控制
   - 建议使用 Git LFS 管理大文件

3. **代码编辑器**（可选）
   - VS Code + Godot Tools 插件
   - 或使用 Godot 内置编辑器

### 项目设置

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd utoland
   ```

2. **打开项目**
   - 启动 Godot 4.6
   - 点击"导入"
   - 选择项目目录中的 `project.godot`

3. **验证配置**
   - 检查 AutoLoad 配置（项目设置 → AutoLoad）
   - 确认三个单例已注册：
     - GameData
     - GameConfig
     - GDAIMCPRuntime

4. **运行测试**
   - 按 `F5` 运行游戏
   - 验证开始菜单正常显示

### GDAI MCP 插件

项目集成了 GDAI MCP 插件，提供 AI 辅助开发功能。

**插件位置**: `addons/gdai-mcp-plugin-godot/`

**注意事项**:
- 插件为商业插件，不应提交到公共仓库
- 插件需要原生库支持（已包含在 `bin/` 目录）

---

## 代码规范

### GDScript 风格

**命名约定**:
```gdscript
# 变量和函数：snake_case
var player_health: float = 100.0
func calculate_damage(base_damage: float) -> float:

# 常量：UPPER_SNAKE_CASE
const MAX_ENEMIES = 100
const SPAWN_INTERVAL = 1.5

# 类名：PascalCase
class_name EnemySpawner

# 信号：snake_case
signal enemy_died(enemy_type: String)

# 私有变量：_前缀
var _internal_state: int = 0
```

**类型注解**:
```gdscript
# 始终使用类型注解
var speed: float = 200.0
var enemies: Array[Node] = []

func get_damage() -> float:
    return base_damage * multiplier
```

**代码组织**:
```gdscript
extends Node2D

# 1. 信号
signal health_changed(new_health: float)

# 2. 常量
const MAX_HP = 100.0

# 3. @export 变量
@export var speed: float = 200.0

# 4. 公共变量
var current_hp: float

# 5. 私有变量
var _timer: float = 0.0

# 6. @onready 变量
@onready var sprite = $Sprite2D

# 7. 生命周期函数
func _ready():
    pass

func _process(delta):
    pass

# 8. 公共方法
func take_damage(amount: float):
    pass

# 9. 私有方法
func _update_health_bar():
    pass
```

### 配置优先原则

**禁止硬编码数值**:
```gdscript
# ❌ 错误
var damage = 10.0
var fire_rate = 0.1

# ✅ 正确
var weapon_config = GameConfig.WEAPONS[weapon_type]
var damage = weapon_config["damage"]
var fire_rate = weapon_config["fire_rate"]
```

**使用 GameData 管理状态**:
```gdscript
# ❌ 错误
var coins = 100

# ✅ 正确
GameData.coins += 10
```

### 注释规范

**函数注释**:
```gdscript
## 计算最终伤害值
##
## 参数:
##   base_damage: 基础伤害
##   multiplier: 伤害倍率
##
## 返回:
##   最终伤害值
func calculate_damage(base_damage: float, multiplier: float) -> float:
    return base_damage * multiplier
```

**关键逻辑注释**:
```gdscript
# 波次结束后需要 +1，因为 current_wave 从 1 开始
if GameData.current_wave > GameConfig.WAVES["total_waves"]:
    # 通关
```

---

## 常见开发任务

### 添加新武器

**步骤**:

1. **在 GameConfig 中添加配置**
   ```gdscript
   # game_config.gd
   const WEAPONS = {
       # ... 现有武器
       "laser": {
           "name": "激光枪",
           "fire_rate": 0.05,
           "damage": 5.0,
           "bullet_count": 1,
           "bullet_speed": 1000
       }
   }
   ```

2. **更新武器选择界面**
   ```gdscript
   # scripts/weapon_select.gd
   func _on_laser_button_pressed():
       GameData.selected_weapon = "laser"
       get_tree().change_scene_to_file("res://scenes/placement.tscn")
   ```

3. **添加武器按钮到场景**
   - 打开 `scenes/ui/weapon_select.tscn`
   - 复制现有武器按钮
   - 修改文本和信号连接

4. **测试**
   - 运行游戏
   - 选择新武器
   - 验证伤害和射速

### 添加新敌人

**步骤**:

1. **在 GameConfig 中添加配置**
   ```gdscript
   # game_config.gd
   const ENEMIES = {
       # ... 现有敌人
       "boss": {
           "name": "Boss",
           "hp": 500.0,
           "speed": 80.0,
           "damage": 50.0,
           "coin_drop_min": 20,
           "coin_drop_max": 30
       }
   }
   ```

2. **创建敌人场景**
   - 复制 `scenes/enemies/enemy_normal.tscn`
   - 重命名为 `enemy_boss.tscn`
   - 修改外观（Sprite2D、CollisionShape2D）

3. **更新敌人脚本**
   ```gdscript
   # scenes/enemies/enemy_boss.tscn 附加的脚本
   extends "res://scripts/enemy.gd"

   func _ready():
       enemy_type = "boss"
       super._ready()
   ```

4. **添加到波次配置**
   ```gdscript
   # game_config.gd
   const WAVES = {
       "wave_configs": [
           # ...
           {
               "duration": 60,
               "spawn_interval": 2.0,
               "enemy_types": ["normal", "fast", "tank", "boss"]
           }
       ]
   }
   ```

5. **更新敌人生成器**
   ```gdscript
   # scripts/enemy_spawner.gd
   var enemy_scenes = {
       "normal": preload("res://scenes/enemies/enemy_normal.tscn"),
       "fast": preload("res://scenes/enemies/enemy_fast.tscn"),
       "tank": preload("res://scenes/enemies/enemy_tank.tscn"),
       "boss": preload("res://scenes/enemies/enemy_boss.tscn")
   }
   ```

### 添加新塔

**步骤**:

1. **在 GameConfig 中添加配置**
   ```gdscript
   # game_config.gd
   const TOWERS = {
       # ... 现有塔
       "fire": {
           "name": "火焰塔",
           "hp": 100.0,
           "damage": 5.0,
           "fire_rate": 0.5,
           "range": 250.0,
           "shop_price_min": 40,
           "shop_price_max": 50
       }
   }
   ```

2. **创建塔场景**
   - 复制 `scenes/towers/tower_shooter.tscn`
   - 重命名为 `tower_fire.tscn`
   - 修改外观

3. **创建塔脚本**
   ```gdscript
   # scripts/tower_fire.gd
   extends "res://scripts/tower.gd"

   var damage: float
   var fire_rate: float
   var range: float
   var fire_timer: float = 0.0

   func _ready():
       tower_type = "fire"
       var config = GameConfig.TOWERS["fire"]
       max_hp = config["hp"]
       current_hp = max_hp
       damage = config["damage"]
       fire_rate = config["fire_rate"]
       range = config["range"]

   func _process(delta):
       fire_timer += delta
       if fire_timer >= fire_rate:
           fire_timer = 0.0
           attack_enemies()

   func attack_enemies():
       var enemies = get_tree().get_nodes_in_group("enemies")
       for enemy in enemies:
           if global_position.distance_to(enemy.global_position) <= range:
               enemy.take_damage(damage)
   ```

4. **更新布置系统**
   ```gdscript
   # scripts/placement.gd
   var tower_scenes = {
       "shooter": preload("res://scenes/towers/tower_shooter.tscn"),
       "wall": preload("res://scenes/towers/tower_wall.tscn"),
       "slow": preload("res://scenes/towers/tower_slow.tscn"),
       "fire": preload("res://scenes/towers/tower_fire.tscn")
   }
   ```

5. **更新商店系统**
   - 商店会自动从 GameConfig.TOWERS 读取配置
   - 无需额外修改

### 调整游戏难度

**降低难度**:
```gdscript
# game_config.gd

# 1. 增加初始资源
const PLAYER = {
    "initial_hp": 120.0,      # 100 → 120
    "initial_coins": 150,     # 100 → 150
    # ...
}

# 2. 降低敌人强度
const ENEMIES = {
    "normal": {
        "hp": 40.0,           # 50 → 40
        "damage": 8.0,        # 10 → 8
        # ...
    }
}

# 3. 延长波次时长
const WAVES = {
    "wave_configs": [
        {
            "duration": 60,   # 45 → 60
            "spawn_interval": 2.0,  # 1.5 → 2.0
            # ...
        }
    ]
}
```

**提高难度**:
```gdscript
# 1. 减少初始资源
const PLAYER = {
    "initial_hp": 80.0,
    "initial_coins": 80,
}

# 2. 增强敌人
const ENEMIES = {
    "normal": {
        "hp": 60.0,
        "damage": 12.0,
        "speed": 120.0,
    }
}

# 3. 加快节奏
const WAVES = {
    "wave_configs": [
        {
            "duration": 40,
            "spawn_interval": 1.0,
        }
    ]
}
```

---

## 调试技巧

### 使用 GDAI MCP 工具

GDAI MCP 提供了强大的调试工具，可以自动化测试和调试。

**运行项目**:
```python
mcp__godot__run_project(
    projectPath="/Users/langtao/utoland"
)
```

**获取调试输出**:
```python
mcp__godot__get_debug_output()
```

**创建测试场景**:
```python
mcp__godot__create_scene(
    projectPath="/Users/langtao/utoland",
    scenePath="res://test_scene.tscn",
    rootNodeType="Node2D"
)
```

### 调试最佳实践

**1. 使用 print 调试**:
```gdscript
# 调试变量值
print("当前生命值: ", current_hp)

# 调试函数调用
print("take_damage 被调用，伤害: ", amount)

# 调试条件分支
if condition:
    print("条件为真")
else:
    print("条件为假")
```

**2. 使用断言**:
```gdscript
# 确保变量在预期范围内
assert(current_hp >= 0, "生命值不能为负")
assert(coins >= 0, "金币不能为负")
```

**3. 使用调试绘制**:
```gdscript
# 绘制攻击范围
func _draw():
    if GameConfig.DEBUG_MODE:
        draw_circle(Vector2.ZERO, range, Color(1, 0, 0, 0.2))
```

**4. 创建自动化测试脚本**:
```gdscript
# test_tower_placement.gd
extends Node

func _ready():
    print("=== 测试开始 ===")

    # 测试1: 布置3个塔
    test_place_three_towers()

    # 测试2: 保存和恢复塔
    test_save_and_restore_towers()

    print("=== 测试完成 ===")
    get_tree().quit()

func test_place_three_towers():
    print("测试1: 布置3个塔")
    var tower_scene = load("res://scenes/towers/tower_shooter.tscn")

    for i in range(3):
        var tower = tower_scene.instantiate()
        tower.global_position = Vector2(100 + i * 100, 100)
        add_child(tower)

    var towers = get_tree().get_nodes_in_group("towers")
    assert(towers.size() == 3, "应该有3个塔")
    print("✅ 测试1通过")
```

### 常见问题排查

**问题: 塔不攻击敌人**
- 检查塔的 `range` 配置
- 检查敌人是否在 "enemies" 组中
- 检查 `_process` 函数是否正常调用

**问题: 场景切换后数据丢失**
- 确认数据保存到 `GameData` 单例
- 检查场景 `_ready()` 是否恢复数据
- 使用 `print` 调试数据流

**问题: 配置修改不生效**
- 确认修改的是 `game_config.gd`
- 重启 Godot 编辑器
- 检查代码是否正确读取配置

---

## 测试流程

### 功能测试

**完整游戏流程测试**:
1. 启动游戏
2. 选择武器
3. 布置初始塔
4. 完成第1波战斗
5. 进入商店购买
6. 追加布置塔
7. 完成第2-10波
8. 验证胜利/失败结算

**单系统测试**:
- 武器系统: 测试每种武器的伤害和射速
- 敌人系统: 测试每种敌人的行为
- 塔系统: 测试每种塔的功能
- 商店系统: 测试购买和刷新

### 平衡测试

**数值验证**:
```gdscript
# 计算武器 DPS
var rifle_dps = 10.0 / 0.1  # 100
var shotgun_dps = (6.0 * 5) / 0.6  # 50
var sniper_dps = 30.0 / 1.0  # 30

print("步枪 DPS: ", rifle_dps)
print("霰弹枪 DPS: ", shotgun_dps)
print("狙击枪 DPS: ", sniper_dps)
```

**难度测试**:
- 使用不同武器通关
- 使用不同策略通关
- 记录通关时间和剩余生命

### 性能测试

**同屏敌人数量**:
```gdscript
func _process(delta):
    var enemy_count = get_tree().get_nodes_in_group("enemies").size()
    if enemy_count > 100:
        print("警告: 敌人数量过多 ", enemy_count)
```

**帧率监控**:
- 按 `F3` 显示 FPS
- 目标: 保持 60 FPS
- 如果低于 60，考虑优化

---

## 版本控制

### Git 工作流

**提交规范**:
```bash
# 功能添加
git commit -m "feat: 添加激光枪武器"

# Bug 修复
git commit -m "fix: 修复塔布置重叠问题"

# 重构
git commit -m "refactor: 优化敌人生成逻辑"

# 文档
git commit -m "docs: 更新开发指南"

# 配置调整
git commit -m "config: 调整武器平衡"
```

**分支策略**:
- `main`: 稳定版本
- `dev`: 开发分支
- `feature/*`: 功能分支
- `fix/*`: 修复分支

### 忽略文件

确保 `.gitignore` 包含：
```
.godot/
*.import
*.translation
addons/gdai-mcp-plugin-godot/
```

---

## 发布流程

### 构建游戏

1. **配置导出预设**
   - 项目 → 导出
   - 添加目标平台（Windows/Mac/Linux）

2. **导出游戏**
   - 选择导出预设
   - 点击"导出项目"
   - 选择输出目录

3. **测试构建**
   - 运行导出的可执行文件
   - 验证所有功能正常

### 版本号管理

在 `project.godot` 中更新版本号：
```ini
[application]
config/version="0.3.1"
```

---

## 资源

### 官方文档
- Godot 文档: https://docs.godotengine.org/
- GDScript 参考: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/

### 社区资源
- Godot 论坛: https://forum.godotengine.org/
- Godot Discord: https://discord.gg/godotengine

### 项目文档
- [系统架构](ARCHITECTURE.md)
- [游戏设计](GAME_DESIGN.md)
- [配置系统](CONFIGURATION.md)
