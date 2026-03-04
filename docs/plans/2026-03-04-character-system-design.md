# 角色系统设计文档

**日期**: 2026-03-04
**状态**: 已批准
**作者**: Claude + 用户协作

## 背景

Utoland 当前只有单一玩家实体，缺少角色选择机制。为了支持未来的内容扩展（多角色、多武器、多地图），需要建立可扩展的角色系统架构。

## 目标

1. 实现多角色选择功能
2. 支持轻度差异化角色（数值差异）
3. 保持架构简单，避免过度设计
4. 为未来扩展（被动能力、Resource 系统）预留空间

## 设计原则

- **配置驱动**: 使用 `GameConfig.CHARACTERS` 管理角色数据
- **最小改动**: 在现有架构上扩展，不重构核心系统
- **渐进式**: 先实现数值差异，未来再考虑 Resource 和复杂能力
- **开发友好**: 保持默认角色，支持场景独立运行

## 架构设计

### 数据流

```
GameConfig.CHARACTERS (配置)
         ↓
GameData.selected_character (选择)
         ↓
GameData.init_character() (初始化)
         ↓
GameData.player_stats (运行时属性)
         ↓
player.gd (使用属性)
```

### 核心组件

#### 1. 配置层（GameConfig）

**新增 CHARACTERS 配置：**

```gdscript
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

**角色差异化：**
- **战士**: 平衡型，高血量高伤害，速度中等
- **游侠**: 敏捷型，低血量，高速度和攻速
- **坦克**: 肉盾型，超高血量，自带回血，速度慢

#### 2. 状态层（GameData）

**新增字段：**
```gdscript
var selected_character: String = "warrior"  # 默认角色
```

**新增方法：**
```gdscript
func init_character(character_id: String):
    selected_character = character_id
    var char_config = GameConfig.CHARACTERS[character_id]

    player_stats = {
        "max_hp": char_config["max_hp"],
        "speed": char_config["speed"],  # 存储最终值
        "hp_regen": char_config["hp_regen"],
        "damage_mult": char_config["damage_mult"],
        "attack_speed_mult": char_config["attack_speed_mult"],
        "move_speed_mult": char_config["move_speed_mult"],
        "tower_mult": 1.0
    }
```

**修改现有方法：**
```gdscript
func _ready():
    init_character(selected_character)

func reset():
    init_character(selected_character)
    coins = GameConfig.PLAYER["initial_coins"]
    current_wave = 0
    tower_inventory = []
    purchased_towers = []
    pending_heal = 0
```

**关键变更：player_stats 存储策略**
- **之前**: 存储倍率（`move_speed_mult`），需要与基础值计算
- **之后**: 存储最终值（`speed`），直接使用
- **原因**: 简化代码，提高可读性，商店升级更直观

#### 3. UI 层（角色选择界面）

**新建文件：**
- `scenes/ui/character_select.tscn`
- `scripts/character_select.gd`

**界面结构：**
```
CharacterSelect (Control)
├── Label (标题："选择角色")
├── VBoxContainer (角色按钮容器)
│   ├── Button (战士)
│   ├── Button (游侠)
│   └── Button (坦克)
└── Label (角色描述显示区)
```

**交互逻辑：**
1. 显示所有可选角色按钮
2. 点击角色 → 显示详细属性和描述
3. 再次点击确认 → 调用 `GameData.init_character(character_id)`
4. 切换到武器选择界面

**场景流程变更：**
```
之前: 开始菜单 → 武器选择 → 布置场景 → ...
之后: 开始菜单 → 角色选择 → 武器选择 → 布置场景 → ...
```

#### 4. 玩家层（player.gd）

**修改属性读取：**

```gdscript
# 之前
speed = GameConfig.PLAYER["initial_speed"] * GameData.player_stats["move_speed_mult"]

# 之后
speed = GameData.player_stats["speed"]
```

**简化原因：**
- `player_stats["speed"]` 已经是角色的最终速度
- 不需要从 `GameConfig.PLAYER` 读取基础值
- 商店升级直接修改 `player_stats["speed"]`

#### 5. 商店系统调整

**速度升级改为固定值：**

```gdscript
# 之前（百分比）
GameData.player_stats["move_speed_mult"] += 0.1  # +10%

# 之后（固定值）
GameData.player_stats["speed"] += 20.0  # +20 速度
```

**优点：**
- 更直观的数值反馈
- 避免后期指数增长
- 更容易平衡

## 实施计划

### 阶段 1：配置和数据层
1. 在 `game_config.gd` 添加 `CHARACTERS` 配置
2. 修改 `game_data.gd` 添加 `selected_character` 和 `init_character()`
3. 修改 `player_stats` 存储策略（倍率 → 最终值）

### 阶段 2：角色选择界面
1. 创建 `character_select.tscn` 场景
2. 创建 `character_select.gd` 脚本
3. 实现角色选择逻辑
4. 修改开始菜单跳转到角色选择

### 阶段 3：玩家和商店调整
1. 修改 `player.gd` 的属性读取逻辑
2. 修改 `shop_manager.gd` 的速度升级逻辑
3. 测试所有角色的属性应用

### 阶段 4：测试和平衡
1. 测试三个角色的完整游戏流程
2. 调整角色数值平衡
3. 验证商店升级正确应用

## 测试验证

### 功能测试
- [ ] 角色选择界面正常显示
- [ ] 选择不同角色后属性正确应用
- [ ] 场景切换流程正常
- [ ] 商店升级正确修改属性
- [ ] 波次间属性保持正确

### 平衡测试
- [ ] 三个角色都能通关 10 波
- [ ] 角色差异明显但不极端
- [ ] 商店升级对不同角色都有意义

### 回归测试
- [ ] 现有武器系统不受影响
- [ ] 塔布置系统不受影响
- [ ] 波次系统不受影响

## 未来扩展

### 短期（1-2 个月）
- 添加更多角色（4-6 个）
- 角色图标和视觉差异
- 角色解锁机制

### 中期（3-6 个月）
- 引入 CharacterData Resource
- 角色被动能力系统
- 角色专属武器/塔

### 长期（6+ 个月）
- 角色主动技能
- 角色成长树
- 角色皮肤系统

## 风险和限制

### 技术风险
- **低**: 改动集中在配置和数据层，不涉及核心逻辑
- **player_stats 结构变更**: 需要仔细测试所有使用 player_stats 的地方

### 设计限制
- 当前只支持数值差异，不支持特殊能力
- 角色切换需要重新开始游戏（不支持局内切换）
- 所有角色共享相同的武器和塔系统

### 性能影响
- **无**: 只是配置读取，不影响运行时性能

## 文档更新

需要更新的文档：
- `docs/ARCHITECTURE.md` - 添加角色系统说明
- `docs/GAME_DESIGN.md` - 添加角色设计和平衡
- `docs/CONFIGURATION.md` - 添加 CHARACTERS 配置说明
- `CLAUDE.md` - 更新核心架构说明

## 总结

这个设计采用了**最小改动 + 配置驱动**的策略，在不破坏现有架构的前提下，为游戏添加了角色系统。通过将 `player_stats` 改为存储最终值而非倍率，简化了代码逻辑，提高了可维护性。

设计为未来扩展预留了空间（Resource 系统、被动能力），但不会过度设计。预计 1-2 天完成实施，风险低，收益高。
