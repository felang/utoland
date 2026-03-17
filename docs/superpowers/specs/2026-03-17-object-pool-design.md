# 对象池系统设计

## 概述

为 SceneFactory 增加内部对象池机制，管理高频创建/销毁的游戏对象（投射物、普通敌人、金币、经验球），减少 `instantiate()` / `queue_free()` 的开销。预防性优化，对外创建 API 不变，新增 `release_*()` 回收方法。

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

Key 格式：`"enemy_normal"`, `"enemy_fast"`, `"enemy_tank"`, `"coin"`, `"exp_orb"`

投射物 key 从 `ProjectileData.projectile_scene` 的资源路径派生：`"projectile_" + p_data.projectile_scene.resource_path.get_file().get_basename()`

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
  1. idle_queue 非空 → pop_back()
  2. idle_queue 为空 → scene.instantiate()
  3. obj._is_pooled = false  ← 清除池化标记
  4. obj.set_process(true) / set_physics_process(true)  ← 池统一启用
  5. active_count += 1
  6. 返回对象（调用方负责 add_child 和注入数据）
```

### 回收流程

```
_pool_release(key, obj):
  1. 未注册的 key → obj.queue_free() 兜底
  2. obj._is_pooled == true → return（防止双重回收）
  3. obj.reset_for_pool()  ← 对象自身重置状态
  4. obj._is_pooled = true  ← 标记已入池
  5. obj.get_parent() 存在 → remove_child(obj)
  6. obj.set_process(false) / set_physics_process(false)  ← 池统一禁用
  7. idle_queue.push_back(obj)
  8. active_count -= 1
```

**process 启用/禁用职责归属**：统一由池管理（`_pool_acquire` 启用、`_pool_release` 禁用）。实体的 `reset_for_pool()` 不操作 process 状态。

**双重回收防护**：每个可池化实体增加 `var _is_pooled: bool = false` 字段。`_pool_release()` 检查此标记，防止同一对象被回收两次（如敌人死亡 `_on_died()` 和波次清场 `clear_all_enemies()` 同时触发）。

## 实体状态重置

每个可池化实体实现 `reset_for_pool() -> void` 方法。

### 投射物 (ProjectileBase)

**问题**：当前 `setup()` 每次调用都会 `add_child()` 新的 Sprite2D 和 Line2D，并重复连接 `hitbox.area_entered` 信号。池化复用时会导致子节点堆积和信号重复连接。

**解决方案**：重构 `setup()` 为幂等模式——检查子节点是否已存在，存在则复用而非重建；信号连接前先断开旧连接。

```gdscript
# 重构后的 setup()（伪代码，展示关键变更）
func setup(p_data, damage, from, direction, extra_pierce) -> void:
    data = p_data
    global_position = from
    _direction = direction
    _speed = data.speed
    _lifetime = data.lifetime
    _pierce_count = data.base_pierce_count + extra_pierce
    _hit_count = 0
    _elapsed = 0.0
    hitbox = get_node_or_null("Hitbox") as Hitbox
    hitbox.damage = damage
    hitbox.knockback_force = data.knockback_force
    # 精灵：先清理旧的动态 Sprite2D，再创建新的
    _cleanup_dynamic_sprite()
    if data.sprite_path != "" and ResourceLoader.exists(data.sprite_path):
        var sprite := Sprite2D.new()
        sprite.name = "_PooledSprite"
        sprite.texture = load(data.sprite_path)
        sprite.rotation = direction.angle()
        add_child(sprite)
    # 拖尾：先清理旧的，再按需创建
    _cleanup_trail()
    show_trail = data.trail_enabled
    if show_trail:
        _create_trail()
    # 信号：先断开再连接，防止重复
    if hitbox.area_entered.is_connected(_on_hitbox_area_entered):
        hitbox.area_entered.disconnect(_on_hitbox_area_entered)
    hitbox.area_entered.connect(_on_hitbox_area_entered)
```

```gdscript
func reset_for_pool() -> void:
    _cleanup_dynamic_sprite()
    _cleanup_trail()
    _trail_positions.clear()
    # 断开信号
    if hitbox and hitbox.area_entered.is_connected(_on_hitbox_area_entered):
        hitbox.area_entered.disconnect(_on_hitbox_area_entered)
    if hitbox and hitbox.area_entered.is_connected(_on_legacy_hitbox_area_entered):
        hitbox.area_entered.disconnect(_on_legacy_hitbox_area_entered)
    _elapsed = 0.0
    _hit_count = 0
    _pierce_count = 0
    _direction = Vector2.ZERO
    _speed = 0.0
    visible = true

