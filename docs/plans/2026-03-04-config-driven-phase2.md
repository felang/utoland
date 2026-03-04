# 阶段 2：核心系统重构

**目标:** 重构玩家、敌人、塔系统，使其从 GameConfig 读取配置

**预计时间:** 60-90 分钟

---

## Task 3: 重构玩家系统

**Files:**
- Modify: `scripts/player.gd`

**Step 1: 备份当前玩家脚本**

```bash
cp scripts/player.gd scripts/player.gd.backup
```

**Step 2: 读取当前玩家脚本**

先查看当前实现，了解需要修改的部分。

**Step 3: 重构武器配置读取**

找到武器相关的硬编码部分，修改为从配置读取：

```gdscript
# 修改前（大约在 _ready() 函数中）
var fire_rate = 0.1
var damage = 10.0
# ... 等等

# 修改后
var weapon_data = GameConfig.WEAPONS[GameData.selected_weapon]
var fire_rate = weapon_data["fire_rate"]
var damage = weapon_data["damage"] * GameData.player_stats["damage_mult"]
var bullet_count = weapon_data["bullet_count"]
var bullet_speed = weapon_data["bullet_speed"]
```

**Step 4: 重构霰弹枪扩散角度**

找到霰弹枪发射逻辑（大约在射击函数中）：

```gdscript
# 修改前
if GameData.selected_weapon == "shotgun":
    var angles = [-7.5, -3.75, 0, 3.75, 7.5]
    # ...

# 修改后
if GameData.selected_weapon == "shotgun":
    var weapon_data = GameConfig.WEAPONS["shotgun"]
    var angles = weapon_data["spread_angles"]
    # ...
```

**Step 5: 重构玩家初始属性**

找到玩家初始化部分：

```gdscript
# 修改前
var max_hp = GameData.player_stats["max_hp"]
var current_hp = max_hp
var speed = 200.0

# 修改后
var max_hp = GameData.player_stats["max_hp"]
var current_hp = max_hp
var speed = GameConfig.PLAYER["initial_speed"] * GameData.player_stats["move_speed_mult"]
```

**Step 6: 重构生命回复间隔**

找到生命回复逻辑：

```gdscript
# 修改前
if hp_regen_timer >= 5.0:
    # ...

# 修改后
if hp_regen_timer >= GameConfig.PLAYER["hp_regen_interval"]:
    # ...
```

**Step 7: 修复生命回复计时器重置问题（已知问题 #2）**

在 `_ready()` 函数中添加：

```gdscript
func _ready():
    hp_regen_timer = 0.0  # 重置计时器
    # ... 其他初始化代码
```

**Step 8: 测试玩家系统**

运行游戏，测试：
- 选择不同武器，验证伤害和射速
- 霰弹枪扩散角度正确
- 玩家移动速度正常
- 生命回复功能正常

预期：所有功能正常工作

**Step 9: 提交**

```bash
git add scripts/player.gd
git commit -m "refactor: 玩家系统使用 GameConfig 配置"
```

---

## Task 4: 重构敌人系统

**Files:**
- Modify: `scripts/enemy.gd`
- Modify: `scripts/enemy_spawner.gd`

**Step 1: 为敌人添加类型属性**

在 `scripts/enemy.gd` 顶部添加：

```gdscript
extends CharacterBody2D

# 敌人类型（由生成器设置）
var enemy_type: String = "normal"

# ... 其他变量
```

**Step 2: 重构敌人属性初始化**

找到敌人初始化部分（`_ready()` 或变量声明）：

```gdscript
# 修改前
var hp = 30.0
var speed = 80.0
var damage = 10.0

# 修改后
var enemy_data = GameConfig.ENEMIES[enemy_type]
var hp = enemy_data["hp"]
var max_hp = enemy_data["hp"]
var speed = enemy_data["speed"]
var damage = enemy_data["damage"]
```

**Step 3: 重构金币掉落**

找到敌人死亡时的金币掉落逻辑：

```gdscript
# 修改前
var coin_amount = randi() % 4 + 2  # 2-5

# 修改后
var enemy_data = GameConfig.ENEMIES[enemy_type]
var coin_amount = randi_range(
    enemy_data["coin_drop_min"],
    enemy_data["coin_drop_max"]
)
```

