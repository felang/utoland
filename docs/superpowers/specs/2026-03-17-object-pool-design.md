# 对象池系统设计

## 概述

为 SceneFactory 增加内部对象池机制，管理高频创建/销毁的游戏对象（投射物、普通敌人、金币、经验球），减少 `instantiate()` / `queue_free()` 的开销。预防性优化，对外 API 基本不变。

## 决策记录

| 决策项 | 选择 | 理由 |
|--------|------|------|
| 池化范围 | 投射物 + 普通敌人(normal/fast/tank) + 金币 + 经验球 | Boss/塔/武器频率低不值得；特效粒子极轻量收益有限 |
| 架构位置 | 集成到 SceneFactory 内部 | 对外接口不变，调用方零改动 |
| 回收方式 | 显式调用 `release_*()` | 最直接可控，销毁点有限 |
| 预热时机 | 场景加载基础预热 + 每波动态补充 | 覆盖冷启动 + 适应难度递增 |
| 池管理模式 | PoolEntry 独立管理 + 实体 `reset_for_pool()` | 预热配置集中，重置逻辑内聚在实体自身 |

## 池核心结构

### PoolEntry 内部类

```gdscript
class PoolEntry:
    var scene: PackedScene          # 对应的 PackedScene
    var idle_queue: Array[Node] = [] # 空闲对象队列
    var active_count: int = 0       # 当前活跃数
    var warmup_count: int = 0       # 预热数量
```

### SceneFactory 池化字典

```gdscript
var _pools: Dictionary = {}  # Dictionary[String, PoolEntry]
```

Key 格式：`"enemy_normal"`, `"enemy_fast"`, `"enemy_tank"`, `"projectile_<type>"`, `"coin"`, `"exp_orb"`

### 核心内部方法

```gdscript
# 注册池类型（_ready 中调用）
func _register_pool(key: String, scene: PackedScene, warmup: int = 0) -> void

# 通用获取：优先从空闲队列取，否则 instantiate 新建
func _pool_acquire(key: String) -> Node

# 通用回收：重置状态 → 从场景树移除 → 放入空闲队列
func _pool_release(key: String, obj: Node) -> void

# 预热：批量 instantiate 并放入空闲队列（不加入场景树）
func _pool_warmup(key: String, count: int) -> void
```

### 获取流程

```
_pool_acquire(key):
  1. idle_queue 非空 → pop_back() → active_count += 1
  2. idle_queue 为空 → scene.instantiate() → active_count += 1
  3. 返回对象（调用方负责 add_child 和注入数据）
```

### 回收流程

```
_pool_release(key, obj):
  1. 未注册的 key → obj.queue_free() 兜底
  2. obj.reset_for_pool()  ← 对象自身重置状态
  3. obj.get_parent() 存在 → remove_child(obj)
  4. obj.set_process(false) / set_physics_process(false)
  5. idle_queue.push_back(obj)
  6. active_count -= 1
```

## 实体状态重置

每个可池化实体实现 `reset_for_pool() -> void` 方法。

### 投射物 (ProjectileBase)

```gdscript
func reset_for_pool() -> void:
    if _trail:
        _trail.clear_points()
    _elapsed = 0.0
    _hit_count = 0
    _pierce_count = 0
    _direction = Vector2.ZERO
    _speed = 0.0
    visible = true
    hitbox.set_deferred("monitorable", true)
```

ShurikenProjectile 额外重置：`_bounce_target = null`, `_hit_enemies.clear()`, `_shuriken_hit_count = 0`

### 敌人 (enemy.gd)

```gdscript
func reset_for_pool() -> void:
    health.reset()              # HealthComponent 新增方法
    _knockback.kill_tween()
    slow_handler.clear_all()    # SlowHandler 新增方法
    if is_rooted:
        remove_root(_root_source)
    is_elite = false
    _coin_multiplier = 1.0
    _exp_multiplier = 1.0
    scale = Vector2.ONE
    _sprite_animator.reset()
    attack_timer = 0.0
    visible = true
    set_process(true)
    set_physics_process(true)
```

需要新增的组件方法：
- `HealthComponent.reset()` — 恢复 `current_hp = max_hp`，重置 `is_dead = false`
- `SlowHandler.clear_all()` — 断开所有 timer 信号，清空 `_active_slows` 和 `_timed_slow_timers`

### 金币 (coin.gd)

```gdscript
func reset_for_pool() -> void:
    value = 1
    is_attracted = false
    attract_speed = 200.0
    player = null
    visible = true
    modulate.a = 1.0
    scale = Vector2.ONE
    monitoring = true
```

