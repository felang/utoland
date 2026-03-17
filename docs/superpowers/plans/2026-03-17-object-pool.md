# 对象池系统实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 SceneFactory 增加内部对象池，池化投射物、普通敌人、金币、经验球，减少高频 instantiate/queue_free 开销。

**Architecture:** 在 SceneFactory 内部增加 PoolEntry 字典管理池化对象。每种可池化实体实现 `reset_for_pool()` 方法重置自身状态。对外创建 API 不变，新增 `release_*()` 回收方法替代 `queue_free()`。预热机制在 main 场景加载时和每波开始前动态补充。

**Tech Stack:** Godot 4.6 GDScript, GUT 测试框架

**Spec:** `docs/superpowers/specs/2026-03-17-object-pool-design.md`

**测试命令:** `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

---

## Chunk 1: 组件 reset 方法 + 池核心基础设施

### File Map

| 文件 | 操作 | 职责 |
|------|------|------|
| `scripts/components/health_component.gd` | 修改 | 新增 `reset()` 方法 |
| `scripts/components/slow_handler.gd` | 修改 | 新增 `clear_all()` 方法 |
| `scripts/core/scene_factory.gd` | 修改 | 新增 PoolEntry 内部类、池核心方法 |
| `tests/unit/test_health_component.gd` | 修改 | 新增 reset 测试 |
| `tests/unit/test_slow_handler.gd` | 修改 | 新增 clear_all 测试 |
| `tests/unit/test_object_pool.gd` | 新建 | 池核心单元测试 |

---

### Task 1: HealthComponent.reset()

**Files:**
- Modify: `scripts/components/health_component.gd`
- Modify: `tests/unit/test_health_component.gd`

- [ ] **Step 1: 写失败测试**

在 `tests/unit/test_health_component.gd` 末尾添加：

```gdscript
func test_reset_restores_full_hp():
	var hc := HealthComponent.new()
	add_child(hc)
	hc.initialize(100.0)
	hc.current_hp = 30.0
	hc.reset()
	assert_eq(hc.current_hp, 100.0, "reset 后 HP 应恢复满血")
	hc.queue_free()

func test_reset_clears_invincible():
	var hc := HealthComponent.new()
	add_child(hc)
	hc.initialize(100.0)
	hc.invincible = true
	hc.reset()
	assert_false(hc.invincible, "reset 后 invincible 应为 false")
	hc.queue_free()

func test_reset_clears_damage_reduction():
	var hc := HealthComponent.new()
	add_child(hc)
	hc.initialize(100.0)
	hc.damage_reduction = 0.5
	hc.reset()
	assert_eq(hc.damage_reduction, 0.0, "reset 后 damage_reduction 应为 0")
	hc.queue_free()
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_health_component.gd -gexit`
Expected: FAIL — `reset` 方法不存在

- [ ] **Step 3: 实现 HealthComponent.reset()**

在 `scripts/components/health_component.gd` 的 `initialize()` 方法后添加：

```gdscript
func reset() -> void:
	current_hp = max_hp
	invincible = false
	damage_reduction = 0.0
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_health_component.gd -gexit`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/components/health_component.gd tests/unit/test_health_component.gd
git commit -m "feat: HealthComponent 新增 reset() 方法（对象池支持）"
```

---

### Task 2: SlowHandler.clear_all()

**Files:**
- Modify: `scripts/components/slow_handler.gd`
- Modify: `tests/unit/test_slow_handler.gd`

- [ ] **Step 1: 写失败测试**

在 `tests/unit/test_slow_handler.gd` 末尾添加：

```gdscript
func test_clear_all_removes_all_slows():
	var sh := SlowHandler.new()
	add_child(sh)
	sh.initialize(100.0)
	sh.apply_slow(0.3, "source_a")
	sh.apply_slow(0.5, "source_b")
	sh.clear_all()
	assert_true(sh._active_slows.is_empty(), "clear_all 后 _active_slows 应为空")
	assert_true(sh._timed_slow_timers.is_empty(), "clear_all 后 _timed_slow_timers 应为空")
	sh.queue_free()

func test_clear_all_disconnects_timed_slow_timers():
	var sh := SlowHandler.new()
	add_child(sh)
	sh.initialize(100.0)
	sh.apply_timed_slow(0.5, 10.0, "timed_source")
	# 确认 timer 存在
	assert_true(sh._timed_slow_timers.has("timed_source"), "应有定时减速")
	sh.clear_all()
	assert_true(sh._active_slows.is_empty(), "clear_all 后减速应清空")
	assert_true(sh._timed_slow_timers.is_empty(), "clear_all 后 timer 应清空")
	sh.queue_free()
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_slow_handler.gd -gexit`
Expected: FAIL — `clear_all` 方法不存在

- [ ] **Step 3: 实现 SlowHandler.clear_all()**

在 `scripts/components/slow_handler.gd` 的 `_on_timed_slow_expired()` 方法后添加：

```gdscript
func clear_all() -> void:
	for source_id in _timed_slow_timers:
		var timer = _timed_slow_timers[source_id]
		if timer and is_instance_valid(timer):
			if timer.timeout.is_connected(_on_timed_slow_expired.bind(source_id)):
				timer.timeout.disconnect(_on_timed_slow_expired.bind(source_id))
	_timed_slow_timers.clear()
	_active_slows.clear()
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_slow_handler.gd -gexit`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/components/slow_handler.gd tests/unit/test_slow_handler.gd
git commit -m "feat: SlowHandler 新增 clear_all() 方法（对象池支持）"
```

---

### Task 3: SceneFactory 池核心基础设施

**Files:**
- Modify: `scripts/core/scene_factory.gd`
- Create: `tests/unit/test_object_pool.gd`

- [ ] **Step 1: 写失败测试**

创建 `tests/unit/test_object_pool.gd`：

```gdscript
extends GutTest

