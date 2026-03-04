# 系统架构文档

本文档描述 Utoland 项目的技术架构、核心系统和数据流。

## 目录

- [场景结构](#场景结构)
- [脚本组织](#脚本组织)
- [核心系统](#核心系统)
- [数据流](#数据流)
- [关键设计决策](#关键设计决策)

---

## 场景结构

### 场景层次

```
scenes/
├── ui/
│   ├── start_menu.tscn          # 开始菜单（入口场景）
│   ├── weapon_select.tscn       # 武器选择界面
│   ├── shop.tscn                # 商店界面
│   └── result.tscn              # 结算界面
├── placement.tscn               # 塔布置场景
├── main.tscn                    # 主战斗场景
├── player.tscn                  # 玩家实体
├── bullet.tscn                  # 子弹实体
├── coin.tscn                    # 金币实体
├── map_boundary.tscn            # 地图边界
├── enemies/
│   ├── enemy_normal.tscn        # 普通敌人
│   ├── enemy_fast.tscn          # 快速敌人
│   └── enemy_tank.tscn          # 坦克敌人
└── towers/
    ├── tower_shooter.tscn       # 射手塔
    ├── tower_wall.tscn          # 墙塔
    └── tower_slow.tscn          # 减速塔
```

### 场景切换流程

```
开始菜单 (start_menu.tscn)
    ↓ 点击"开始游戏"
角色选择 (character_select.tscn)
    ↓ 选择角色
武器选择 (weapon_select.tscn)
    ↓ 选择武器
布置场景 (placement.tscn)
    ↓ 布置塔，点击"开始战斗"
战斗场景 (main.tscn)
    ↓ 波次完成
商店界面 (shop.tscn)
    ↓ 购买完成
布置场景 (placement.tscn)
    ↓ 继续布置，开始下一波
    ... 循环 ...
    ↓ 通关或失败
结算界面 (result.tscn)
    ↓ 返回主菜单
```

---

## 脚本组织

### 核心脚本

```
scripts/
├── game_data.gd              # AutoLoad: 全局游戏状态
├── player.gd                 # 玩家控制器
├── enemy.gd                  # 敌人基类
├── bullet.gd                 # 子弹逻辑
├── coin.gd                   # 金币拾取
├── hud.gd                    # 游戏内 HUD
├── tower.gd                  # 塔基类
├── tower_shooter.gd          # 射手塔
├── tower_wall.gd             # 墙塔
├── tower_slow.gd             # 减速塔
├── enemy_spawner.gd          # 敌人生成器
├── placement.gd              # 布置场景控制器
├── main.gd                   # 战斗场景控制器
├── shop_manager.gd           # 商店管理器
├── start_menu.gd             # 开始菜单
├── character_select.gd       # 角色选择
├── weapon_select.gd          # 武器选择
└── result.gd                 # 结算界面
```

### AutoLoad 单例

项目使用三个 AutoLoad 单例：

1. **GameData** (`scripts/game_data.gd`)
   - 管理跨场景的游戏状态
   - 玩家属性、金币、波次、塔库存等

2. **GameConfig** (`game_config.gd`)
   - 集中管理所有游戏配置
   - 武器、敌人、塔、波次、商店配置

3. **GDAIMCPRuntime** (`addons/gdai-mcp-plugin-godot/`)
   - GDAI MCP 插件运行时
   - 提供 AI 辅助开发功能

---

## 核心系统

### 1. GameData 单例

**职责**: 管理全局游戏状态，在场景切换时保持数据

**核心数据结构**:

```gdscript
# 玩家属性
var player_stats = {
    "max_hp": 100.0,
    "current_hp": 100.0,
    "damage_multiplier": 1.0,
    "attack_speed_multiplier": 1.0,
    "move_speed": 200.0,
    "hp_regen": 0.0
}

# 游戏状态
var selected_weapon: String = ""      # 选择的武器类型
var coins: int = 100                  # 当前金币
var current_wave: int = 1             # 当前波次

# 塔管理
var tower_inventory: Array = []      # 已布置的塔 [{type, position}, ...]
var purchased_towers: Array = []     # 商店购买的塔 ["shooter", "wall", ...]

# 待处理事件
var pending_heal: int = 0            # 待处理的治疗量
```

**关键方法**:

```gdscript
func reset_game()                    # 重置游戏状态
func apply_passive_upgrade(type, value)  # 应用被动升级
```

### 2. GameConfig 配置系统

**职责**: 集中管理所有游戏数值配置

**配置模块**:

- `CHARACTERS` - 角色配置（生命、速度、伤害倍率等）
- `WEAPONS` - 武器配置（伤害、射速、子弹数等）
- `ENEMIES` - 敌人配置（生命、速度、伤害、掉落）
- `TOWERS` - 塔配置（生命、伤害、射程、价格）
- `WAVES` - 波次配置（时长、刷怪间隔、敌人类型）
- `PLAYER` - 玩家配置（初始生命、速度、金币）
- `SHOP` - 商店配置（价格范围、刷新费用）

**使用示例**:

```gdscript
# 获取武器配置
var weapon_config = GameConfig.WEAPONS[GameData.selected_weapon]
var damage = weapon_config["damage"]

# 获取敌人配置
var enemy_config = GameConfig.ENEMIES["normal"]
max_hp = enemy_config["hp"]
```

详见 [配置系统文档](CONFIGURATION.md)

### 3. 角色系统

**文件**: `scripts/game_data.gd`

**核心功能**:
- 角色选择（战士、游侠、坦克）
- 角色基础属性初始化
- 商店升级在角色基础上叠加

**角色配置**:

| 角色 | 生命值 | 速度 | 伤害倍率 | 攻速倍率 | 生命回复 |
|------|--------|------|----------|----------|----------|
| 战士 | 150 | 180 | 1.2x | 1.0x | 0 |
| 游侠 | 80 | 250 | 0.9x | 1.1x | 0 |
| 坦克 | 200 | 150 | 0.8x | 0.9x | 1.0/5秒 |

**初始化流程**:

```gdscript
# 在 character_select.tscn 中选择角色
GameData.current_character = "warrior"

# 在 weapon_select.gd 的 _ready() 中初始化
GameData.init_character()
```

**数据流**:
```
角色选择 → init_character() → player_stats 初始化 → 商店升级叠加
```

### 4. 玩家系统

**文件**: `scripts/player.gd`

**核心功能**:
- WASD 移动控制
- 自动瞄准最近敌人
- 武器射击系统（支持单发/多发）
- 生命值管理和回复
- 金币拾取

**关键逻辑**:

```gdscript
# 自动瞄准
func _process(delta):
    var enemies = get_tree().get_nodes_in_group("enemies")
    var closest_enemy = null
    var closest_distance = weapon_range

    for enemy in enemies:
        var distance = global_position.distance_to(enemy.global_position)
        if distance < closest_distance:
            closest_enemy = enemy
            closest_distance = distance

    if closest_enemy:
        look_at(closest_enemy.global_position)
        shoot()
```

### 4. 敌人系统

**文件**: `scripts/enemy.gd`

**敌人类型**:
- **普通敌人**: 平衡的生命和速度
- **快速敌人**: 低生命高速度
- **坦克敌人**: 高生命低速度

**核心行为**:
- 简单追击玩家（直线向量移动）
- 碰撞玩家造成伤害
- 死亡掉落金币
- 受减速塔影响

**生成机制** (`enemy_spawner.gd`):
- 在屏幕边缘随机位置生成
- 根据波次配置选择敌人类型
- 按配置的刷怪间隔生成

### 5. 塔防系统

**塔类型**:

| 塔类型 | 文件 | 功能 | 关键属性 |
|--------|------|------|----------|
| 射手塔 | `tower_shooter.gd` | 自动攻击敌人 | 射程、伤害、射速 |
| 墙塔 | `tower_wall.gd` | 物理阻挡 | 高生命值 |
| 减速塔 | `tower_slow.gd` | 范围减速 | 减速百分比、范围 |

**塔基类** (`tower.gd`):

```gdscript
extends StaticBody2D

var tower_type: String = ""  # 塔类型标识
var max_hp: float
var current_hp: float

func take_damage(amount: float):
    current_hp -= amount
    if current_hp <= 0:
        queue_free()
```

**布置系统** (`placement.gd`):
- 网格对齐（32x32 像素）
- 塔预览和放置
- 保存塔位置到 `GameData.tower_inventory`
- 恢复已布置的塔

### 6. 波次系统

**文件**: `scripts/main.gd`, `scripts/enemy_spawner.gd`

**波次流程**:

```gdscript
func _ready():
    # 1. 恢复已布置的塔
    restore_towers()

    # 2. 启动波次
    start_wave()

func start_wave():
    # 获取当前波次配置
    var wave_config = GameConfig.WAVES["wave_configs"][GameData.current_wave - 1]

    # 设置波次时长
    wave_timer = wave_config["duration"]

    # 启动敌人生成器
    enemy_spawner.start_spawning(
        wave_config["spawn_interval"],
        wave_config["enemy_types"]
    )

func _process(delta):
    wave_timer -= delta
    if wave_timer <= 0:
        end_wave()

func end_wave():
    # 清除剩余敌人
    # 自动拾取金币
    # 进入商店或结算
```

### 7. 商店系统

**文件**: `scripts/shop_manager.gd`

**商品类型**:
1. **被动属性** - 提升玩家属性（生命、伤害、攻速、移速）
2. **防御塔** - 购买新塔用于布置
3. **消耗品** - 医疗包（立即回复生命）

**刷新机制**:
- 每次进入商店随机生成 4 个商品
- 可花费金币刷新商品列表
- 价格从配置中随机生成

**购买流程**:

```gdscript
func purchase_item(item_data):
    if GameData.coins >= item_data["price"]:
        GameData.coins -= item_data["price"]

        match item_data["type"]:
            "passive":
                GameData.apply_passive_upgrade(...)
            "tower":
                GameData.purchased_towers.append(item_data["tower_type"])
            "consumable":
                GameData.pending_heal += item_data["heal_amount"]
```

---

## 数据流

### 游戏启动流程

```
1. 加载 AutoLoad 单例
   ├── GameData (初始化游戏状态)
   ├── GameConfig (加载配置)
   └── GDAIMCPRuntime (启动 MCP 服务)

2. 进入开始菜单
   └── 等待用户输入

3. 用户点击"开始游戏"
   └── GameData.reset_game()
   └── 切换到武器选择场景
```

### 战斗循环数据流

```
布置场景 (placement.tscn)
    ├── _ready()
    │   └── 从 GameData.tower_inventory 恢复已有塔
    ├── 用户布置新塔
    └── start_battle()
        └── 收集所有塔 → GameData.tower_inventory
        └── 切换到 main.tscn

战斗场景 (main.tscn)
    ├── _ready()
    │   ├── 从 GameData.tower_inventory 恢复塔
    │   └── 启动波次
    ├── 战斗进行中
    │   ├── 玩家射击敌人
    │   ├── 塔攻击敌人
    │   ├── 敌人追击玩家
    │   └── 收集金币 → GameData.coins
    └── 波次结束
        ├── GameData.current_wave += 1
        └── 切换到 shop.tscn

商店场景 (shop.tscn)
    ├── 生成随机商品
    ├── 用户购买
    │   ├── 被动升级 → GameData.player_stats
    │   ├── 塔 → GameData.purchased_towers
    │   └── 消耗品 → GameData.pending_heal
    └── 点击"继续"
        └── 切换回 placement.tscn
```

### 塔数据持久化

```
placement.gd:
    start_battle() {
        收集场景中所有塔
        ↓
        保存到 GameData.tower_inventory = [
            {type: "shooter", position: Vector2(100, 100)},
            {type: "wall", position: Vector2(200, 100)},
            ...
        ]
    }

main.gd:
    _ready() {
        读取 GameData.tower_inventory
        ↓
        实例化塔场景
        ↓
        设置位置
        ↓
        添加到场景树
    }
```

---

## 关键设计决策

### 1. 为什么使用 AutoLoad 单例？

**问题**: 场景切换时数据丢失

**解决方案**: 使用 GameData 单例保持状态

**优点**:
- 简单直接，易于理解
- 适合小型项目
- 避免复杂的序列化/反序列化

**缺点**:
- 全局状态可能导致耦合
- 不适合大型项目

### 2. 为什么分离 GameData 和 GameConfig？

**GameData**: 运行时状态（会变化）
**GameConfig**: 静态配置（不变）

**优点**:
- 职责分离，清晰明确
- 配置可以独立调整
- 便于后续支持外部配置文件

### 3. 为什么使用简单的敌人追击而非 A* 寻路？

**原因**:
- MVP 阶段优先验证核心玩法
- 简单追击性能更好，支持更多敌人
- 减少开发复杂度

**未来扩展**:
- 可以为特定敌人类型添加寻路
- 可以添加障碍物躲避逻辑

### 4. 为什么塔使用 StaticBody2D？

**原因**:
- 塔不需要移动
- StaticBody2D 性能更好
- 提供物理碰撞（阻挡敌人）

### 5. 为什么使用组（Groups）管理实体？

**使用场景**:
- `get_tree().get_nodes_in_group("enemies")` - 查找所有敌人
- `get_tree().get_nodes_in_group("towers")` - 查找所有塔

**优点**:
- 无需维护全局数组
- 自动处理实体销毁
- 查询简单高效

---

## 性能考虑

### 当前优化

1. **对象池**: 子弹和金币使用 `queue_free()` 自动回收
2. **碰撞层**: 合理设置碰撞层避免不必要的碰撞检测
3. **简单寻路**: 使用向量计算而非 A* 寻路
4. **StaticBody2D**: 塔使用静态刚体减少物理计算

### 潜在瓶颈

- 大量敌人时的 `get_nodes_in_group()` 调用
- 每帧的距离计算（玩家瞄准、塔索敌）
- 大量子弹的碰撞检测

### 未来优化方向

- 使用空间分区（Quadtree）优化敌人查询
- 限制每帧的距离计算数量
- 使用对象池管理子弹和敌人

---

## 扩展性设计

### 添加新武器

1. 在 `GameConfig.WEAPONS` 添加配置
2. 在 `weapon_select.tscn` 添加选项
3. 在 `player.gd` 的 `shoot()` 方法添加逻辑

### 添加新敌人

1. 在 `GameConfig.ENEMIES` 添加配置
2. 复制 `enemy_normal.tscn` 创建新场景
3. 在 `enemy_spawner.gd` 添加场景引用
4. 在波次配置中使用新敌人类型

### 添加新塔

1. 在 `GameConfig.TOWERS` 添加配置
2. 创建新的塔场景和脚本（继承 `tower.gd`）
3. 在 `placement.gd` 添加场景引用
4. 在商店配置中添加购买选项

详见 [开发指南](DEVELOPMENT.md)
