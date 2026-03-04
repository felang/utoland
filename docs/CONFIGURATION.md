# 配置系统文档

本文档说明 Utoland 的配置系统结构和使用方法。

## 目录

- [配置系统概述](#配置系统概述)
- [配置文件结构](#配置文件结构)
- [配置项详解](#配置项详解)
- [如何调整数值](#如何调整数值)
- [添加新内容](#添加新内容)

---

## 配置系统概述

### 设计目标

Utoland 使用集中化的配置系统（`game_config.gd`），实现：

1. **统一管理**: 所有游戏数值集中在一个文件
2. **易于调整**: 修改配置即可调整游戏平衡
3. **类型安全**: 使用 GDScript 常量，编译时检查
4. **可维护性**: 清晰的结构，便于理解和修改

### 配置文件位置

```
utoland/
└── game_config.gd    # 配置中心（AutoLoad 单例）
```

### 使用方式

配置通过 `GameConfig` 单例访问：

```gdscript
# 获取武器配置
var weapon_config = GameConfig.WEAPONS["rifle"]
var damage = weapon_config["damage"]

# 获取敌人配置
var enemy_config = GameConfig.ENEMIES["normal"]
var hp = enemy_config["hp"]

# 获取波次配置
var wave_config = GameConfig.WAVES["wave_configs"][0]
var duration = wave_config["duration"]
```

---

## 配置文件结构

### 完整结构

```gdscript
extends Node

# 开发模式开关
const DEBUG_MODE = true

# 武器配置
const WEAPONS = { ... }

# 敌人配置
const ENEMIES = { ... }

# 塔配置
const TOWERS = { ... }

# 波次配置
const WAVES = { ... }

# 玩家配置
const PLAYER = { ... }

# 商店配置
const SHOP = { ... }
```

---

## 配置项详解

### 1. 武器配置 (WEAPONS)

```gdscript
const WEAPONS = {
    "rifle": {
        "name": "步枪",
        "fire_rate": 0.1,        # 射击间隔（秒）
        "damage": 10.0,          # 基础伤害
        "bullet_count": 1,       # 每次发射子弹数
        "bullet_speed": 600      # 子弹速度
    },
    "shotgun": {
        "name": "霰弹枪",
        "fire_rate": 0.6,
        "damage": 6.0,
        "bullet_count": 5,
        "spread_angles": [-7.5, -3.75, 0, 3.75, 7.5],  # 散射角度
        "bullet_speed": 500
    },
    "sniper": {
        "name": "狙击枪",
        "fire_rate": 1.0,
        "damage": 30.0,
        "bullet_count": 1,
        "bullet_speed": 800
    }
}
```

**字段说明**:

| 字段 | 类型 | 说明 | 影响 |
|------|------|------|------|
| `name` | String | 武器显示名称 | UI 显示 |
| `fire_rate` | float | 射击间隔（秒） | 射速，越小越快 |
| `damage` | float | 单发伤害 | 输出能力 |
| `bullet_count` | int | 每次发射子弹数 | 霰弹枪专用 |
| `spread_angles` | Array | 散射角度数组 | 霰弹枪专用 |
| `bullet_speed` | int | 子弹飞行速度 | 命中速度 |

**DPS 计算**:
```
DPS = (damage × bullet_count) / fire_rate
```

### 2. 敌人配置 (ENEMIES)

```gdscript
const ENEMIES = {
    "normal": {
        "name": "普通敌人",
        "hp": 50.0,              # 生命值
        "speed": 100.0,          # 移动速度
        "damage": 10.0,          # 碰撞伤害
        "coin_drop_min": 1,      # 最小掉落金币
        "coin_drop_max": 3       # 最大掉落金币
    },
    "fast": {
        "name": "快速敌人",
        "hp": 35.0,
        "speed": 180.0,
        "damage": 8.0,
        "coin_drop_min": 2,
        "coin_drop_max": 4
    },
    "tank": {
        "name": "坦克敌人",
        "hp": 200.0,
        "speed": 50.0,
        "damage": 25.0,
        "coin_drop_min": 5,
        "coin_drop_max": 10
    }
}
```

**字段说明**:

| 字段 | 类型 | 说明 | 平衡建议 |
|------|------|------|----------|
| `hp` | float | 生命值 | 影响击杀时间 |
| `speed` | float | 移动速度 | 玩家基础速度 200 |
| `damage` | float | 碰撞伤害 | 玩家初始 100 HP |
| `coin_drop_min/max` | int | 掉落金币范围 | 影响经济节奏 |

**设计原则**:
- 快速敌人: 低 HP + 高速度 + 中等掉落
- 坦克敌人: 高 HP + 低速度 + 高掉落
- 普通敌人: 平衡属性

### 3. 塔配置 (TOWERS)

```gdscript
const TOWERS = {
    "shooter": {
        "name": "射手塔",
        "hp": 80.0,              # 生命值
        "damage": 15.0,          # 攻击伤害
        "fire_rate": 1.0,        # 射击间隔（秒）
        "range": 300.0,          # 攻击范围
        "shop_price_min": 35,    # 商店最低价格
        "shop_price_max": 45     # 商店最高价格
    },
    "wall": {
        "name": "墙塔",
        "hp": 300.0,
        "shop_price_min": 35,
        "shop_price_max": 45
    },
    "slow": {
        "name": "减速塔",
        "hp": 70.0,
        "range": 200.0,          # 减速范围
        "slow_percent": 0.3,     # 减速百分比（30%）
        "shop_price_min": 35,
        "shop_price_max": 45
    }
}
```

**字段说明**:

| 字段 | 类型 | 说明 | 适用塔 |
|------|------|------|--------|
| `hp` | float | 生命值 | 所有塔 |
| `damage` | float | 攻击伤害 | 射手塔 |
| `fire_rate` | float | 射击间隔 | 射手塔 |
| `range` | float | 作用范围 | 射手塔、减速塔 |
| `slow_percent` | float | 减速百分比 | 减速塔 |
| `shop_price_min/max` | int | 价格范围 | 所有塔 |

### 4. 波次配置 (WAVES)

```gdscript
const WAVES = {
    "total_waves": 10,
    "wave_configs": [
        {
            "duration": 45,           # 波次时长（秒）
            "spawn_interval": 1.5,    # 刷怪间隔（秒）
            "enemy_types": ["normal"] # 敌人类型列表
        },
        {
            "duration": 45,
            "spawn_interval": 1.5,
            "enemy_types": ["normal"]
        },
        {
            "duration": 50,
            "spawn_interval": 1.0,
            "enemy_types": ["normal", "fast"]
        },
        # ... 共 10 个波次配置
    ]
}
```

**字段说明**:

| 字段 | 类型 | 说明 | 影响 |
|------|------|------|------|
| `duration` | int | 波次时长（秒） | 生存压力 |
| `spawn_interval` | float | 刷怪间隔（秒） | 敌人密度 |
| `enemy_types` | Array | 敌人类型列表 | 敌人多样性 |

**难度曲线设计**:
- 波次 1-2: 45秒，1.5秒间隔，仅普通敌人
- 波次 3-5: 50-55秒，1.0秒间隔，普通+快速
- 波次 6-8: 55-60秒，0.8秒间隔，全类型
- 波次 9-10: 60秒，0.5秒间隔，全类型高密度

### 5. 玩家配置 (PLAYER)

```gdscript
const PLAYER = {
    "initial_hp": 100.0,         # 初始生命值
    "initial_speed": 200.0,      # 初始移动速度
    "initial_coins": 100,        # 初始金币
    "hp_regen_interval": 5.0     # 生命回复间隔（秒）
}
```

**字段说明**:

| 字段 | 类型 | 说明 | 平衡影响 |
|------|------|------|----------|
| `initial_hp` | float | 初始生命值 | 容错率 |
| `initial_speed` | float | 初始移动速度 | 走位能力 |
| `initial_coins` | int | 初始金币 | 初始布置能力 |
| `hp_regen_interval` | float | 回复间隔 | 回复频率 |

### 6. 商店配置 (SHOP)

```gdscript
const SHOP = {
    "refresh_cost": 10,          # 刷新费用
    "item_count": 4,             # 商品数量
    "passive_price_min": 20,     # 被动升级最低价格
    "passive_price_max": 40,     # 被动升级最高价格
    "heal_price": 12,            # 医疗包价格
    "heal_amount": 50            # 医疗包回复量
}
```

**字段说明**:

| 字段 | 类型 | 说明 | 经济影响 |
|------|------|------|----------|
| `refresh_cost` | int | 刷新费用 | 刷新成本 |
| `item_count` | int | 商品数量 | 选择空间 |
| `passive_price_min/max` | int | 被动升级价格范围 | 升级成本 |
| `heal_price` | int | 医疗包价格 | 回复成本 |
| `heal_amount` | int | 医疗包回复量 | 回复效果 |

---

## 如何调整数值

### 调整武器平衡

**提升武器强度**:
```gdscript
# 提高伤害
"damage": 10.0 → 12.0

# 提高射速
"fire_rate": 0.1 → 0.08

# 两者都提升 DPS
```

**降低武器强度**:
```gdscript
# 降低伤害
"damage": 10.0 → 8.0

# 降低射速
"fire_rate": 0.1 → 0.12
```

**霰弹枪特殊调整**:
```gdscript
# 调整散射角度（更集中或更分散）
"spread_angles": [-7.5, -3.75, 0, 3.75, 7.5]
                → [-5.0, -2.5, 0, 2.5, 5.0]  # 更集中

# 调整子弹数量
"bullet_count": 5 → 4  # 降低爆发
```

### 调整难度

**降低游戏难度**:

```gdscript
# 1. 增加初始资源
PLAYER = {
    "initial_hp": 100.0 → 120.0,
    "initial_coins": 100 → 150
}

# 2. 削弱敌人
ENEMIES = {
    "normal": {
        "hp": 50.0 → 40.0,
        "damage": 10.0 → 8.0
    }
}

# 3. 延长波次时间
WAVES = {
    "wave_configs": [
        {"duration": 45 → 60, ...}
    ]
}

# 4. 降低商店价格
SHOP = {
    "passive_price_min": 20 → 15,
    "passive_price_max": 40 → 30
}
```

**提高游戏难度**:

```gdscript
# 1. 减少初始资源
PLAYER = {
    "initial_hp": 100.0 → 80.0,
    "initial_coins": 100 → 80
}

# 2. 强化敌人
ENEMIES = {
    "normal": {
        "hp": 50.0 → 60.0,
        "speed": 100.0 → 120.0,
        "damage": 10.0 → 12.0
    }
}

# 3. 缩短刷怪间隔
WAVES = {
    "wave_configs": [
        {"spawn_interval": 1.5 → 1.0, ...}
    ]
}

# 4. 提高商店价格
SHOP = {
    "passive_price_min": 20 → 25,
    "passive_price_max": 40 → 50
}
```

### 调整经济节奏

**增加金币收入**:
```gdscript
# 提高敌人掉落
ENEMIES = {
    "normal": {
        "coin_drop_min": 1 → 2,
        "coin_drop_max": 3 → 5
    }
}

# 增加初始金币
PLAYER = {
    "initial_coins": 100 → 150
}
```

**减少金币收入**:
```gdscript
# 降低敌人掉落
ENEMIES = {
    "normal": {
        "coin_drop_min": 1 → 1,
        "coin_drop_max": 3 → 2
    }
}

# 提高商店价格
TOWERS = {
    "shooter": {
        "shop_price_min": 35 → 45,
        "shop_price_max": 45 → 55
    }
}
```

---

## 添加新内容

### 添加新武器

**步骤**:

1. 在 `GameConfig.WEAPONS` 中添加配置：

```gdscript
const WEAPONS = {
    # ... 现有武器 ...
    "laser": {
        "name": "激光枪",
        "fire_rate": 0.05,
        "damage": 5.0,
        "bullet_count": 1,
        "bullet_speed": 1000,
        "penetrate": true  # 自定义属性
    }
}
```

2. 在 `weapon_select.tscn` 中添加选择按钮

3. 在 `player.gd` 中处理新武器逻辑：

```gdscript
func shoot():
    var weapon_config = GameConfig.WEAPONS[GameData.selected_weapon]

    if weapon_config.has("penetrate") and weapon_config["penetrate"]:
        # 穿透逻辑
        pass
```

### 添加新敌人

**步骤**:

1. 在 `GameConfig.ENEMIES` 中添加配置：

```gdscript
const ENEMIES = {
    # ... 现有敌人 ...
    "flying": {
        "name": "飞行敌人",
        "hp": 40.0,
        "speed": 150.0,
        "damage": 12.0,
        "coin_drop_min": 3,
        "coin_drop_max": 6,
        "can_fly": true  # 自定义属性
    }
}
```

2. 创建敌人场景 `scenes/enemies/enemy_flying.tscn`

3. 在 `enemy_spawner.gd` 中注册场景：

```gdscript
var enemy_scenes = {
    "normal": preload("res://scenes/enemies/enemy_normal.tscn"),
    "fast": preload("res://scenes/enemies/enemy_fast.tscn"),
    "tank": preload("res://scenes/enemies/enemy_tank.tscn"),
    "flying": preload("res://scenes/enemies/enemy_flying.tscn")
}
```

4. 在波次配置中使用：

```gdscript
{"duration": 60, "spawn_interval": 0.8, "enemy_types": ["normal", "fast", "flying"]}
```

### 添加新塔

**步骤**:

1. 在 `GameConfig.TOWERS` 中添加配置：

```gdscript
const TOWERS = {
    # ... 现有塔 ...
    "flame": {
        "name": "火焰塔",
        "hp": 90.0,
        "damage": 5.0,
        "fire_rate": 0.2,
        "range": 150.0,
        "shop_price_min": 40,
        "shop_price_max": 50,
        "damage_over_time": true  # 自定义属性
    }
}
```

2. 创建塔脚本 `scripts/tower_flame.gd`：

```gdscript
extends "res://scripts/tower.gd"

func _ready():
    tower_type = "flame"
    var config = GameConfig.TOWERS["flame"]
    max_hp = config["hp"]
    current_hp = max_hp
    # ... 初始化其他属性
```

3. 创建塔场景 `scenes/towers/tower_flame.tscn`

4. 在 `placement.gd` 中注册场景：

```gdscript
var tower_scenes = {
    "shooter": preload("res://scenes/towers/tower_shooter.tscn"),
    "wall": preload("res://scenes/towers/tower_wall.tscn"),
    "slow": preload("res://scenes/towers/tower_slow.tscn"),
    "flame": preload("res://scenes/towers/tower_flame.tscn")
}
```

### 添加新波次

**步骤**:

1. 修改总波次数：

```gdscript
const WAVES = {
    "total_waves": 10 → 15,
    "wave_configs": [
        # ... 现有 10 波 ...
        {
            "duration": 70,
            "spawn_interval": 0.3,
            "enemy_types": ["normal", "fast", "tank", "flying"]
        },
        # ... 添加更多波次
    ]
}
```

2. 更新结算逻辑 `result.gd`：

```gdscript
if GameData.current_wave > GameConfig.WAVES["total_waves"]:
    # 胜利
```

---

## 配置最佳实践

### 1. 修改前备份

```bash
# 复制配置文件
cp game_config.gd game_config.gd.backup
```

### 2. 小步迭代

- 每次只修改一个参数
- 测试效果后再继续调整
- 记录修改原因和效果

### 3. 保持平衡

**武器平衡**:
- 不同武器应有不同定位
- DPS 差异不应过大（2倍以内）
- 考虑实战表现，不只看数值

**敌人平衡**:
- 威胁度 = HP × 速度 × 伤害
- 掉落金币应与威胁度匹配
- 混合出现时考虑协同效果

**经济平衡**:
- 初始金币应能布置 2-3 个塔
- 每波收入应能购买 1-2 件商品
- 避免金币过剩或过度匮乏

### 4. 使用注释

```gdscript
const WEAPONS = {
    "rifle": {
        "damage": 10.0,  # 2026-03-04: 从 12.0 降低到 10.0，平衡 DPS
        "fire_rate": 0.1
    }
}
```

### 5. 测试验证

修改配置后必须测试：
- 完整通关一次
- 测试不同武器
- 测试不同策略
- 检查经济节奏

---

## 常见问题

### Q: 修改配置后不生效？

**A**: 确保：
1. 保存了 `game_config.gd` 文件
2. 重新运行游戏（Godot 会重新加载）
3. 检查是否有语法错误

### Q: 如何快速测试某一波？

**A**: 临时修改 `GameData.current_wave`：

```gdscript
# 在 main.gd 的 _ready() 中
func _ready():
    GameData.current_wave = 9  # 直接测试第 9 波
    start_wave()
```

### Q: 如何禁用某个敌人类型？

**A**: 从波次配置中移除：

```gdscript
# 移除坦克敌人
{"enemy_types": ["normal", "fast", "tank"]}
              → ["normal", "fast"]
```

### Q: 如何让游戏更简单/更难？

**A**: 参考 [调整难度](#调整难度) 章节，综合调整多个参数。

---

## 相关文档

- [系统架构](ARCHITECTURE.md) - 了解配置如何被使用
- [游戏设计](GAME_DESIGN.md) - 了解数值设计理念
- [开发指南](DEVELOPMENT.md) - 了解如何添加新内容