# 测试 SceneFactory 的池核心方法

func test_register_pool():
	# 注册后 _pools 中应有对应 key
	var scene: PackedScene = preload("res://scenes/entities/coin.tscn")
	SceneFactory._register_pool("test_coin", scene)
	assert_true(SceneFactory._pools.has("test_coin"), "注册后应有 test_coin 池")
	# 清理
	SceneFactory._pools.erase("test_coin")

func test_pool_acquire_creates_new_when_empty():
	var scene: PackedScene = preload("res://scenes/entities/coin.tscn")
	SceneFactory._register_pool("test_coin2", scene)
	var obj: Node = SceneFactory._pool_acquire("test_coin2")
	assert_not_null(obj, "空池应 instantiate 新对象")
	assert_eq(SceneFactory._pools["test_coin2"].active_count, 1, "active_count 应为 1")
	obj.queue_free()
	SceneFactory._pools.erase("test_coin2")

func test_pool_release_and_reuse():
	var scene: PackedScene = preload("res://scenes/entities/coin.tscn")
	SceneFactory._register_pool("test_coin3", scene)
	var obj: Node = SceneFactory._pool_acquire("test_coin3")
	add_child(obj)
	# 回收
	SceneFactory._pool_release("test_coin3", obj)
	assert_eq(SceneFactory._pools["test_coin3"].idle_queue.size(), 1, "回收后空闲队列应有 1 个")
	assert_eq(SceneFactory._pools["test_coin3"].active_count, 0, "active_count 应为 0")
	# 再次获取应复用同一对象
	var obj2: Node = SceneFactory._pool_acquire("test_coin3")
	assert_eq(obj, obj2, "应复用同一对象")
	obj2.queue_free()
	SceneFactory._pools.erase("test_coin3")

func test_pool_warmup():
	var scene: PackedScene = preload("res://scenes/entities/coin.tscn")
	SceneFactory._register_pool("test_coin4", scene)
	SceneFactory._pool_warmup("test_coin4", 5)
	assert_eq(SceneFactory._pools["test_coin4"].idle_queue.size(), 5, "预热后应有 5 个空闲对象")
	# 清理
	for obj in SceneFactory._pools["test_coin4"].idle_queue:
		obj.queue_free()
	SceneFactory._pools.erase("test_coin4")

func test_double_release_guard():
	var scene: PackedScene = preload("res://scenes/entities/coin.tscn")
	SceneFactory._register_pool("test_coin5", scene)
	var obj: Node = SceneFactory._pool_acquire("test_coin5")
	add_child(obj)
	SceneFactory._pool_release("test_coin5", obj)
	# 第二次 release 应被忽略
	SceneFactory._pool_release("test_coin5", obj)
	assert_eq(SceneFactory._pools["test_coin5"].idle_queue.size(), 1, "双重回收不应增加队列")
	obj.queue_free()
	SceneFactory._pools.erase("test_coin5")

func test_release_unregistered_key_calls_queue_free():
	var scene: PackedScene = preload("res://scenes/entities/coin.tscn")
	var obj: Node = scene.instantiate()
	add_child(obj)
	# 未注册的 key，应 queue_free
	SceneFactory._pool_release("nonexistent_key", obj)
	await get_tree().process_frame
	assert_false(is_instance_valid(obj), "未注册 key 应 queue_free 对象")

func test_clear_all_pools():
	var scene: PackedScene = preload("res://scenes/entities/coin.tscn")
	SceneFactory._register_pool("test_coin6", scene)
	SceneFactory._pool_warmup("test_coin6", 3)
	SceneFactory.clear_all_pools()
	assert_true(SceneFactory._pools.is_empty(), "clear_all_pools 后池应为空")
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_object_pool.gd -gexit`
Expected: FAIL — `_register_pool` 等方法不存在

- [ ] **Step 3: 实现池核心**

在 `scripts/core/scene_factory.gd` 中添加。在文件顶部（`extends Node` 之后，scene preloads 之前）添加 PoolEntry 内部类：

```gdscript
class PoolEntry:
	var scene: PackedScene
	var idle_queue: Array[Node] = []
	var active_count: int = 0
	var warmup_count: int = 0
```

在文件末尾（`create_projectile` 之后）添加池核心方法：

```gdscript
# ---- 对象池核心 ----
var _pools: Dictionary = {}

func _register_pool(key: String, scene: PackedScene, warmup: int = 0) -> void:
	var entry := PoolEntry.new()
	entry.scene = scene
	entry.warmup_count = warmup
	_pools[key] = entry

func _pool_acquire(key: String) -> Node:
	var entry: PoolEntry = _pools[key]
	var obj: Node
	if entry.idle_queue.size() > 0:
		obj = entry.idle_queue.pop_back()
	else:
		obj = entry.scene.instantiate()
	obj._is_pooled = false
	obj.set_process(true)
	obj.set_physics_process(true)
	entry.active_count += 1
	return obj