**Step 4: 修改敌人生成器设置类型**

在 `scripts/enemy_spawner.gd` 中，找到敌人实例化部分：

```gdscript
# 修改前
var enemy = enemy_scene.instantiate()
add_child(enemy)

# 修改后
var enemy = enemy_scene.instantiate()
# 根据场景设置敌人类型
if enemy_scene.resource_path.contains("enemy_normal"):
    enemy.enemy_type = "normal"
elif enemy_scene.resource_path.contains("enemy_fast"):
    enemy.enemy_type = "fast"
elif enemy_scene.resource_path.contains("enemy_tank"):
    enemy.enemy_type = "tank"
add_child(enemy)
```

**Step 5: 测试敌人系统**

运行游戏，测试：
- 不同类型敌人的血量、速度正确
- 金币掉落数量符合配置
- 敌人伤害正确

预期：所有敌人类型功能正常

**Step 6: 提交**

```bash
git add scripts/enemy.gd scripts/enemy_spawner.gd
git commit -m "refactor: 敌人系统使用 GameConfig 配置"
```

---

## Task 5: 重构塔系统

**Files:**
- Modify: `scripts/tower_shooter.gd`
- Modify: `scripts/tower_wall.gd`
- Modify: `scripts/tower_slow.gd`

**Step 1: 重构射手塔**

在 `scripts/tower_shooter.gd` 中：

```gdscript
# 在顶部添加
var tower_type: String = "shooter"

# 修改属性初始化
func _ready():
    var tower_data = GameConfig.TOWERS[tower_type]
    hp = tower_data["hp"]
    max_hp = tower_data["hp"]
    damage = tower_data["damage"] * GameData.player_stats["tower_mult"]
    fire_rate = tower_data["fire_rate"]
    attack_range = tower_data["range"]
    # ... 其他初始化代码
```

**Step 2: 重构墙塔**

在 `scripts/tower_wall.gd` 中：

```gdscript
# 在顶部添加
var tower_type: String = "wall"

# 修改属性初始化
func _ready():
    var tower_data = GameConfig.TOWERS[tower_type]
    hp = tower_data["hp"]
    max_hp = tower_data["hp"]
    # ... 其他初始化代码
```

**Step 3: 重构减速塔**

在 `scripts/tower_slow.gd` 中：

```gdscript
# 在顶部添加
var tower_type: String = "slow"

# 修改属性初始化
func _ready():
    var tower_data = GameConfig.TOWERS[tower_type]
    hp = tower_data["hp"]
    max_hp = tower_data["hp"]
    slow_range = tower_data["range"]
    slow_percent = tower_data["slow_percent"]
    # ... 其他初始化代码
```

**Step 4: 修复塔类型识别问题（已知问题 #4）**

在 `scripts/placement.gd` 中，找到塔类型识别部分：

```gdscript
# 修改前
if tower.name.begins_with("TowerShooter"):
    tower_type = "shooter"
elif tower.name.begins_with("TowerWall"):
    tower_type = "wall"
# ...

# 修改后
if tower.has_method("get") and "tower_type" in tower:
    tower_type = tower.tower_type
else:
    # 降级方案：通过名称判断
    if tower.name.begins_with("TowerShooter"):
        tower_type = "shooter"
    elif tower.name.begins_with("TowerWall"):
        tower_type = "wall"
    elif tower.name.begins_with("TowerSlow"):
        tower_type = "slow"
```

**Step 5: 测试塔系统**

运行游戏，测试：
- 布置不同类型的塔
- 验证塔的血量、伤害、射程
- 验证塔的保存和恢复功能

预期：所有塔功能正常

**Step 6: 提交**

```bash
git add scripts/tower_shooter.gd scripts/tower_wall.gd scripts/tower_slow.gd scripts/placement.gd
git commit -m "refactor: 塔系统使用 GameConfig 配置并修复类型识别"
```

---

## Task 6: 重构波次系统

**Files:**
- Modify: `scripts/wave_manager.gd`

**Step 1: 重构波次配置读取**

在 `scripts/wave_manager.gd` 中：

