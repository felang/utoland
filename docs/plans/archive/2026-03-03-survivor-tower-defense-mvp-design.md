# 幸存者+阵地战游戏 MVP 设计文档

> **文档版本**：v1.0
> **创建日期**：2026-03-03
> **设计目标**：基于游戏策划案，制定三阶段渐进式开发计划

---

## 一、设计概述

### 1.1 核心定位
结合 Brotato 式自动射击幸存者玩法与植物大战僵尸式阵地建设，打造"走位风筝+塔防火力网"的独特战斗体验。

### 1.2 核心爽点
满屏怪物追杀下，玩家通过走位将怪物引入精心布置的植物塔火力网与减速区中绞杀。

### 1.3 技术选型
- **引擎**：Godot 4.6 (2D)
- **开发方式**：充分利用 GDAI MCP 工具，AI 直接操作编辑器
- **美术风格**：纯占位符（ColorRect、简单几何图形）
- **开发周期**：6-9 天，分三阶段迭代

---

## 二、整体架构设计

### 2.1 核心场景结构
```
Main (主场景)
├── Player (玩家 - CharacterBody2D)
├── Camera2D (跟随摄像机)
├── WaveManager (波次管理器 - Node)
├── EnemySpawner (敌人生成器 - Node)
├── TowerManager (植物塔管理器 - Node)
└── UI (用户界面层)
    ├── HUD (血条、波次倒计时、金币)
    ├── ShopUI (商店界面)
    └── ResultUI (结算界面)
```

### 2.2 核心脚本架构
| 脚本文件 | 职责 |
|---------|------|
| `player.gd` | 玩家移动、血量、自动射击逻辑 |
| `enemy.gd` | 敌人基类，追击玩家或攻击植物塔 |
| `tower.gd` | 植物塔基类，血量、攻击、阻挡 |
| `weapon.gd` | 武器基类，自动索敌和射击 |
| `bullet.gd` | 子弹碰撞和伤害 |
| `wave_manager.gd` | 波次倒计时、刷怪控制、商店触发 |
| `shop_manager.gd` | 商店刷新、购买逻辑 |
| `coin.gd` | 金币掉落和自动吸附 |

### 2.3 碰撞层设计（关键）
| Layer | 用途 | 碰撞规则 |
|-------|------|---------|
| Layer 1 | 玩家 | 与敌人碰撞（受伤），穿透植物塔 |
| Layer 2 | 敌人 | 被植物塔阻挡，可触碰玩家 |
| Layer 3 | 植物塔 | 阻挡敌人，不阻挡玩家 |
| Layer 4 | 玩家子弹 | 穿透植物塔，命中敌人 |
| Layer 5 | 金币/拾取物 | 玩家靠近自动吸附 |

**关键碰撞逻辑**：
- 玩家子弹：穿透植物塔，命中敌人
- 敌人：被植物塔阻挡（碰撞后切换攻击目标），可触碰玩家
- 植物塔：阻挡敌人，不阻挡玩家和子弹

---

## 三、三阶段开发计划

### 阶段 1：核心战斗原型（2-3天）

#### 功能范围
**包含**：
- 玩家 WASD 移动 + 摄像机跟随
- 单一武器（速射枪）自动射击最近敌人
- 单一敌人类型（普通怪）从屏幕边缘生成并追击玩家
- 3 个预设位置的坚果墙（纯阻挡，测试怪物碰撞转移仇恨）
- 简单 HUD：玩家血条、倒计时 60 秒
- 胜利条件：撑过 60 秒
- 失败条件：血量归零

**不包含**：
- 商店系统
- 金币和经验
- 多种武器/怪物/植物塔
- 完整 UI 界面

#### 实现细节

**玩家系统**：
- `CharacterBody2D`，初始速度 200px/s
- HP: 100，受击后 0.5 秒无敌时间
- 武器射程：300px，射速：0.1s/发，伤害：10