func _pool_release(key: String, obj: Node) -> void:
	if not _pools.has(key):
		obj.queue_free()
		return
	if obj.get("_is_pooled") == true:
		return
	obj.reset_for_pool()
	obj._is_pooled = true
	if obj.get_parent():
		obj.get_parent().remove_child(obj)
	obj.set_process(false)
	obj.set_physics_process(false)
	_pools[key].idle_queue.push_back(obj)
	_pools[key].active_count -= 1

func _pool_warmup(key: String, count: int) -> void:
	var entry: PoolEntry = _pools[key]
	for i in count:
		var obj: Node = entry.scene.instantiate()
		obj.set("_is_pooled", true)  # 使用 set() 兼容未定义 _is_pooled 的对象
		obj.set_process(false)
		obj.set_physics_process(false)
		entry.idle_queue.push_back(obj)

func clear_all_pools() -> void:
	for key in _pools:
		var entry: PoolEntry = _pools[key]
		for obj in entry.idle_queue:
			if is_instance_valid(obj):
				obj.queue_free()
		entry.idle_queue.clear()
		entry.active_count = 0
	_pools.clear()
```

**注意**：`_pool_acquire` 和 `_pool_release` 使用 duck typing（`obj._is_pooled`、`obj.reset_for_pool()`），可池化实体必须定义这些属性/方法。coin.tscn 的根节点脚本（coin.gd）后续任务会添加 `_is_pooled` 和 `reset_for_pool()`。测试中暂时用 coin（它有简单结构），但需要先给 coin.gd 添加最小的池化接口才能让测试通过。

为了让池核心测试独立于实体池化实现，使用 mock 节点。修改测试中的 coin 使用为自定义 mock：

将 `test_object_pool.gd` 的 preload 全部换成内联场景创建，避免依赖实体的 `reset_for_pool()` 和 `_is_pooled`：

实际上，更简单的做法是：先让 coin.gd 在 Task 4（金币池化）中添加 `_is_pooled` 和 `reset_for_pool()`。Task 3 的测试可以直接用 coin 场景，但先跳过 release/reuse 测试，只测 register 和 warmup。

**修正方案**：Task 3 只实现和测试 `_register_pool`、`_pool_warmup`、`clear_all_pools`。`_pool_acquire` 和 `_pool_release` 的集成测试放到 Task 4（金币池化）之后。

修改测试为：

```gdscript
extends GutTest

func test_register_pool():
	var scene: PackedScene = preload("res://scenes/entities/coin.tscn")
	SceneFactory._register_pool("test_coin", scene)
	assert_true(SceneFactory._pools.has("test_coin"), "注册后应有 test_coin 池")
	SceneFactory._pools.erase("test_coin")

func test_pool_warmup():
	var scene: PackedScene = preload("res://scenes/entities/coin.tscn")
	SceneFactory._register_pool("test_coin_w", scene)
	SceneFactory._pool_warmup("test_coin_w", 5)
	assert_eq(SceneFactory._pools["test_coin_w"].idle_queue.size(), 5, "预热后应有 5 个空闲对象")
	for obj in SceneFactory._pools["test_coin_w"].idle_queue:
		obj.queue_free()
	SceneFactory._pools.erase("test_coin_w")

func test_clear_all_pools():
	var scene: PackedScene = preload("res://scenes/entities/coin.tscn")
	SceneFactory._register_pool("test_coin_c", scene)
	SceneFactory._pool_warmup("test_coin_c", 3)
	SceneFactory.clear_all_pools()
	assert_true(SceneFactory._pools.is_empty(), "clear_all_pools 后池应为空")
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_object_pool.gd -gexit`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/core/scene_factory.gd tests/unit/test_object_pool.gd
git commit -m "feat: SceneFactory 新增对象池核心基础设施（PoolEntry/register/warmup/clear）"
```

---

## Chunk 2: 金币 + 经验球池化

### Task 4: 金币 (coin.gd) 池化

**Files:**
- Modify: `scripts/entities/coin.gd` — 添加 `_is_pooled`、`reset_for_pool()`
- Modify: `scripts/core/scene_factory.gd` — 修改 `create_coin()`、新增 `release_coin()`、注册池
- Modify: `tests/unit/test_object_pool.gd` — 新增金币池化测试

- [ ] **Step 1: 写失败测试**

在 `tests/unit/test_object_pool.gd` 末尾追加：

```gdscript
func test_coin_reset_for_pool():
	var coin: Area2D = SceneFactory.create_coin()
	add_child(coin)
	# 模拟使用后的状态
	coin.value = 5
	coin.is_attracted = true
	coin.attract_speed = 999.0
	coin.modulate.a = 0.0
	coin.scale = Vector2(0.1, 0.1)
	coin.reset_for_pool()
	assert_eq(coin.value, 1, "reset 后 value 应为 1")
	assert_false(coin.is_attracted, "reset 后 is_attracted 应为 false")
	assert_eq(coin.attract_speed, 250.0, "reset 后 attract_speed 应为默认值")
	assert_eq(coin.attract_range, 75.0, "reset 后 attract_range 应为默认值")
	assert_null(coin.player, "reset 后 player 应为 null")
	assert_eq(coin.modulate.a, 1.0, "reset 后 modulate.a 应为 1.0")
	assert_eq(coin.scale, Vector2.ONE, "reset 后 scale 应为 ONE")
	coin.queue_free()

func test_coin_pool_acquire_and_release():
	# 先确保池已注册（SceneFactory._ready 会注册）
	var coin: Area2D = SceneFactory.create_coin()
	add_child(coin)
	coin.value = 10
	SceneFactory.release_coin(coin)
	# 回收后不在场景树中
	assert_null(coin.get_parent(), "回收后不应有 parent")
	# 再次获取应复用
	var coin2: Area2D = SceneFactory.create_coin()
	assert_eq(coin, coin2, "应复用同一 coin 对象")
	assert_eq(coin2.value, 1, "复用后 value 应已重置")
	coin2.queue_free()

func test_coin_double_release_ignored():
	var coin: Area2D = SceneFactory.create_coin()
	add_child(coin)
	SceneFactory.release_coin(coin)
	var idle_count: int = SceneFactory._pools["coin"].idle_queue.size()
	SceneFactory.release_coin(coin)
	assert_eq(SceneFactory._pools["coin"].idle_queue.size(), idle_count, "双重回收不应增加队列")
	coin.queue_free()
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_object_pool.gd -gexit`
Expected: FAIL — `reset_for_pool`、`release_coin` 不存在

