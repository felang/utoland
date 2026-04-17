# #3 塔耐久 + 拆塔者 — 设计文档

## 概述

为塔系统引入耐久机制，并新增"拆塔者"敌人类型。拆塔者不追英雄，直奔最近的塔进行接触伤害，逼迫玩家主动拦截保护塔阵。

**简化决策（相对原始设计文档）：**
- 不做降级机制：塔 HP 归零直接摧毁
- 不做残骸/重建：摧毁即永久移除
- 保留波间恢复 30% max_hp

## 一、EnemyData 扩展

### 新字段

```
targets_towers: bool = false
```

启用后敌人优先寻找并攻击最近的塔，没有塔时退化为追玩家。默认 false，现有所有敌人不受影响。

### Enums 扩展

`Enums.Enemy` 新增 `TOWER_BREAKER`。

## 二、拆塔者敌人

### 数据配置（`resources/enemies/tower_breaker.tres`）

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `"tower_breaker"` | |
| hp | 普通怪 ~3 倍 | 中等偏高，需要集火才能拦截 |
| speed | 与 normal 相同 | 中等移速 |
| damage | 中高 | 对塔接触伤害有威胁感 |
| targets_towers | true | 优先追塔 |
| exp_drop | 高于普通怪 | 奖励成功拦截 |
| is_boss | false | |

具体数值在实施阶段参考现有 `normal.tres` / `tank.tres` 比例确定。

### 场景（`scenes/entities/enemies/enemy_tower_breaker.tscn`）

复用标准敌人场景结构：

```
CharacterBody2D (enemy.gd)
├── SpriteAnimator
├── HealthComponent
├── KnockbackHandler
├── SlowHandler
├── Hitbox (Area2D, layer=EnemyAttack)
├── Hurtbox (Area2D, layer=EnemyHurt)
└── CollisionShape2D
```

视觉用占位色块（区别于普通敌人的颜色），后续美术替换。

### SceneFactory 注册

- 注册 `tower_breaker` 场景和 EnemyData 加载
- 不走对象池（低频特殊怪）

## 三、enemy.gd 寻塔 AI

### 目标选择逻辑

在 `_physics_process` 移动目标选择中增加分支：

```
if data.targets_towers:
    _target = 最近的存活塔（从 "towers" 分组获取）
    if 没有塔:
        _target = player（退化为追玩家）
else:
    _target = player（现有逻辑，不变）
```

### 寻塔刷新策略

- 每 0.5 秒重新评估最近的塔（`_target_refresh_timer` 计时），避免每帧遍历和频繁切换
- 目标塔被摧毁时立即重新评估（监听目标的 `tree_exiting` 信号）

### 碰撞交互

- 拆塔者 Hitbox 在 EnemyAttack 层(6)，塔 Hurtbox 在 DefenderHurt 层(7)
- 碰撞矩阵已配好，走到塔旁边自然触发接触伤害
- 塔 Hurtbox 的 `repeat_damage` 模式已启用（`repeat_interval=1.0`），持续造成伤害

### 不改动的部分

- 击退、减速、定身、精英化等现有机制全部照常生效
- 玩家可用控制技能（疾风箭减速、箭雨击退等）拦截拆塔者
- 死亡掉经验球逻辑不变

## 四、塔耐久视觉反馈

### 受击反馈

- 使用现有 `EffectsManager.flash_hit()` 做受击红闪
- 塔受伤后显示血条，满血时隐藏

### 低血量警告

- HP < 30% 时精灵持续红色 tint（`modulate = Color(1, 0.5, 0.5)`）
- HP 恢复到 30% 以上时恢复正常颜色
- 在 `tower.gd` 中监听 `HealthComponent.damaged` 信号，检查 HP 比例更新视觉状态

### 塔摧毁流程

1. HP 归零 → `HealthComponent.died` 信号
2. `tower.gd` 处理：
   - 播放死亡特效（`EffectsManager.spawn_death_effect`）
   - 发射 `EventBus.tower_destroyed(tower_type, position, deploy_id)` 信号（新增 `deploy_id` 参数）
   - `queue_free()`