func _cleanup_dynamic_sprite() -> void:
    var old_sprite = get_node_or_null("_PooledSprite")
    if old_sprite:
        remove_child(old_sprite)
        old_sprite.queue_free()

func _cleanup_trail() -> void:
    if _trail and is_instance_valid(_trail):
        remove_child(_trail)
        _trail.queue_free()
        _trail = null
```

ShurikenProjectile 额外重置：
```gdscript
func reset_for_pool() -> void:
    super.reset_for_pool()
    _bounce_target = null
    _hit_enemies.clear()
    _shuriken_hit_count = 0
    # 断开 shuriken 专用信号
    if hitbox and hitbox.area_entered.is_connected(_on_shuriken_hit):
        hitbox.area_entered.disconnect(_on_shuriken_hit)
```

### 敌人 (enemy.gd)

```gdscript
func reset_for_pool() -> void:
    # HealthComponent 重置
    health.reset()
    # 击退清理
    _knockback.kill_tween()
    # 减速清理 — 清除所有活跃减速，断开定时器信号
    slow_handler.clear_all()
    # 定身清理（remove_root() 无参数）
    if is_rooted:
        remove_root()
    # 精英状态重置
    if is_in_group("elites"):
        remove_from_group("elites")
    is_elite = false
    _elite_coin_mult = 1.0
    _elite_exp_mult = 1.0
    scale = Vector2.ONE
    # 状态机重置
    current_state = State.CHASE_PLAYER
    target_tower = null
    velocity = Vector2.ZERO
    attack_timer = 0.0
    # 动画重置到默认朝向
    if _sprite_animator._sprite:
        _sprite_animator._sprite.play("walk_down")
        _sprite_animator._current_anim = "walk_down"
    # 可见性
    visible = true
    modulate = Color.WHITE
```

**复用时由 `create_enemy()` 重新初始化的属性**：
```gdscript
func create_enemy(type: String) -> CharacterBody2D:
    var key := "enemy_" + type
    var enemy = _pool_acquire(key) if _pools.has(key) else _enemy_scenes[type].instantiate()
    enemy.enemy_type = type
    if GameConfig.enemies.has(type):
        enemy.data = GameConfig.enemies[type]
    # 从 Resource 重新初始化数值（覆盖精英缩放后的残留值）
    enemy.health.initialize(enemy.data.hp)
    enemy.speed = enemy.data.speed
    enemy.tower_attack_damage = enemy.data.damage
    enemy._hitbox.damage = enemy.data.damage
    enemy.slow_handler.initialize(enemy.data.speed)
    # 重新获取 player 引用
    enemy.player = null  # _process 中会重新获取（如果需要立即获取也可在此处）
    return enemy
```

**注意**：`_ready()` 中的信号连接（`health.died`, `slow_handler.speed_changed`, `$Hurtbox.hit_taken`）在首次 instantiate 后永久存在，复用时不需要也不能重新连接。`@onready` 节点引用同理。

**Root 定时器处理**：`apply_root()` 创建的 `SceneTreeTimer` 无法取消，但 `remove_root()` 已有 `if not is_rooted: return` 守卫。回收时调用 `remove_root()` 将 `is_rooted` 设为 false，即使旧定时器后续触发也会被守卫拦截。

需要新增的组件方法：

**HealthComponent.reset()**：
```gdscript
func reset() -> void:
    current_hp = max_hp
    invincible = false
    damage_reduction = 0.0
```

**SlowHandler.clear_all()**：
```gdscript
func clear_all() -> void:
    # 先断开所有定时器信号，再清空字典
    for source_id in _timed_slow_timers:
        var timer = _timed_slow_timers[source_id]
        if timer and is_instance_valid(timer):
            if timer.timeout.is_connected(_on_timed_slow_expired.bind(source_id)):
                timer.timeout.disconnect(_on_timed_slow_expired.bind(source_id))
    _timed_slow_timers.clear()
    _active_slows.clear()
    # 不 emit speed_changed，因为 create_enemy 会重新 initialize
