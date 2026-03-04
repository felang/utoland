# Utoland 项目状态

**最后更新**: 2026-03-03
**当前版本**: MVP v0.3
**项目类型**: 2D 塔防 + 生存射击游戏

---

## 项目概览

Utoland 是一个结合了塔防和生存射击元素的 2D 游戏。玩家需要在波次间布置防御塔，并在战斗中使用武器击败敌人，通过商店系统强化角色和防御。

---

## 完成的阶段

### ✅ 阶段1: 核心战斗系统
**完成日期**: 2026-03-01

**实现功能**:
- 玩家移动和射击
- 敌人生成和AI
- 碰撞检测
- 基础UI（生命值、金币）

**关键文件**:
- `scripts/player.gd`
- `scripts/enemy.gd`
- `scripts/bullet.gd`
- `scenes/main.tscn`

---

### ✅ 阶段2: 塔防系统
**完成日期**: 2026-03-02

**实现功能**:
- 三种防御塔：
  - 射手塔：自动攻击敌人
  - 墙塔：阻挡敌人移动
  - 减速塔：降低敌人速度
- 波次管理系统（10波）
- 金币掉落和收集
- 敌人寻路（导航网格）

**关键文件**:
- `scripts/tower_shooter.gd`
- `scripts/tower_wall.gd`
- `scripts/tower_slow.gd`
- `scripts/wave_manager.gd`
- `scripts/enemy_spawner.gd`

---

### ✅ 阶段3: 完整游戏循环
**完成日期**: 2026-03-03

**实现功能**:
- 开始菜单
- 武器选择系统（步枪/霰弹枪/狙击枪）
- 初始布置系统
- 商店系统（被动属性、塔、消耗品）
- 结算界面
- 完整场景流程整合
- 生命回复机制
- 霰弹枪多发子弹

**关键文件**:
- `scripts/game_data.gd` (全局单例)
- `scripts/start_menu.gd`
- `scripts/weapon_select.gd`
- `scripts/placement.gd`
- `scripts/shop_manager.gd`
- `scripts/result.gd`
- `scripts/main.gd`

**详细文档**: `docs/phase3-implementation-summary.md`

---

## 当前游戏功能

### 核心系统 ✅

#### 玩家系统
- [x] WASD 移动
- [x] 鼠标瞄准和射击
- [x] 生命值系统
- [x] 生命回复机制
- [x] 三种武器（步枪/霰弹枪/狙击枪）
- [x] 被动属性强化（生命、伤害、攻速、移速）

#### 敌人系统
- [x] 自动寻路（导航网格）
- [x] 碰撞伤害
- [x] 金币掉落
- [x] 减速效果

#### 塔防系统
- [x] 射手塔（自动攻击）
- [x] 墙塔（阻挡）
- [x] 减速塔（范围减速）
- [x] 塔布置系统（网格对齐、预览）
- [x] 塔位置保存和恢复

#### 波次系统
- [x] 10波敌人
- [x] 难度递进
- [x] 波次间商店

#### UI系统
- [x] 开始菜单
- [x] 武器选择界面
- [x] 布置界面
- [x] 商店界面
- [x] 结算界面
- [x] HUD（生命值、金币、波次）

#### 商店系统
- [x] 随机商品生成
- [x] 被动属性购买
- [x] 塔购买
- [x] 消耗品购买（医疗包）
- [x] 刷新机制

---

## 架构概览

### 场景结构
```
scenes/
├── ui/
│   ├── start_menu.tscn      # 开始菜单
│   ├── weapon_select.tscn   # 武器选择
│   ├── shop.tscn            # 商店
│   └── result.tscn          # 结算界面
├── placement.tscn           # 布置场景
├── main.tscn                # 主游戏场景
├── player.tscn              # 玩家
├── enemy.tscn               # 敌人
├── bullet.tscn              # 子弹
├── coin.tscn                # 金币
└── towers/
    ├── tower_shooter.tscn   # 射手塔
    ├── tower_wall.tscn      # 墙塔
    └── tower_slow.tscn      # 减速塔
```