**敌人系统**：
- `CharacterBody2D`，速度 150px/s
- HP: 30，触碰伤害：10
- 在摄像机视口外 100px 随机生成
- 每 5 秒生成 1 只，最多同屏 20 只
- 追击逻辑：`velocity = position.direction_to(player.position) * speed`
- 碰到植物塔时：停止移动，切换为攻击塔（每秒 5 伤害）

**植物塔系统**：
- 坚果墙：`StaticBody2D`，HP: 300
- 预设在地图中央附近的 3 个固定位置
- 被摧毁后消失

**地图**：
- 2000x2000px 的开阔平面，纯色背景
- 摄像机限制在地图边界内

#### 验证目标
- 核心手感：走位是否流畅，自动射击是否准确
- 怪物追击：简单向量寻路是否自然
- 塔阻挡机制：怪物是否正确切换攻击目标
- 生存压力：60 秒内是否有足够的紧张感

---

### 阶段 2：完整战斗循环（2-3天）

#### 功能范围
**在阶段 1 基础上新增**：
- 3 种敌人类型（普通/快速/肉盾）
- 3 种植物塔类型（豌豆射手/坚果墙/冰雪菇）
- 10 波次渐进难度系统
- 金币掉落、自动吸附和计数
- 波次结束自动清屏和金币飞向玩家
- 完善的 HUD（金币数、当前波次）

#### 实现细节

**敌人类型扩展**：
| 类型 | HP | 速度 | 触碰伤害 | 战术特点 |
|------|----|----|---------|---------|
| 普通怪 | 30 | 150px/s | 10 | 基础单位，数量多 |
| 快速怪 | 20 | 250px/s | 8 | 速度大于玩家基准，逼迫使用塔 |
| 肉盾怪 | 150 | 100px/s | 15 | 高血量，测试 DPS |

**植物塔类型扩展**：
| 类型 | HP | 效果 | 成本 | 战术用途 |
|------|----|----|------|---------|
| 豌豆射手 | 80 | 射程 250px，伤害 10/秒 | 30 金币 | 补足输出 |
| 坚果墙 | 300 | 无攻击，纯阻挡 | 40 金币 | 逼迫怪物绕路 |
| 冰雪菇 | 70 | 光环半径 200px，减速 50% | 35 金币 | 风筝控制 |

**波次设计**（基于策划案）：
| 波次 | 时长 | 怪物构成 | 生成间隔 | 同屏上限 | 战术体验 |
|------|------|---------|---------|---------|---------|
| 1-3 波 | 45 秒 | 只有普通怪 | 4 秒 | 15 只 | 热身，积攒金币 |
| 4-6 波 | 50 秒 | 普通+快速怪(3:1) | 3 秒 | 25 只 | 逼迫使用塔拉扯 |
| 7-9 波 | 60 秒 | 三种混合(2:1:1) | 2 秒 | 35 只 | 测试 DPS 和塔耐久 |
| 10 波 | 60 秒 | 三种混合(1:1:1) | 1 秒 | 50 只 | 大决战，满屏压力 |

**金币系统**：
- 敌人死亡掉落 1-3 金币（`Area2D` 节点）
- 玩家靠近 150px 自动吸附
- 波次结束时，所有金币以 500px/s 速度飞向玩家并自动拾取

#### 验证目标
- 难度曲线：10 波是否有明显的递进感
- 怪物多样性：三种怪物是否带来不同的战术压力
- 植物塔价值：三种塔是否各有用途
- 经济系统：金币获取和消耗是否平衡

---

### 阶段 3：商店与成长系统（2-3天）

#### 功能范围
**在阶段 2 基础上新增**：
- 完整的开始界面、角色选择、武器选择流程
- 初始布置期（50 金币预算，网格摆放植物塔）
- 波次结束后的商店界面
- 局间布置期（摆放新购买的植物塔）
- 6 种被动属性强化系统
- 2 种初始武器选择
- 胜利/失败结算界面