- [ ] **Step 3: 实现金币池化**

3a. 在 `scripts/entities/coin.gd` 中添加（在 `var is_attracted` 之后）：

```gdscript
var _is_pooled: bool = false
```

在文件末尾添加：

```gdscript
func reset_for_pool() -> void:
	value = 1
	is_attracted = false
	attract_speed = 250.0
	attract_range = 75.0
	player = null
	visible = true
	modulate.a = 1.0
	scale = Vector2.ONE
	set_deferred("monitoring", true)
```

3b. 在 `scripts/core/scene_factory.gd` 中：

在 `_ready()` 方法中（如果没有 `_ready()` 则新建）注册 coin 池：

```gdscript
func _ready() -> void:
	_register_pool("coin", _coin_scene)
```

修改 `create_coin()` 方法：

```gdscript
func create_coin() -> Area2D:
	return _pool_acquire("coin") as Area2D
```

新增 `release_coin()` 方法（在 `create_exp_orb()` 之后）：

```gdscript
func release_coin(coin: Area2D) -> void:
	_pool_release("coin", coin)
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_object_pool.gd -gexit`
Expected: PASS

- [ ] **Step 5: 替换调用方 queue_free**

在 `scripts/entities/coin.gd` 的 `_play_pickup_effect()` 中，将 tween 回调的 `queue_free` 替换：

```gdscript
# 原代码（第 45 行）：
tween.tween_callback(queue_free)

# 改为：
tween.tween_callback(func(): SceneFactory.release_coin(self))
```

- [ ] **Step 6: 运行全量测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全部 PASS

- [ ] **Step 7: 提交**

```bash
git add scripts/entities/coin.gd scripts/core/scene_factory.gd tests/unit/test_object_pool.gd
git commit -m "feat: 金币对象池化（reset_for_pool + release_coin + 池注册）"
```

---

### Task 5: 经验球 (exp_orb.gd) 池化

**Files:**
- Modify: `scripts/entities/exp_orb.gd` — 添加 `_is_pooled`、`reset_for_pool()`
- Modify: `scripts/core/scene_factory.gd` — 修改 `create_exp_orb()`、新增 `release_exp_orb()`、注册池
- Modify: `tests/unit/test_object_pool.gd` — 新增经验球测试

- [ ] **Step 1: 写失败测试**

在 `tests/unit/test_object_pool.gd` 末尾追加：

```gdscript
func test_exp_orb_reset_for_pool():
	var orb: Area2D = SceneFactory.create_exp_orb()
	add_child(orb)
	orb.value = 10
	orb.is_attracted = true
	orb.attract_speed = 500.0
	orb.modulate.a = 0.0
	orb.reset_for_pool()
	assert_eq(orb.value, 1, "reset 后 value 应为 1")
	assert_false(orb.is_attracted, "reset 后 is_attracted 应为 false")
	assert_eq(orb.attract_speed, 200.0, "reset 后 attract_speed 应为默认值")
	assert_eq(orb.attract_range, 30.0, "reset 后 attract_range 应为默认值")
	assert_null(orb.player, "reset 后 player 应为 null")
	orb.queue_free()

func test_exp_orb_pool_acquire_and_release():
	var orb: Area2D = SceneFactory.create_exp_orb()
	add_child(orb)
	orb.value = 10
	SceneFactory.release_exp_orb(orb)
	var orb2: Area2D = SceneFactory.create_exp_orb()
	assert_eq(orb, orb2, "应复用同一 exp_orb 对象")
	assert_eq(orb2.value, 1, "复用后 value 应已重置")
	orb2.queue_free()
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_object_pool.gd -gexit`
Expected: FAIL

- [ ] **Step 3: 实现经验球池化**

3a. 在 `scripts/entities/exp_orb.gd` 中添加 `var _is_pooled: bool = false`（在 `var is_attracted` 之后），在文件末尾添加：

```gdscript
func reset_for_pool() -> void:
	value = 1
	is_attracted = false
	attract_speed = 200.0
	attract_range = 30.0
	player = null
	visible = true
	modulate.a = 1.0
	scale = Vector2.ONE
	set_deferred("monitoring", true)
```

3b. 在 `scripts/core/scene_factory.gd` 中：

`_ready()` 中追加注册：
```gdscript
_register_pool("exp_orb", _exp_orb_scene)
```

修改 `create_exp_orb()`：
```gdscript
func create_exp_orb() -> Area2D:
	return _pool_acquire("exp_orb") as Area2D
```

