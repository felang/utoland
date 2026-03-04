# 配置驱动优化设计文档

**日期**: 2026-03-04
**版本**: v1.0
**项目**: Utoland
**设计目标**: 通过配置系统解决数值调整困难问题，提升代码可维护性

---

## 一、背景与目标

### 当前问题
1. **数值调整困难**：游戏参数散落在各个脚本中，难以统一管理和快速调整
2. **整体难度偏简单**：需要频繁调整敌人、武器、经济等数值来平衡难度
3. **代码可维护性担忧**：担心项目规模扩大后代码质量和可维护性下降
4. **调试效率低**：每次调整数值需要重启游戏，测试周期长

### 设计目标
1. **集中化配置管理**：所有游戏数值统一在配置文件中管理
2. **快速迭代能力**：支持热重载和游戏内调试，快速测试不同数值组合
3. **代码质量提升**：消除硬编码，提高代码可读性和可维护性
4. **为未来扩展打基础**：建立清晰的配置架构，便于后续添加新内容

---

## 二、配置文件架构

### 2.1 配置文件结构

创建 `game_config.gd` 作为全局配置单例（Autoload），包含以下模块：

#### 武器配置
```gdscript
const WEAPONS = {
    "rifle": {
        "name": "步枪",
        "fire_rate": 0.1,
        "damage": 10.0,
        "bullet_count": 1,
        "bullet_speed": 600
    },
    "shotgun": {
        "name": "霰弹枪",
        "fire_rate": 0.5,
        "damage": 8.0,
        "bullet_count": 5,
        "spread_angles": [-7.5, -3.75, 0, 3.75, 7.5],
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

#### 敌人配置
```gdscript
const ENEMIES = {
    "normal": {
        "name": "普通敌人",
        "hp": 50.0,
        "speed": 100.0,
        "damage": 10.0,
        "coin_drop_min": 1,
        "coin_drop_max": 3
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

#### 塔配置
```gdscript
const TOWERS = {
    "shooter": {
        "name": "射手塔",
        "hp": 80.0,
        "damage": 15.0,
        "fire_rate": 1.0,
        "range": 300.0,
        "shop_price_min": 35,
        "shop_price_max": 45
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
        "range": 200.0,
        "slow_percent": 0.3,
        "shop_price_min": 35,
        "shop_price_max": 45
    }
}
```

#### 波次配置
```gdscript
const WAVES = {
    "total_waves": 10,
    "wave_configs": [
        {"duration": 45, "spawn_interval": 1.5, "enemy_types": ["normal"]},
        {"duration": 45, "spawn_interval": 1.5, "enemy_types": ["normal"]},
        {"duration": 50, "spawn_interval": 1.0, "enemy_types": ["normal", "fast"]},
        {"duration": 50, "spawn_interval": 1.0, "enemy_types": ["normal", "fast"]},
        {"duration": 55, "spawn_interval": 1.0, "enemy_types": ["normal", "fast"]},
        {"duration": 55, "spawn_interval": 0.8, "enemy_types": ["normal", "fast", "tank"]},
        {"duration": 60, "spawn_interval": 0.8, "enemy_types": ["normal", "fast", "tank"]},
        {"duration": 60, "spawn_interval": 0.8, "enemy_types": ["normal", "fast", "tank"]},
        {"duration": 60, "spawn_interval": 0.5, "enemy_types": ["normal", "fast", "tank"]},
        {"duration": 60, "spawn_interval": 0.5, "enemy_types": ["normal", "fast", "tank"]}
    ]
}
```

#### 玩家配置
```gdscript
const PLAYER = {
    "initial_hp": 100.0,
    "initial_speed": 200.0,
    "initial_coins": 100,
    "hp_regen_interval": 5.0
}
```

#### 商店配置
```gdscript
const SHOP = {
    "refresh_cost": 10,
    "item_count": 4,
    "passive_price_min": 20,
    "passive_price_max": 40,
    "heal_price": 12,
    "heal_amount": 50
}
```

### 2.2 配置访问方式

所有脚本通过 `GameConfig` 单例访问配置：

```gdscript
# 获取武器数据
var weapon_data = GameConfig.WEAPONS[weapon_type]
var damage = weapon_data["damage"]

# 获取敌人数据
var enemy_data = GameConfig.ENEMIES[enemy_type]
var hp = enemy_data["hp"]

# 获取塔数据
var tower_data = GameConfig.TOWERS[tower_type]
var range = tower_data["range"]
```

---

## 三、调试工具系统

### 3.1 调试面板功能

创建游戏内调试面板，方便开发和测试：

#### 面板结构
- **游戏控制标签页**
  - 跳转到指定波次
  - 无敌模式开关
  - 无限金币开关
  - 清除所有敌人
  - 暂停/继续游戏

- **数值调整标签页**
  - 实时修改武器伤害/射速
  - 实时修改敌人血量/速度
  - 实时修改塔的属性
  - 修改玩家金币数量

- **性能监控标签页**
  - FPS 显示
  - 当前敌人数量
  - 内存占用
  - 节点数量

- **快速测试标签页**
  - 一键生成 10 个测试敌人
  - 一键获得所有塔
  - 一键跳到 Boss 波

### 3.2 调试快捷键

```
F12: 开关调试面板
F11: 开关调试信息显示（HUD）
F9:  重新加载配置文件（热重载）
F1:  无敌模式切换
F2:  +1000 金币
F3:  跳到下一波
F4:  清除所有敌人
F5:  生成 10 个测试敌人
```

### 3.3 调试信息显示

在屏幕左上角显示关键信息（F11 切换）：

```
=== 调试信息 ===
FPS: 60
波次: 3/10 (剩余 35s)
敌人数: 25
金币: 150
玩家: 80/100 HP
塔数量: 5
```

### 3.4 配置热重载

- 修改 `game_config.gd` 后按 F9 重新加载
- 无需重启游戏，立即生效
- 显示重载成功/失败提示
- 仅在开发模式下启用（通过配置开关控制）

### 3.5 实现方式

- 创建 `scenes/debug/debug_panel.tscn` 场景（CanvasLayer）
- 创建 `scripts/debug_manager.gd` 自动加载单例
- 添加开发模式开关：`GameConfig.DEBUG_MODE = true`

---

## 四、代码重构策略

### 4.1 重构原则

1. **最小化改动**：降低引入 bug 的风险
2. **逐个文件重构**：每次重构后测试功能
3. **保持向后兼容**：确保游戏始终可运行
4. **消除硬编码**：所有数值从配置读取

### 4.2 重构步骤

#### 步骤 1：创建配置系统
- 创建 `game_config.gd`
- 添加为自动加载单例（Autoload）
- 定义所有配置常量

#### 步骤 2：重构玩家系统 (`scripts/player.gd`)
**修改前**：
```gdscript
var fire_rate = 0.1
var damage = 10.0
var bullet_count = 1
```

**修改后**：
```gdscript
var weapon_data = GameConfig.WEAPONS[GameData.selected_weapon]
var fire_rate = weapon_data["fire_rate"]
var damage = weapon_data["damage"]
var bullet_count = weapon_data["bullet_count"]
```

**重构内容**：
- 武器数据从配置读取
- 玩家初始属性从配置读取
- 霰弹枪扩散角度从配置读取

#### 步骤 3：重构敌人系统 (`scripts/enemy.gd`)
**修改前**：
```gdscript
var hp = 30.0
var speed = 80.0
var damage = 10.0
```

**修改后**：
```gdscript
var enemy_type: String = "normal"  # 由生成器设置
var enemy_data = GameConfig.ENEMIES[enemy_type]
var hp = enemy_data["hp"]
var speed = enemy_data["speed"]
var damage = enemy_data["damage"]
```

**重构内容**：
- 添加 `enemy_type` 属性
- 所有属性从配置读取
- 金币掉落数量从配置读取

#### 步骤 4：重构塔系统 (`scripts/tower_*.gd`)
**修改前**：
```gdscript
# tower_shooter.gd
var hp = 80.0
var damage = 15.0
var fire_rate = 1.0
```

**修改后**：
```gdscript
var tower_type: String = "shooter"
var tower_data = GameConfig.TOWERS[tower_type]
var hp = tower_data["hp"]
var damage = tower_data["damage"]
var fire_rate = tower_data["fire_rate"]
```

**重构内容**：
- 统一三种塔的配置读取方式
- 添加 `tower_type` 属性（解决已知问题 #4）
- 商店价格从配置读取

#### 步骤 5：重构波次系统 (`scripts/wave_manager.gd`)
**重构内容**：
- 从 `GameConfig.WAVES` 读取波次配置
- 支持动态调整生成间隔和敌人类型
- 根据配置生成不同类型的敌人

#### 步骤 6：重构商店系统 (`scripts/shop_manager.gd`)
**重构内容**：
- 价格范围从配置读取
- 刷新费用从配置读取
- 医疗包价格和回复量从配置读取

#### 步骤 7：添加调试系统
- 创建调试面板场景
- 实现调试管理器
- 添加快捷键处理
- 实现配置热重载

#### 步骤 8：全面测试
- 测试所有武器
- 测试所有敌人类型
- 测试所有塔
- 测试完整游戏流程（10 波）
- 测试调试功能

### 4.3 重构顺序

```
1. game_config.gd (创建配置)
   ↓
2. player.gd (玩家系统)
   ↓
3. enemy.gd (敌人系统)
   ↓
4. tower_*.gd (塔系统)
   ↓
5. wave_manager.gd (波次系统)
   ↓
6. shop_manager.gd (商店系统)
   ↓
7. debug_manager.gd + debug_panel.tscn (调试系统)
   ↓
8. 全面测试和数值调整
```

---

## 五、难度平衡调整方案

### 5.1 当前问题分析

**整体难度偏简单**，可能原因：
- 敌人血量偏低，容易被秒杀
- 敌人生成速度慢，压力不足
- 金币获取容易，可以快速购买大量升级
- 塔的性价比过高

### 5.2 调整方向

#### 敌人强化
```gdscript
# 当前值 → 建议值
"normal": {
    "hp": 30.0 → 50.0      # 提高 67%
    "speed": 80.0 → 100.0  # 提高 25%
}
"fast": {
    "hp": 20.0 → 35.0      # 提高 75%
    "speed": 150.0 → 180.0 # 提高 20%
}
"tank": {
    "hp": 100.0 → 200.0    # 翻倍
    "damage": 20.0 → 25.0  # 提高 25%
}
```

#### 波次难度曲线优化
```gdscript
# 更激进的难度递增
波次 1-2: 生成间隔 2.0s → 1.5s
波次 3-5: 混入快速敌人，间隔 1.5s → 1.0s
波次 6-8: 混入坦克敌人，间隔 1.0s → 0.8s
波次 9-10: 三种敌人混合，间隔 0.8s → 0.5s
```

#### 经济系统收紧
```gdscript
# 减少金币获取
"coin_drop_min": 2 → 1
"coin_drop_max": 5 → 3

# 提高商店价格
"passive_price_min": 15 → 20
"passive_price_max": 30 → 40
"tower_price_min": 25 → 35
"tower_price_max": 30 → 45
```

#### 武器平衡（修复已知问题 #1）
```gdscript
# 霰弹枪削弱
"shotgun": {
    "damage": 8.0 → 6.0      # 降低单发伤害
    "fire_rate": 0.5 → 0.6   # 降低射速
    # DPS: 80 → 50 (降低 37.5%)
}
```

### 5.3 调整策略

1. **小幅迭代调整**
   - 先进行 10-20% 的小幅调整
   - 通过调试面板快速测试
   - 记录测试数据

2. **数据驱动决策**
   - 记录通关时间
   - 记录剩余血量
   - 记录金币使用情况
   - 记录死亡波次

3. **多轮测试**
   - 测试不同武器的通关难度
   - 测试不同策略的可行性
   - 确保每种武器都有价值

4. **难度预设（可选）**
   - 简单模式：当前数值
   - 普通模式：建议数值
   - 困难模式：进一步强化

### 5.4 测试流程

1. 使用 F3 跳转到不同波次
2. 修改 `game_config.gd` 中的数值
3. 按 F9 热重载配置
4. 测试新数值的游戏体验
5. 记录测试结果
6. 迭代调整直到满意

---

## 六、实施计划

### 6.1 开发阶段

**阶段 1：配置系统搭建**（0.5 会话）
- 创建 `game_config.gd`
- 定义所有配置常量
- 设置为自动加载

**阶段 2：核心系统重构**（1 会话）
- 重构玩家系统
- 重构敌人系统
- 重构塔系统
- 基础功能测试

**阶段 3：辅助系统重构**（0.5 会话）
- 重构波次系统
- 重构商店系统
- 完整流程测试

**阶段 4：调试工具开发**（0.5 会话）
- 创建调试面板
- 实现调试管理器
- 添加快捷键和热重载

**阶段 5：难度平衡调整**（0.5 会话）
- 调整敌人数值
- 调整经济系统
- 调整武器平衡
- 多轮测试迭代

**总计**：约 3 个会话

### 6.2 验收标准

- [ ] 所有游戏数值集中在 `game_config.gd` 中
- [ ] 所有脚本从配置读取数值，无硬编码
- [ ] 调试面板功能完整可用
- [ ] 配置热重载功能正常
- [ ] 完整游戏流程可正常运行
- [ ] 难度调整到合理水平
- [ ] 修复霰弹枪平衡问题（已知问题 #1）
- [ ] 修复塔类型识别问题（已知问题 #4）

### 6.3 风险与应对

**风险 1：重构引入新 bug**
- 应对：逐个文件重构，每次重构后立即测试
- 应对：保持 git 提交频率，方便回滚

**风险 2：配置结构设计不合理**
- 应对：先实现基础版本，后续可以迭代优化
- 应对：保持配置结构的灵活性

**风险 3：调试工具影响性能**
- 应对：仅在开发模式下启用
- 应对：发布版本自动禁用调试功能

---

## 七、后续扩展方向

### 7.1 短期扩展（配置系统完成后）
- 添加更多武器类型（配置驱动，易于扩展）
- 添加更多敌人类型（配置驱动，易于扩展）
- 添加更多塔类型（配置驱动，易于扩展）
- 添加难度选择（简单/普通/困难）

### 7.2 中期扩展（美术资源集成前）
- 配置文件外部化（JSON/YAML）
- 可视化配置编辑器
- 数据统计和分析系统
- 自动化平衡测试

### 7.3 长期扩展（项目成熟后）
- 模组支持（通过配置文件）
- 关卡编辑器
- 成就系统（配置驱动）
- 多语言支持（配置驱动）

---

## 八、总结

### 8.1 设计优势

1. **立即解决痛点**：数值调整从"改代码重启游戏"变为"改配置热重载"
2. **提升开发效率**：调试面板大幅缩短测试周期
3. **提高代码质量**：消除硬编码，提升可读性和可维护性
4. **为未来打基础**：清晰的配置架构便于后续扩展
5. **风险可控**：渐进式重构，不影响现有功能

### 8.2 预期效果

- **数值调整时间**：从 5-10 分钟降低到 10-30 秒
- **测试迭代速度**：提升 10 倍以上
- **代码可维护性**：显著提升
- **难度平衡**：通过快速迭代达到理想状态

### 8.3 下一步

设计文档确认后，将创建详细的实施计划（implementation plan），逐步执行重构和优化工作。

---

**文档结束**