#### 实现细节

**游戏流程**：
```
StartMenu → CharacterSelect → WeaponSelect → InitialPlacement →
Battle(Wave 1) → Shop → PlacementPhase → Battle(Wave 2) → ... →
Battle(Wave 10) → ResultScreen
```

**武器系统**：
| 武器 | 射速 | 伤害 | 射程 | 特性 |
|------|------|------|------|------|
| 速射枪 | 0.1s/发 | 10 | 300px | 高频清理小怪 |
| 爆裂霰弹 | 1.5s/发 | 50 | 200px | 高伤害+击退效果 |

**商店系统**：
- 每波结束展示 4 个随机商品
- 刷新按钮：花费 10 金币重新随机
- 商品池权重：被动属性 60%，植物塔 30%，消耗品 10%

**被动属性商品**（策划案中的 6 种）：
| 属性 | 效果 | 价格 |
|------|------|------|
| 最大生命值 | +20 HP | 25 金币 |
| 生命回复 | +5 HP/5 秒 | 20 金币 |
| 伤害 | +10% | 30 金币 |
| 攻击速度 | +15% | 25 金币 |
| 移动速度 | +10% | 20 金币 |
| 工程学强度 | 塔血量和伤害 +20% | 35 金币 |

**植物塔商品**：
| 商品 | 价格 |
|------|------|
| 豌豆射手 x1 | 30 金币 |
| 坚果墙 x1 | 40 金币 |
| 冰雪菇 x1 | 35 金币 |

**消耗品**：
| 商品 | 效果 | 价格 |
|------|------|------|
| 医疗包 | 回复 50 HP | 15 金币 |

**布置系统**：
- 32x32px 网格吸附
- 鼠标悬停显示半透明预览
- 左键放置，右键取消
- 不能放置在已有塔或地图边界外
- 确认按钮进入下一波

**UI 界面**：
- `StartMenu`：标题 + 开始按钮
- `CharacterSelect`：MVP 只有 1 个角色（显示"默认角色"并直接跳过）
- `WeaponSelect`：2 个武器卡片选择
- `ResultScreen`：显示存活波次、击杀数、重新开始/退出按钮

#### 验证目标
- 完整流程：从开始到结算是否流畅
- 成长系统：被动属性是否带来明显的强度提升
- 策略深度：商店选择是否有决策价值
- 布置系统：网格摆放是否直观易用

---

## 四、核心技术实现要点

### 4.1 自动射击系统
```gdscript
# 伪代码示例
func auto_shoot():
    var enemies = get_tree().get_nodes_in_group("enemies")
    var closest_enemy = null
    var min_distance = weapon_range

    for enemy in enemies:
        var distance = global_position.distance_to(enemy.global_position)
        if distance < min_distance:
            min_distance = distance
            closest_enemy = enemy

    if closest_enemy and shoot_timer <= 0:
        shoot_bullet(closest_enemy.global_position)
        shoot_timer = weapon_fire_rate
```

### 4.2 敌人追击与仇恨转移
```gdscript
# 伪代码示例
enum State { CHASE_PLAYER, ATTACK_TOWER }
var current_state = State.CHASE_PLAYER
var target_tower = null

func _physics_process(delta):
    match current_state:
        State.CHASE_PLAYER:
            velocity = position.direction_to(player.position) * speed
            move_and_slide()
            # 检测是否碰到塔
            for i in get_slide_collision_count():
                var collision = get_slide_collision(i)
                if collision.get_collider().is_in_group("towers"):
                    current_state = State.ATTACK_TOWER
                    target_tower = collision.get_collider()

        State.ATTACK_TOWER:
            velocity = Vector2.ZERO
            if attack_timer <= 0:
                target_tower.take_damage(attack_damage)
                attack_timer = attack_rate
            # 塔被摧毁后继续追玩家
            if not is_instance_valid(target_tower):
                current_state = State.CHASE_PLAYER
```