新增：
```gdscript
func release_exp_orb(orb: Area2D) -> void:
	_pool_release("exp_orb", orb)
```

3c. 在 `scripts/entities/exp_orb.gd` 的 `_play_pickup_effect()` 中替换 tween 回调：

```gdscript
# 原代码（第 44 行）：
tween.tween_callback(queue_free)

# 改为：
tween.tween_callback(func(): SceneFactory.release_exp_orb(self))
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_object_pool.gd -gexit`
Expected: PASS

- [ ] **Step 5: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全部 PASS

- [ ] **Step 6: 提交**

```bash
git add scripts/entities/exp_orb.gd scripts/core/scene_factory.gd tests/unit/test_object_pool.gd
git commit -m "feat: 经验球对象池化（reset_for_pool + release_exp_orb）"
```

---

## Chunk 3: 投射物池化

### Task 6: ProjectileBase 池化重构

**Files:**
- Modify: `scripts/entities/projectiles/projectile_base.gd` — 重构 `setup()` 为幂等、添加 `reset_for_pool()`
- Modify: `scripts/entities/projectiles/shuriken_projectile.gd` — 重写 `reset_for_pool()`
- Modify: `scripts/core/scene_factory.gd` — 修改 `create_projectile()`、新增 `release_projectile()`
- Modify: `tests/unit/test_object_pool.gd` — 新增投射物池化测试

- [ ] **Step 1: 写失败测试**

在 `tests/unit/test_object_pool.gd` 末尾追加：

```gdscript
func test_projectile_reset_for_pool():
	var pd := ProjectileData.new()
	pd.speed = 800.0
	pd.lifetime = 5.0
	pd.base_pierce_count = 0
	pd.knockback_force = 50.0
	pd.trail_enabled = false
	pd.sprite_path = ""
	pd.projectile_scene = preload("res://scenes/entities/projectiles/bullet_projectile.tscn")
	var proj: ProjectileBase = SceneFactory.create_projectile(pd, 10.0, Vector2(100, 100), Vector2.RIGHT)
	add_child(proj)
	# 模拟使用
	proj._elapsed = 3.0
	proj._hit_count = 2
	proj.reset_for_pool()
	assert_eq(proj._elapsed, 0.0, "reset 后 _elapsed 应为 0")
	assert_eq(proj._hit_count, 0, "reset 后 _hit_count 应为 0")
	assert_eq(proj._direction, Vector2.ZERO, "reset 后 _direction 应为 ZERO")
	assert_true(proj.visible, "reset 后应可见")
	proj.queue_free()

func test_projectile_pool_reuse():
	var pd := ProjectileData.new()
	pd.speed = 800.0
	pd.lifetime = 5.0
	pd.base_pierce_count = 0
	pd.knockback_force = 50.0
	pd.trail_enabled = false
	pd.sprite_path = ""
	pd.projectile_scene = preload("res://scenes/entities/projectiles/bullet_projectile.tscn")
	var proj1: ProjectileBase = SceneFactory.create_projectile(pd, 10.0, Vector2.ZERO, Vector2.RIGHT)
	add_child(proj1)
	SceneFactory.release_projectile(proj1)
	var proj2: ProjectileBase = SceneFactory.create_projectile(pd, 20.0, Vector2(50, 50), Vector2.LEFT)
	assert_eq(proj1, proj2, "应复用同一投射物对象")
	assert_eq(proj2._speed, 800.0, "复用后 speed 应来自 setup")
	proj2.queue_free()
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_object_pool.gd -gexit`
Expected: FAIL — `reset_for_pool`、`release_projectile` 不存在

- [ ] **Step 3: 实现投射物池化**

3a. 在 `scripts/entities/projectiles/projectile_base.gd` 中：

在类变量区域添加：
```gdscript
var _is_pooled: bool = false
```

添加清理辅助方法和 `reset_for_pool()`（在 `_cleanup_and_free()` 之后）：

```gdscript
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

func _create_trail() -> void:
	var fx: EffectConfigData = GameConfig.effects
	_trail_max_points = fx.bullet_trail_max_points
	_trail = Line2D.new()
	_trail.width = fx.bullet_trail_width
	_trail.default_color = fx.bullet_trail_color
	_trail.z_index = -1
	_trail.top_level = true
	add_child(_trail)

func reset_for_pool() -> void:
	_cleanup_dynamic_sprite()
	_cleanup_trail()
	_trail_positions.clear()
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
```

重构 `setup()` 方法使其幂等（替换现有 setup 方法，第 67-98 行）：

```gdscript
func setup(p_data: ProjectileData, damage: float, from: Vector2, direction: Vector2, extra_pierce: int = 0) -> void:
	data = p_data
	global_position = from
	_direction = direction
	_speed = data.speed
	_lifetime = data.lifetime
	_pierce_count = data.base_pierce_count + extra_pierce
	_hit_count = 0
	_elapsed = 0.0
	hitbox = get_node_or_null("Hitbox") as Hitbox
	assert(hitbox != null, "ProjectileBase.setup: 缺少 Hitbox 子节点")
	hitbox.damage = damage
	hitbox.knockback_force = data.knockback_force
	# 精灵：先清理旧的，再按需创建
	_cleanup_dynamic_sprite()
	if data.sprite_path != "" and ResourceLoader.exists(data.sprite_path):
		var sprite := Sprite2D.new()
		sprite.name = "_PooledSprite"
		sprite.texture = load(data.sprite_path)
		sprite.rotation = direction.angle()
		add_child(sprite)
	# 拖尾：先清理旧的，再按需创建
	_cleanup_trail()
	_trail_positions.clear()
	show_trail = data.trail_enabled
	if show_trail:
		_create_trail()
	# 信号：先断开再连接，防止重复
	if hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox.area_entered.disconnect(_on_hitbox_area_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)
```