### 经验球 (exp_orb.gd)

```gdscript
func reset_for_pool() -> void:
    value = 1
    is_attracted = false
    attract_speed = 200.0
    player = null
    visible = true
    modulate.a = 1.0
    scale = Vector2.ONE
    monitoring = true
```

## 预热机制

### A. 首次进入 main 场景 — 基础预热

`main.gd._ready()` 中调用 `SceneFactory.warmup_initial()`：

| 类型 | 数量 |
|------|------|
| 投射物（各类型） | 各 20 |
| enemy_normal | 10 |
| enemy_fast | 5 |
| enemy_tank | 3 |
| coin | 15 |
| exp_orb | 15 |

### B. 每波开始前 — 动态补充

`SceneFactory.warmup_for_wave(wave_data)` 在 `wave_started` 时调用：

- 根据 `wave_data.max_alive_enemies` 和 `enemy_weights` 按比例补充敌人池差额
- 投射物按 `max_alive_enemies * 2` 估算补充
- 金币和经验球按 `max_alive_enemies` 估算补充
- 只在空闲队列数量不足时补充差额

预热对象只做 `instantiate()` 放入空闲队列，不加入场景树。

## SceneFactory 对外 API 变更

### 不变的方法（内部改为走池）

- `create_enemy(type)` — 内部 `_pool_acquire("enemy_" + type)`，返回前注入 data
- `create_coin()` — 内部 `_pool_acquire("coin")`
- `create_exp_orb()` — 内部 `_pool_acquire("exp_orb")`
- `create_projectile(p_data, ...)` — 内部按 projectile 类型 key 走池

### 新增方法

- `release_enemy(enemy: CharacterBody2D) -> void`
- `release_coin(coin: Area2D) -> void`
- `release_exp_orb(orb: Area2D) -> void`
- `release_projectile(proj: ProjectileBase) -> void`
- `warmup_initial() -> void` — main 场景基础预热
- `warmup_for_wave(wave_data: WaveData) -> void` — 每波动态补充
- `clear_all_pools() -> void` — 游戏结束时清理所有池化对象

## 调用方改动点

| 位置 | 原代码 | 改为 |
|------|--------|------|
| `projectile_base._cleanup_and_free()` | `queue_free()` | `SceneFactory.release_projectile(self)` |
| `enemy._on_died()` | `queue_free()` | `SceneFactory.release_enemy(self)` |
| `wave_manager.clear_all_enemies()` | `enemy.queue_free()` | `SceneFactory.release_enemy(enemy)` |
| `coin._play_pickup_effect()` tween 回调 | `queue_free()` | `SceneFactory.release_coin(self)` |
| `exp_orb._play_pickup_effect()` tween 回调 | `queue_free()` | `SceneFactory.release_exp_orb(self)` |
| `main.gd._ready()` | 无 | 新增 `SceneFactory.warmup_initial()` |
| wave_started 处理 | 无 | 新增 `SceneFactory.warmup_for_wave(wave_data)` |
| 离开 main 场景时 | 无 | 新增 `SceneFactory.clear_all_pools()` |

## 边界情况处理

### `_ready()` 与复用

- `_ready()` 只在首次 instantiate 时调用，复用时不再触发
- `@onready` 引用首次建立后始终有效
- `_enter_tree()` / `_exit_tree()` 每次 add/remove 都会触发
- 敌人每次复用的初始化（HP、data 注入）由 `create_enemy()` 显式完成

### 信号连接

- 所有信号连接保留在 `_ready()` 中，复用时连接依然存在
- `reset_for_pool()` 不做信号操作，避免重复连接

### Tween 安全

- `KnockbackHandler.kill_tween()` 已有，直接调用
- 金币/经验球回收时机是 tween 回调点，tween 已完成
- 投射物无 tween

### 防御性检查

- `_pool_release()` 检查 `obj.get_parent()` 是否存在再 `remove_child()`
- 未注册的 key 走 `queue_free()` 兜底

### 池上限

- 不设硬性上限（峰值对象数量有限）
- 未来如需要可加 `max_idle` 参数

### 场景切换清理

- 池中空闲对象不在场景树中，不会随场景切换自动销毁
- 离开 main 场景时必须调用 `clear_all_pools()` 真正释放

### 敌人类型隔离

- 每种敌人类型独立池 key（`enemy_normal` / `enemy_fast` / `enemy_tank`）
- 不同类型场景结构不同，不能混用