### 4.3 波次结束清屏与金币吸附
```gdscript
# 伪代码示例
func on_wave_complete():
    # 清除所有敌人
    for enemy in get_tree().get_nodes_in_group("enemies"):
        enemy.die_and_drop_coin()

    # 所有金币飞向玩家
    for coin in get_tree().get_nodes_in_group("coins"):
        coin.fly_to_player(player.global_position, 500) # 500px/s
```

### 4.4 网格吸附布置系统
```gdscript
# 伪代码示例
const GRID_SIZE = 32

func snap_to_grid(pos: Vector2) -> Vector2:
    return Vector2(
        floor(pos.x / GRID_SIZE) * GRID_SIZE + GRID_SIZE / 2,
        floor(pos.y / GRID_SIZE) * GRID_SIZE + GRID_SIZE / 2
    )

func _input(event):
    if event is InputEventMouseMotion:
        var snapped_pos = snap_to_grid(get_global_mouse_position())
        preview_tower.global_position = snapped_pos
        preview_tower.modulate = Color.GREEN if can_place(snapped_pos) else Color.RED
```

---

## 五、开发里程碑与交付物

### 阶段 1 交付物（第 3 天）
- [x] 可运行的单波次战斗原型
- [x] 玩家移动+自动射击+敌人追击
- [x] 预设塔阻挡机制验证
- [x] 简单 HUD 显示

### 阶段 2 交付物（第 6 天）
- [x] 10 波次完整战斗循环
- [x] 3 种敌人、3 种植物塔
- [x] 金币掉落和拾取系统
- [x] 难度曲线调试完成

### 阶段 3 交付物（第 9 天）
- [x] 完整游戏流程（开始→战斗→商店→结算）
- [x] 2 种武器、6 种被动属性
- [x] 初始布置期和局间布置期
- [x] 完整 UI 界面

---

## 六、风险与应对

### 6.1 性能风险
**风险**：同屏 50 只怪物可能导致帧率下降
**应对**：
- 使用对象池复用敌人节点
- 简化碰撞形状（使用圆形而非多边形）
- 必要时降低同屏上限

### 6.2 手感风险
**风险**：自动射击可能让玩家感觉"无聊"
**应对**：
- 阶段 1 重点调试移动速度和射击反馈
- 增加视觉和音效反馈（即使是占位符也要有明显的击中效果）
- 通过怪物数量和速度制造压迫感

### 6.3 平衡性风险
**风险**：金币获取和消耗可能不平衡
**应对**：
- 阶段 2 重点测试经济系统
- 记录每波获得的金币和商店消耗
- 预留调整空间（金币掉落数量、商品价格都可配置）

---

## 七、后续扩展方向（MVP 之后）

1. **美术替换**：将占位符替换为像素风格或卡通风格的精灵图
2. **音效音乐**：添加射击、受击、波次开始等音效
3. **更多内容**：更多武器、植物塔、敌人类型
4. **Roguelike 元素**：永久解锁、天赋树、随机事件
5. **多人模式**：合作生存或竞技模式

---

## 八、总结

本设计文档基于游戏策划案，采用三阶段渐进式开发策略：

1. **阶段 1**：验证核心手感（走位+射击+追击+塔阻挡）
2. **阶段 2**：完善战斗循环（多样性+难度曲线+经济系统）
3. **阶段 3**：补全游戏流程（商店+成长+完整 UI）

每个阶段都有明确的功能范围和验证目标，确保开发过程可控、可测试。利用 GDAI MCP 工具可以加速场景搭建和脚本编写，预计 6-9 天完成 MVP。

**核心设计优势**：
- 无需复杂寻路算法，降低开发成本
- 简单向量追击支持同屏大量怪物
- 塔阻挡+玩家风筝的独特战术体验
- 分阶段迭代降低风险，每阶段都可独立测试

---

**文档结束**