修改 `_cleanup_and_free()` 使用池回收：

```gdscript
func _cleanup_and_free() -> void:
	SceneFactory.release_projectile(self)
```

3b. 在 `scripts/entities/projectiles/shuriken_projectile.gd` 中添加：

```gdscript
var _is_pooled: bool = false

func reset_for_pool() -> void:
	super.reset_for_pool()
	_bounce_target = null
	_hit_enemies.clear()
	_shuriken_hit_count = 0
	if hitbox and hitbox.area_entered.is_connected(_on_shuriken_hit):
		hitbox.area_entered.disconnect(_on_shuriken_hit)
```

3c. 在 `scripts/core/scene_factory.gd` 中：

修改 `create_projectile()` 使用池：

```gdscript
func create_projectile(p_data: ProjectileData, damage: float, from: Vector2, direction: Vector2, extra_pierce: int = 0) -> ProjectileBase:
	assert(p_data != null, "SceneFactory.create_projectile: data 不能为 null")
	assert(p_data.projectile_scene != null, "SceneFactory.create_projectile: projectile_scene 未配置")
	var key: String = _get_projectile_pool_key(p_data)
	if not _pools.has(key):
		_register_pool(key, p_data.projectile_scene)
	var proj: ProjectileBase = _pool_acquire(key) as ProjectileBase
	proj.setup(p_data, damage, from, direction, extra_pierce)
	return proj
```

新增辅助方法和 release 方法：

```gdscript
func _get_projectile_pool_key(p_data: ProjectileData) -> String:
	return "projectile_" + p_data.projectile_scene.resource_path.get_file().get_basename()

func release_projectile(proj: ProjectileBase) -> void:
	if proj.data:
		var key: String = _get_projectile_pool_key(proj.data)
		_pool_release(key, proj)
	else:
		proj.queue_free()
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_object_pool.gd -gexit`
Expected: PASS

- [ ] **Step 5: 运行已有投射物测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_projectile.gd -gexit`
Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_shuriken_projectile.gd -gexit`
Expected: PASS

- [ ] **Step 6: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全部 PASS

- [ ] **Step 7: 提交**

```bash
git add scripts/entities/projectiles/projectile_base.gd scripts/entities/projectiles/shuriken_projectile.gd scripts/core/scene_factory.gd tests/unit/test_object_pool.gd
git commit -m "feat: 投射物对象池化（setup 幂等重构 + reset_for_pool + release_projectile）"
```

---

## Chunk 4: 敌人池化

### Task 7: 敌人 (enemy.gd) 池化

**Files:**
- Modify: `scripts/entities/enemy.gd` — 添加 `_is_pooled`、`reset_for_pool()`
- Modify: `scripts/core/scene_factory.gd` — 重写 `create_enemy()` 支持复用初始化、新增 `release_enemy()`、注册池
- Modify: `scripts/systems/wave_manager.gd` — `clear_all_enemies()` 替换 `queue_free()`
- Modify: `tests/unit/test_object_pool.gd` — 新增敌人池化测试

- [ ] **Step 1: 写失败测试**

在 `tests/unit/test_object_pool.gd` 末尾追加：

```gdscript
func test_enemy_reset_for_pool():
	var enemy: CharacterBody2D = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	add_child(enemy)
	# 模拟使用后的脏状态
	enemy.is_elite = true
	enemy._elite_coin_mult = 2.0
	enemy._elite_exp_mult = 2.0
	enemy.scale = Vector2(1.5, 1.5)
	enemy.current_state = enemy.State.ATTACK_TOWER
	enemy.velocity = Vector2(100, 0)
	enemy.attack_timer = 0.5
	enemy.visible = false
	enemy.reset_for_pool()
	assert_false(enemy.is_elite, "reset 后 is_elite 应为 false")
	assert_eq(enemy._elite_coin_mult, 1.0, "reset 后 coin mult 应为 1.0")
	assert_eq(enemy._elite_exp_mult, 1.0, "reset 后 exp mult 应为 1.0")
	assert_eq(enemy.scale, Vector2.ONE, "reset 后 scale 应为 ONE")
	assert_eq(enemy.current_state, enemy.State.CHASE_PLAYER, "reset 后应为 CHASE_PLAYER")
	assert_null(enemy.target_tower, "reset 后 target_tower 应为 null")
	assert_eq(enemy.velocity, Vector2.ZERO, "reset 后 velocity 应为 ZERO")
	assert_eq(enemy.attack_timer, 0.0, "reset 后 attack_timer 应为 0")
	assert_true(enemy.visible, "reset 后应可见")
	enemy.queue_free()

func test_enemy_pool_reuse_reinitializes():
	var enemy1: CharacterBody2D = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	add_child(enemy1)
	var original_speed: float = enemy1.speed
	# 模拟精英修改
	enemy1.speed = 999.0
	enemy1.tower_attack_damage = 999.0
	SceneFactory.release_enemy(enemy1)
	# 复用
	var enemy2: CharacterBody2D = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	assert_eq(enemy1, enemy2, "应复用同一敌人对象")
	assert_eq(enemy2.speed, original_speed, "复用后 speed 应从 data 重新初始化")
	assert_false(enemy2.health.is_dead(), "复用后不应处于死亡状态")
	enemy2.queue_free()

func test_enemy_double_release_ignored():
	var enemy: CharacterBody2D = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	add_child(enemy)
	SceneFactory.release_enemy(enemy)
	var idle_count: int = SceneFactory._pools["enemy_normal"].idle_queue.size()
	SceneFactory.release_enemy(enemy)
	assert_eq(SceneFactory._pools["enemy_normal"].idle_queue.size(), idle_count, "双重回收不应增加队列")
	enemy.queue_free()
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_object_pool.gd -gexit`
Expected: FAIL