### 核心脚本
```
scripts/
├── game_data.gd             # 全局单例（游戏状态）
├── main.gd                  # 主场景控制器
├── player.gd                # 玩家控制
├── enemy.gd                 # 敌人AI
├── bullet.gd                # 子弹逻辑
├── wave_manager.gd          # 波次管理
├── enemy_spawner.gd         # 敌人生成
├── placement.gd             # 布置系统
├── shop_manager.gd          # 商店管理
├── start_menu.gd            # 开始菜单
├── weapon_select.gd         # 武器选择
├── result.gd                # 结算界面
└── towers/
    ├── tower_shooter.gd     # 射手塔逻辑
    ├── tower_wall.gd        # 墙塔逻辑
    └── tower_slow.gd        # 减速塔逻辑
```

### 游戏流程
```
开始菜单
    ↓
武器选择（步枪/霰弹枪/狙击枪）
    ↓
布置场景（使用初始金币布置塔）
    ↓
战斗场景（第1波）
    ↓
波次完成 → 商店（购买升级/塔/消耗品）
    ↓
布置场景（布置新购买的塔）
    ↓
战斗场景（第2波）
    ↓
... 循环直到第10波或玩家死亡 ...
    ↓
结算界面（显示胜利/失败）
    ↓
返回开始菜单
```

### GameData 单例
管理所有跨场景的游戏状态：
- `selected_weapon`: 选择的武器类型
- `player_stats`: 玩家属性字典（生命、伤害、攻速、移速等）
- `coins`: 当前金币
- `current_wave`: 当前波次
- `tower_inventory`: 已布置的塔 `[{type, position}, ...]`
- `purchased_towers`: 商店购买的塔类型 `["shooter", ...]`
- `pending_heal`: 待处理的治疗量

---

## 已知问题

详细列表见 `docs/known-issues.md`

### Important 级别
1. 霰弹枪伤害平衡问题（DPS过高）
2. 生命回复计时器未重置

### Minor 级别
1. 魔法数字硬编码
2. 塔类型识别脆弱
3. 缺少边界检查
4. 代码注释不足

### 待测试问题
- 用户手工测试发现的问题（待记录）

---

## 技术栈

- **引擎**: Godot 4.6
- **语言**: GDScript
- **版本控制**: Git
- **分辨率**: 1920x1080（全屏）

---

## 游戏平衡参数

### 玩家
- 初始生命值: 100
- 移动速度: 200
- 初始金币: 100

### 武器
- 步枪: 射速 0.1s, 伤害 10.0, 单发
- 霰弹枪: 射速 0.5s, 伤害 8.0x5, 扇形散射
- 狙击枪: 射速 1.0s, 伤害 30.0, 单发

### 塔
- 射手塔: 价格 25-30, 射程 300, 伤害 15, 射速 1.0s
- 墙塔: 价格 25-30, 生命值 200
- 减速塔: 价格 25-30, 射程 200, 减速 30%

### 商店
- 被动升级: 15-30 金币
- 塔: 25-30 金币
- 医疗包: 12 金币
- 刷新: 10 金币

### 敌人
- 金币掉落: 2-5
- 波次难度递进

---

## 下一步计划

### 短期（修复和优化）
1. 修复已知 Important 问题
2. 处理用户测试发现的问题
3. 完整10波通关测试
4. 平衡性调整

### 中期（内容扩展）
1. 更多武器类型
2. 更多塔类型
3. 更多敌人类型
4. Boss 战

### 长期（体验优化）
1. 音效系统
2. 视觉特效
3. 成就系统
4. 难度选择

---

## 开发统计

- **总开发时间**: 3个会话
- **总提交数**: ~30+
- **代码行数**: ~2000 行（估算）
- **场景文件数**: 15+
- **脚本文件数**: 20+

---

## 如何运行

1. 使用 Godot 4.6 打开项目
2. 主场景: `scenes/ui/start_menu.tscn`
3. 按 F5 运行游戏

---

## 相关文档

- `docs/plans/2026-03-03-survivor-tower-defense-phase3.md` - 阶段3计划
- `docs/phase3-implementation-summary.md` - 阶段3实施总结
- `docs/known-issues.md` - 已知问题清单