3. `main.gd`（或监听 `tower_destroyed` 的系统）负责联动清理：
   - 调用 `InventoryManager.remove_destroyed_tower(deploy_id)` 移除部署记录
   - 调用 `DragManager._remove_tower_node(deploy_id)` 移除节点引用

### InventoryManager 联动

- 塔被摧毁时从 `deployed_towers` 中移除对应记录
- `DragManager._tower_nodes` 中移除引用
- 同类塔计数减少（影响下次购买同类塔的价格递增）

## 五、波间恢复

### 触发时机

`wave_completed` 信号触发时（在 `main.gd` 或 `WaveManager` 中）。

### 恢复逻辑

- 遍历 `towers` 分组所有存活塔
- 每座塔恢复 30% max_hp
- 恢复后同步更新血条显示和 tint 状态

### HealthComponent 扩展

新增 `heal(amount: float)` 方法：

```
func heal(amount: float) -> void:
    current_hp = min(current_hp + amount, max_hp)
```

## 六、波次配置

### 拆塔者出现规则

- 第 1-7 波：不出现
- 第 8 波起：`enemy_weights` 中加入 `tower_breaker`，权重 ~5-8%（低频）
- 第 8 波首次出现约 1-2 只
- 之后逐波缓慢增加但始终保持低频
- Boss 波可搭配少量拆塔者增加压力

### 设计意图

拆塔者作为"警报事件"而非"常态消耗"，每次出现制造紧张感，逼迫玩家做出走位决策（是继续输出还是去拦截拆塔者）。

## 七、测试策略

### 单元测试

| 测试 | 验证内容 |
|------|---------|
| `test_tower_breaker_targets_tower` | 拆塔者优先追塔而非玩家 |
| `test_tower_breaker_fallback_to_player` | 没塔时退化追玩家 |
| `test_tower_breaker_retarget_on_destroy` | 目标塔被毁后切换最近的塔 |
| `test_tower_hp_damage` | 塔受伤 HP 正确扣减 |
| `test_tower_destroyed_on_zero_hp` | HP 归零触发摧毁 + InventoryManager 移除 |
| `test_tower_heal_between_waves` | 波间恢复 30% max_hp，不超上限 |
| `test_health_component_heal` | heal() 方法正确性 |
| `test_tower_low_hp_visual` | HP < 30% 时 modulate 变色 |

### 集成测试

| 测试 | 验证内容 |
|------|---------|
| `test_tower_breaker_flow` | 生成拆塔者 → 移向塔 → 造成伤害 → 塔摧毁 → 转追玩家 |

## 八、改动范围汇总

| 文件 | 改动 |
|------|------|
| `scripts/resources/enemy_data.gd` | 新增 `targets_towers: bool` |
| `scripts/entities/enemies/enemy.gd` | 寻塔 AI 分支 + 目标刷新计时 |
| `scripts/entities/towers/tower.gd` | 受损视觉反馈 + 摧毁联动 |
| `scripts/components/health_component.gd` | 新增 `heal()` 方法 |
| `scripts/core/scene_factory.gd` | 注册 tower_breaker |
| `scripts/core/inventory_manager.gd` | 塔摧毁时移除部署记录 |
| `scripts/systems/drag_manager.gd` | 塔摧毁时移除节点引用 |
| `scripts/ui/main.gd` 或 `wave_manager.gd` | 波间恢复逻辑 |
| `resources/enemies/tower_breaker.tres` | 新增拆塔者数据 |
| `scenes/entities/enemies/enemy_tower_breaker.tscn` | 新增拆塔者场景 |
| `resources/waves/*/` | 第 8 波起加入 tower_breaker 权重 |
| `scripts/core/enums.gd` | 新增 TOWER_BREAKER |
| 测试文件 | 8 个单元测试 + 1 个集成测试 |