- [ ] **Step 3: 实现敌人池化**

3a. 在 `scripts/entities/enemy.gd` 中：

在变量区域添加（`var _root_source` 之后）：
```gdscript
var _is_pooled: bool = false
```

修改 `_on_died()` 方法（第 112 行），将 `queue_free()` 替换：
```gdscript
# 原代码：queue_free()
# 改为：
SceneFactory.release_enemy(self)
```

在文件末尾添加 `reset_for_pool()`：

```gdscript
func reset_for_pool() -> void:
	health.reset()
	_knockback.kill_tween()
	slow_handler.clear_all()
	if is_rooted:
		remove_root()
	if is_in_group("elites"):
		remove_from_group("elites")
	is_elite = false
	_elite_coin_mult = 1.0
	_elite_exp_mult = 1.0
	scale = Vector2.ONE
	current_state = State.CHASE_PLAYER
	target_tower = null
	velocity = Vector2.ZERO
	attack_timer = 0.0
	if _sprite_animator._sprite:
		_sprite_animator._sprite.play("walk_down")
		_sprite_animator._current_anim = "walk_down"
	visible = true
	modulate = Color.WHITE
```

3b. 在 `scripts/core/scene_factory.gd` 中：

`_ready()` 中注册敌人池（只注册可池化的普通敌人类型）：
```gdscript
for enemy_type in [Enums.Enemy.NORMAL, Enums.Enemy.FAST, Enums.Enemy.TANK]:
	_register_pool("enemy_" + enemy_type, _enemy_scenes[enemy_type])
```

重写 `create_enemy()` 方法（替换第 37-47 行）：

```gdscript
func create_enemy(type: String) -> CharacterBody2D:
	if not _enemy_scenes.has(type):
		push_error("Unknown enemy type: " + type)
		return null

	var key := "enemy_" + type
	var enemy: CharacterBody2D
	if _pools.has(key):
		enemy = _pool_acquire(key) as CharacterBody2D
	else:
		enemy = _enemy_scenes[type].instantiate()

	enemy.enemy_type = type
	if GameConfig.enemies.has(type):
		enemy.data = GameConfig.enemies[type]
	# 从 Resource 重新初始化数值（覆盖精英缩放后的残留值）
	if enemy.data:
		enemy.health.initialize(enemy.data.hp)
		enemy.speed = enemy.data.speed
		enemy.tower_attack_damage = enemy.data.damage
		enemy._hitbox.damage = enemy.data.damage
		enemy.slow_handler.initialize(enemy.data.speed)
	# 重新获取 player 引用
	enemy.player = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	return enemy
```

新增：
```gdscript
func release_enemy(enemy: CharacterBody2D) -> void:
	var key := "enemy_" + enemy.enemy_type
	_pool_release(key, enemy)
```

3c. 在 `scripts/systems/wave_manager.gd` 中修改 `clear_all_enemies()`（第 73-79 行）：

```gdscript
func clear_all_enemies() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	for enemy in enemies:
		SceneFactory.release_enemy(enemy)
```

**注意**：不再需要手动 `set_physics_process(false)` / `set_process(false)`，因为 `_pool_release()` 已经处理。

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_object_pool.gd -gexit`
Expected: PASS

- [ ] **Step 5: 运行已有敌人/波次相关测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_scene_factory.gd -gexit`
Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_wave_manager.gd -gexit`
Expected: PASS

- [ ] **Step 6: 运行全量测试**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全部 PASS

- [ ] **Step 7: 提交**

```bash
git add scripts/entities/enemy.gd scripts/core/scene_factory.gd scripts/systems/wave_manager.gd tests/unit/test_object_pool.gd
git commit -m "feat: 敌人对象池化（reset_for_pool + release_enemy + wave_manager 集成）"
```

---

## Chunk 5: 预热机制 + 场景集成 + 清理

### Task 8: 预热机制

**Files:**
- Modify: `scripts/core/scene_factory.gd` — 新增 `warmup_initial()`、`warmup_for_wave()`
- Modify: `tests/unit/test_object_pool.gd` — 新增预热测试

- [ ] **Step 1: 写失败测试**

在 `tests/unit/test_object_pool.gd` 末尾追加：

```gdscript
func test_warmup_initial():
	# 先清空池（前面测试可能留有残留）
	SceneFactory.clear_all_pools()
	# 重新注册
	SceneFactory._ready()
	SceneFactory.warmup_initial()
	# 验证各池有预热对象
	assert_true(SceneFactory._pools["coin"].idle_queue.size() >= 15, "coin 池应有 >= 15 个预热对象")
	assert_true(SceneFactory._pools["exp_orb"].idle_queue.size() >= 15, "exp_orb 池应有 >= 15 个预热对象")
	assert_true(SceneFactory._pools["enemy_normal"].idle_queue.size() >= 10, "enemy_normal 池应有 >= 10 个预热对象")
	# 清理
	SceneFactory.clear_all_pools()
	SceneFactory._ready()  # 恢复正常注册