```gdscript
# 修改前
var total_waves = 10
var wave_duration = 45  # 硬编码

# 修改后
var total_waves = GameConfig.WAVES["total_waves"]
var current_wave_config = GameConfig.WAVES["wave_configs"][current_wave - 1]
var wave_duration = current_wave_config["duration"]
var spawn_interval = current_wave_config["spawn_interval"]
```

**Step 2: 重构敌人生成逻辑**

找到敌人生成部分：

```gdscript
# 修改后应该根据波次配置生成对应类型的敌人
func spawn_enemy():
    var current_wave_config = GameConfig.WAVES["wave_configs"][GameData.current_wave - 1]
    var enemy_types = current_wave_config["enemy_types"]

    # 随机选择一个敌人类型
    var enemy_type = enemy_types[randi() % enemy_types.size()]

    # 根据类型加载对应场景
    var enemy_scene
    if enemy_type == "normal":
        enemy_scene = preload("res://scenes/enemies/enemy_normal.tscn")
    elif enemy_type == "fast":
        enemy_scene = preload("res://scenes/enemies/enemy_fast.tscn")
    elif enemy_type == "tank":
        enemy_scene = preload("res://scenes/enemies/enemy_tank.tscn")

    # ... 生成敌人
```

**Step 3: 测试波次系统**

运行游戏，测试：
- 波次时长符合配置
- 敌人生成间隔符合配置
- 不同波次生成正确的敌人类型

预期：波次系统按配置运行

**Step 4: 提交**

```bash
git add scripts/wave_manager.gd
git commit -m "refactor: 波次系统使用 GameConfig 配置"
```

---

## Task 7: 重构商店系统

**Files:**
- Modify: `scripts/shop_manager.gd`

**Step 1: 重构商店价格**

在 `scripts/shop_manager.gd` 中：

```gdscript
# 修改前
var passive_price = randi() % 16 + 15  # 15-30
var tower_price = randi() % 6 + 25  # 25-30

# 修改后
var passive_price = randi_range(
    GameConfig.SHOP["passive_price_min"],
    GameConfig.SHOP["passive_price_max"]
)
var tower_price = randi_range(
    GameConfig.TOWERS[tower_type]["shop_price_min"],
    GameConfig.TOWERS[tower_type]["shop_price_max"]
)
```

**Step 2: 重构刷新和治疗价格**

```gdscript
# 修改前
var refresh_cost = 10
var heal_price = 12
var heal_amount = 50

# 修改后
var refresh_cost = GameConfig.SHOP["refresh_cost"]
var heal_price = GameConfig.SHOP["heal_price"]
var heal_amount = GameConfig.SHOP["heal_amount"]
```

**Step 3: 测试商店系统**

运行游戏，测试：
- 商店物品价格符合配置
- 刷新功能正常
- 购买功能正常

预期：商店系统正常工作

**Step 4: 提交**

```bash
git add scripts/shop_manager.gd
git commit -m "refactor: 商店系统使用 GameConfig 配置"
```

---

## Task 8: 重构 GameData 初始值

**Files:**
- Modify: `scripts/game_data.gd`

**Step 1: 使用配置初始化玩家数据**

```gdscript
# 修改前
var coins: int = 100

# 修改后
var coins: int = GameConfig.PLAYER["initial_coins"]

# 在 reset() 函数中也要修改
func reset():
    # ...
    coins = GameConfig.PLAYER["initial_coins"]
    # ...
```

**Step 2: 测试 GameData**

运行游戏，验证初始金币数量正确。

**Step 3: 提交**

```bash
git add scripts/game_data.gd
git commit -m "refactor: GameData 使用 GameConfig 初始值"
```

---

## 阶段 2 验收

- [ ] 玩家系统从配置读取武器、属性数据
- [ ] 敌人系统从配置读取血量、速度、金币掉落
- [ ] 塔系统从配置读取属性，类型识别改进
- [ ] 波次系统从配置读取时长和生成间隔
- [ ] 商店系统从配置读取价格
- [ ] 游戏可以正常运行，所有功能正常
- [ ] 提交 6 次
- [ ] 无硬编码的游戏数值

**下一步:** 执行阶段 3 - 调试工具开发