```

**注意**：`SceneTreeTimer` 无法被停止或释放，它会自然过期。`clear_all()` 断开信号后，旧定时器会无害地过期。但如果敌人在旧定时器过期前被复用并被施加新的同 source_id 减速，旧定时器的回调已断开，不会干扰新减速。

### 金币 (coin.gd)

```gdscript
func reset_for_pool() -> void:
    value = 1
    is_attracted = false
    attract_speed = 250.0  # @export 默认值
    attract_range = 75.0   # @export 默认值
    player = null          # _process 中自动重新获取
    visible = true
    modulate.a = 1.0
    scale = Vector2.ONE
    set_deferred("monitoring", true)
```

### 经验球 (exp_orb.gd)

```gdscript
func reset_for_pool() -> void:
    value = 1
    is_attracted = false
    attract_speed = 200.0  # @export 默认值
    attract_range = 30.0   # @export 默认值
    player = null          # _process 中自动重新获取
    visible = true
    modulate.a = 1.0
    scale = Vector2.ONE
    set_deferred("monitoring", true)
```

**注意**：金币和经验球的 `_ready()` 中连接 `body_entered` 信号和 `add_to_group()`。信号连接在对象生命周期内永久存在。Group 成员身份在 `remove_child()` 后依然保留在节点上，`get_nodes_in_group()` 只返回场景树中的节点，所以不会误匹配。

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

如果首次预热导致帧率卡顿（约 100 个对象），可改为跨帧异步预热（`await get_tree().process_frame`），但预计不需要。

### B. 每波开始前 — 动态补充

`SceneFactory.warmup_for_wave(wave_data)` 在 `wave_started` 时调用：

- 根据 `wave_data.max_alive_enemies` 和 `enemy_weights` 按比例补充敌人池差额
- 投射物按 `max_alive_enemies * 2` 估算补充
- 金币和经验球按 `max_alive_enemies` 估算补充
- 只在空闲队列数量不足时补充差额（`need = target - idle_queue.size()`, `if need > 0`）

预热对象只做 `instantiate()` 放入空闲队列，不加入场景树。

## SceneFactory 对外 API 变更

### 不变的方法（内部改为走池）

- `create_enemy(type)` — 内部 `_pool_acquire("enemy_" + type)`，返回前注入 data 并重新初始化数值
- `create_coin()` — 内部 `_pool_acquire("coin")`
- `create_exp_orb()` — 内部 `_pool_acquire("exp_orb")`
- `create_projectile(p_data, ...)` — 内部按投射物类型 key 走池，`setup()` 已重构为幂等

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
- 敌人每次复用的初始化（HP、speed、damage）由 `create_enemy()` 显式完成

### 信号连接

- 所有信号连接保留在 `_ready()` 中，复用时连接依然存在
- `reset_for_pool()` 不做这些信号的操作，避免重复连接
- **例外**：投射物的 `hitbox.area_entered` 信号在 `setup()` 中连接（因为每种投射物类型的回调不同），需要在 `reset_for_pool()` 中断开

### Tween 安全

- `KnockbackHandler.kill_tween()` 已有，直接调用
- 金币/经验球回收时机是 tween 回调点，tween 已完成
- 投射物无 tween

### SceneTreeTimer 安全

- `SlowHandler.clear_all()` 断开所有定时器信号，旧定时器无害过期
- `enemy.remove_root()` 有 `if not is_rooted: return` 守卫，旧 root 定时器被拦截
- SceneTreeTimer 无法被停止/释放，只能断开信号让其空转

### 双重回收防护

- 每个可池化实体增加 `var _is_pooled: bool = false`
- `_pool_release()` 检查 `_is_pooled`，已入池则跳过
- `_pool_acquire()` 清除 `_is_pooled = false`
- 防止场景：敌人死亡触发 `_on_died()` → `release_enemy()`，同时波次清场也调用 `release_enemy()`

### 池上限

- 不设硬性上限（峰值对象数量有限）
- 未来如需要可加 `max_idle` 参数

### 场景切换清理

- 池中空闲对象不在场景树中，不会随场景切换自动销毁
- 离开 main 场景时必须调用 `clear_all_pools()` 真正释放所有池化对象（idle + 清空计数）

### 敌人类型隔离

- 每种敌人类型独立池 key（`enemy_normal` / `enemy_fast` / `enemy_tank`）
- 不同类型场景结构不同，不能混用