func test_warmup_for_wave_fills_gap():
	SceneFactory.clear_all_pools()
	SceneFactory._ready()
	# 模拟一个 WaveData
	var wd := WaveData.new()
	wd.max_alive_enemies = 20
	wd.enemy_weights = {Enums.Enemy.NORMAL: 1.0}
	SceneFactory.warmup_for_wave(wd)
	assert_true(SceneFactory._pools["enemy_normal"].idle_queue.size() >= 20, "应按 max_alive_enemies 补充")
	SceneFactory.clear_all_pools()
	SceneFactory._ready()
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_object_pool.gd -gexit`
Expected: FAIL — `warmup_initial`、`warmup_for_wave` 不存在

- [ ] **Step 3: 实现预热方法**

在 `scripts/core/scene_factory.gd` 的池核心方法区域末尾添加：

```gdscript
func warmup_initial() -> void:
	# 投射物预热：遍历所有武器的 projectile_data
	for weapon_id in GameConfig.weapons:
		var wd: WeaponData = GameConfig.weapons[weapon_id]
		if wd.projectile_data and wd.projectile_data.projectile_scene:
			var key: String = _get_projectile_pool_key(wd.projectile_data)
			if not _pools.has(key):
				_register_pool(key, wd.projectile_data.projectile_scene)
			_pool_warmup(key, 20)
	# 敌人预热
	_pool_warmup("enemy_normal", 10)
	_pool_warmup("enemy_fast", 5)
	_pool_warmup("enemy_tank", 3)
	# 掉落物预热
	_pool_warmup("coin", 15)
	_pool_warmup("exp_orb", 15)

func warmup_for_wave(wave_data: WaveData) -> void:
	var max_enemies: int = wave_data.max_alive_enemies
	# 按 enemy_weights 比例补充敌人
	var total_weight: float = 0.0
	for w in wave_data.enemy_weights.values():
		total_weight += w
	if total_weight > 0:
		for enemy_type in wave_data.enemy_weights:
			var key: String = "enemy_" + enemy_type
			if not _pools.has(key):
				continue
			var ratio: float = wave_data.enemy_weights[enemy_type] / total_weight
			var target: int = int(ceil(max_enemies * ratio))
			var current: int = _pools[key].idle_queue.size()
			if target > current:
				_pool_warmup(key, target - current)
	# 投射物补充
	for proj_key in _pools:
		if proj_key.begins_with("projectile_"):
			var target: int = max_enemies * 2
			var current: int = _pools[proj_key].idle_queue.size()
			if target > current:
				_pool_warmup(proj_key, target - current)
	# 掉落物补充
	for drop_key in ["coin", "exp_orb"]:
		if _pools.has(drop_key):
			var target: int = max_enemies
			var current: int = _pools[drop_key].idle_queue.size()
			if target > current:
				_pool_warmup(drop_key, target - current)
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_object_pool.gd -gexit`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/core/scene_factory.gd tests/unit/test_object_pool.gd
git commit -m "feat: 对象池预热机制（warmup_initial + warmup_for_wave）"
```

---

### Task 9: main 场景集成（预热调用 + 场景切换清理）

**Files:**
- Modify: `scripts/ui/main.gd` — `_ready()` 中调用 `warmup_initial()`，退出时 `clear_all_pools()`

- [ ] **Step 1: 在 main.gd `_ready()` 末尾添加预热调用**

在 `scripts/ui/main.gd` 的 `_ready()` 方法末尾（`_enter_shop_phase(true)` 之后）添加：

```gdscript
SceneFactory.warmup_initial()
```

- [ ] **Step 2: 连接每波预热**

在 `scripts/ui/main.gd` 的 `_ready()` 中（信号连接区域，`EventBus.coins_generated.connect(...)` 之后）添加：

```gdscript
EventBus.wave_started.connect(_on_wave_started_warmup)
```

在 `scripts/ui/main.gd` 中添加回调方法：

```gdscript
func _on_wave_started_warmup(_wave_num: int, wave_data: WaveData) -> void:
	SceneFactory.warmup_for_wave(wave_data)
```

- [ ] **Step 3: 添加场景退出清理**

在 `scripts/ui/main.gd` 中添加 `_exit_tree()` 方法：

```gdscript
func _exit_tree() -> void:
	SceneFactory.clear_all_pools()
```

- [ ] **Step 4: 运行全量测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全部 PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/ui/main.gd
git commit -m "feat: main 场景集成对象池预热和退出清理"
```

---

### Task 10: 最终全量测试 + 清理

- [ ] **Step 1: 运行全量测试套件**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全部 PASS

- [ ] **Step 2: 确认 SceneFactory 对外 API 兼容性**

检查以下方法签名未变：
- `create_tower(type, level)` — 未修改
- `create_enemy(type)` — 返回类型不变
- `create_coin()` — 返回类型不变
- `create_exp_orb()` — 返回类型不变
- `create_projectile(p_data, damage, from, direction, extra_pierce)` — 返回类型不变

- [ ] **Step 3: 提交最终状态**

如果有任何遗漏修复：
```bash
git add -A
git commit -m "chore: 对象池系统最终调整"
```
