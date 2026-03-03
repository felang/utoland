# 阶段 2：完整战斗循环实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 完善战斗循环（多样性+难度曲线+经济系统）

**Architecture:** 在阶段1基础上扩展3种敌人、3种植物塔、10波次系统、金币经济

**Tech Stack:** Godot 4.6, GDScript, GDAI MCP Plugin

---

## Task 1: 扩展敌人类型

**Files:**
- Create: `scenes/enemies/enemy_fast.tscn`
- Create: `scenes/enemies/enemy_tank.tscn`
- Modify: `scripts/enemy.gd`

**Step 1: 创建快速敌人场景**

基于 enemy_normal.tscn 复制创建 enemy_fast.tscn

**Step 2: 配置快速敌人属性**

```gdscript
# 在场景中设置
speed = 250.0
max_hp = 20.0
touch_damage = 8.0
# 视觉：蓝色 ColorRect
```

**Step 3: 创建肉盾敌人场景**

基于 enemy_normal.tscn 复制创建 enemy_tank.tscn

**Step 4: 配置肉盾敌人属性**

```gdscript
# 在场景中设置
speed = 100.0
max_hp = 150.0
touch_damage = 15.0
# 视觉：紫色 ColorRect (48x48)
```

**Step 5: 测试三种敌人**

在 main.tscn 中手动放置三种敌人测试

**Step 6: 提交**

```bash
git add scenes/enemies/
git commit -m "feat(phase2): 添加快速敌人和肉盾敌人"
```

---

## Task 2: 扩展植物塔类型

**Files:**
- Create: `scenes/towers/tower_shooter.tscn` (豌豆射手)
- Create: `scenes/towers/tower_slow.tscn` (冰雪菇)
- Create: `scripts/tower.gd` (基类)

**Step 1: 创建塔基类脚本**

```gdscript
extends StaticBody2D
class_name Tower

@export var max_hp: float = 100.0
@export var cost: int = 30

var current_hp: float

func _ready():
    current_hp = max_hp
    add_to_group("towers")

func take_damage(amount: float):
    current_hp -= amount
    if current_hp <= 0:
        queue_free()
```

**Step 2: 创建豌豆射手场景**

```
mcp__gdai-mcp__create_scene
- file_path: "res://scenes/towers/tower_shooter.tscn"
- node_type: "StaticBody2D"
- node_name: "TowerShooter"
```

添加绿色 ColorRect (32x32) 和 CollisionShape2D

**Step 3: 编写豌豆射手脚本**

继承 Tower，添加射击逻辑：
```gdscript
extends Tower

@export var attack_range: float = 250.0
@export var attack_damage: float = 10.0
@export var attack_rate: float = 1.0
var attack_timer: float = 0.0
var bullet_scene = preload("res://scenes/bullet.tscn")

func _process(delta):
    attack_timer -= delta
    if attack_timer <= 0:
        shoot_nearest_enemy()

func shoot_nearest_enemy():
    var enemies = get_tree().get_nodes_in_group("enemies")
    var closest = null
    var min_dist = attack_range

    for enemy in enemies:
        var dist = global_position.distance_to(enemy.global_position)
        if dist < min_dist:
            min_dist = dist
            closest = enemy

    if closest:
        var bullet = bullet_scene.instantiate()
        bullet.global_position = global_position
        bullet.direction = global_position.direction_to(closest.global_position)
        get_parent().add_child(bullet)
        attack_timer = attack_rate
```

**Step 4: 创建冰雪菇场景**

```
mcp__gdai-mcp__create_scene
- file_path: "res://scenes/towers/tower_slow.tscn"
- node_type: "StaticBody2D"
- node_name: "TowerSlow"
```

添加青色 ColorRect 和 Area2D (减速光环)

**Step 5: 编写冰雪菇脚本**

```gdscript
extends Tower

@export var slow_radius: float = 200.0
@export var slow_percent: float = 0.5

var slow_area: Area2D

func _ready():
    super._ready()
    slow_area = Area2D.new()
    var collision = CollisionShape2D.new()
    var shape = CircleShape2D.new()
    shape.radius = slow_radius
    collision.shape = shape
    slow_area.add_child(collision)
    add_child(slow_area)
    slow_area.body_entered.connect(_on_enemy_entered)
    slow_area.body_exited.connect(_on_enemy_exited)

func _on_enemy_entered(body):
    if body.is_in_group("enemies"):
        body.speed *= (1.0 - slow_percent)

func _on_enemy_exited(body):
    if body.is_in_group("enemies"):
        body.speed /= (1.0 - slow_percent)
```

**Step 6: 测试植物塔**

在 main.tscn 中放置三种塔测试功能

**Step 7: 提交**

```bash
git add scenes/towers/ scripts/tower.gd
git commit -m "feat(phase2): 添加豌豆射手和冰雪菇"
```

---

## Task 3: 实现波次管理系统

**Files:**
- Create: `scripts/wave_manager.gd`
- Modify: `scenes/main.tscn`

**Step 1: 创建波次管理器脚本**

```gdscript
extends Node

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal game_won()
signal game_lost()

@export var total_waves: int = 10
var current_wave: int = 0
var wave_time_left: float = 0.0
var is_wave_active: bool = false

# 波次配置
var wave_configs = {
    1: {"duration": 45, "enemy_types": ["normal"], "spawn_interval": 4.0, "max_enemies": 15},
    2: {"duration": 45, "enemy_types": ["normal"], "spawn_interval": 4.0, "max_enemies": 15},
    3: {"duration": 45, "enemy_types": ["normal"], "spawn_interval": 4.0, "max_enemies": 15},
    4: {"duration": 50, "enemy_types": ["normal", "fast"], "spawn_interval": 3.0, "max_enemies": 25},
    5: {"duration": 50, "enemy_types": ["normal", "fast"], "spawn_interval": 3.0, "max_enemies": 25},
    6: {"duration": 50, "enemy_types": ["normal", "fast"], "spawn_interval": 3.0, "max_enemies": 25},
    7: {"duration": 60, "enemy_types": ["normal", "fast", "tank"], "spawn_interval": 2.0, "max_enemies": 35},
    8: {"duration": 60, "enemy_types": ["normal", "fast", "tank"], "spawn_interval": 2.0, "max_enemies": 35},
    9: {"duration": 60, "enemy_types": ["normal", "fast", "tank"], "spawn_interval": 2.0, "max_enemies": 35},
    10: {"duration": 60, "enemy_types": ["normal", "fast", "tank"], "spawn_interval": 1.0, "max_enemies": 50}
}

func _ready():
    start_next_wave()

func _process(delta):
    if is_wave_active:
        wave_time_left -= delta
        if wave_time_left <= 0:
            complete_wave()

func start_next_wave():
    current_wave += 1
    if current_wave > total_waves:
        game_won.emit()
        return

    var config = wave_configs[current_wave]
    wave_time_left = config["duration"]
    is_wave_active = true
    wave_started.emit(current_wave)

func complete_wave():
    is_wave_active = false
    clear_all_enemies()
    wave_completed.emit(current_wave)

func clear_all_enemies():
    var enemies = get_tree().get_nodes_in_group("enemies")
    for enemy in enemies:
        enemy.queue_free()

func get_current_wave_config():
    return wave_configs.get(current_wave, {})
```

**Step 2: 添加到主场景**

在 main.tscn 中添加 WaveManager 节点

**Step 3: 测试波次系统**

运行游戏，观察波次倒计时和切换

**Step 4: 提交**

```bash
git add scripts/wave_manager.gd scenes/main.tscn
git commit -m "feat(phase2): 实现10波次管理系统"
```

---

## Task 4: 实现敌人生成器

**Files:**
- Create: `scripts/enemy_spawner.gd`
- Modify: `scenes/main.tscn`

**Step 1: 创建生成器脚本**

```gdscript
extends Node2D

var enemy_scenes = {
    "normal": preload("res://scenes/enemies/enemy_normal.tscn"),
    "fast": preload("res://scenes/enemies/enemy_fast.tscn"),
    "tank": preload("res://scenes/enemies/enemy_tank.tscn")
}

var spawn_timer: float = 0.0
var wave_manager: Node
var camera: Camera2D
var spawn_distance: float = 100.0

func _ready():
    wave_manager = get_node("../WaveManager")
    camera = get_tree().get_first_node_in_group("camera")
    wave_manager.wave_started.connect(_on_wave_started)

func _process(delta):
    if wave_manager.is_wave_active:
        spawn_timer -= delta
        if spawn_timer <= 0:
            spawn_enemy()
            var config = wave_manager.get_current_wave_config()
            spawn_timer = config.get("spawn_interval", 3.0)

func spawn_enemy():
    var config = wave_manager.get_current_wave_config()
    var current_enemies = get_tree().get_nodes_in_group("enemies").size()

    if current_enemies >= config.get("max_enemies", 20):
        return

    var enemy_types = config.get("enemy_types", ["normal"])
    var random_type = enemy_types[randi() % enemy_types.size()]
    var enemy = enemy_scenes[random_type].instantiate()

    var spawn_pos = get_random_spawn_position()
    enemy.global_position = spawn_pos
    get_parent().add_child(enemy)

func get_random_spawn_position() -> Vector2:
    if not camera:
        return Vector2.ZERO

    var viewport_size = get_viewport_rect().size
    var camera_pos = camera.global_position

    var side = randi() % 4
    var pos = Vector2.ZERO

    match side:
        0: # 上
            pos = Vector2(randf_range(-viewport_size.x/2, viewport_size.x/2), -viewport_size.y/2 - spawn_distance)
        1: # 下
            pos = Vector2(randf_range(-viewport_size.x/2, viewport_size.x/2), viewport_size.y/2 + spawn_distance)
        2: # 左
            pos = Vector2(-viewport_size.x/2 - spawn_distance, randf_range(-viewport_size.y/2, viewport_size.y/2))
        3: # 右
            pos = Vector2(viewport_size.x/2 + spawn_distance, randf_range(-viewport_size.y/2, viewport_size.y/2))

    return camera_pos + pos

func _on_wave_started(wave_number: int):
    spawn_timer = 0.0
```

**Step 2: 添加到主场景**

在 main.tscn 中添加 EnemySpawner 节点

**Step 3: 测试敌人生成**

运行游戏，观察敌人从屏幕边缘生成

**Step 4: 提交**

```bash
git add scripts/enemy_spawner.gd scenes/main.tscn
git commit -m "feat(phase2): 实现敌人生成系统"
```

---

## Task 5: 实现金币系统

**Files:**
- Create: `scenes/coin.tscn`
- Create: `scripts/coin.gd`
- Modify: `scripts/enemy.gd`
- Modify: `scripts/player.gd`

**Step 1: 创建金币场景**

```
mcp__gdai-mcp__create_scene
- file_path: "res://scenes/coin.tscn"
- node_type: "Area2D"
- node_name: "Coin"
```

添加黄色 ColorRect (16x16)

**Step 2: 编写金币脚本**

```gdscript
extends Area2D

@export var value: int = 1
@export var attract_speed: float = 500.0
@export var attract_range: float = 150.0

var player: Node2D = null
var is_attracted: bool = false

func _ready():
    body_entered.connect(_on_body_entered)
    player = get_tree().get_first_node_in_group("player")

func _process(delta):
    if player and global_position.distance_to(player.global_position) < attract_range:
        is_attracted = true

    if is_attracted and player:
        var direction = global_position.direction_to(player.global_position)
        global_position += direction * attract_speed * delta

func _on_body_entered(body):
    if body.is_in_group("player"):
        body.add_coins(value)
        queue_free()
```

**Step 3: 配置碰撞层**

collision_layer = 5, collision_mask = 1

**Step 4: 修改敌人掉落金币**

在 enemy.gd 的 die() 函数中：
```gdscript
func die():
    drop_coins()
    queue_free()

func drop_coins():
    var coin_scene = preload("res://scenes/coin.tscn")
    var coin_count = randi_range(1, 3)
    for i in coin_count:
        var coin = coin_scene.instantiate()
        coin.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
        get_parent().add_child(coin)
```

**Step 5: 修改玩家添加金币计数**

在 player.gd 中添加：
```gdscript
var coins: int = 0

func add_coins(amount: int):
    coins += amount
    print("Coins: ", coins)
```

**Step 6: 测试金币系统**

运行游戏，击杀敌人观察金币掉落和拾取

**Step 7: 提交**

```bash
git add scenes/coin.tscn scripts/coin.gd scripts/enemy.gd scripts/player.gd
git commit -m "feat(phase2): 实现金币掉落和拾取系统"
```

---

## Task 6: 完善HUD显示

**Files:**
- Modify: `scenes/ui/hud.tscn`
- Modify: `scripts/hud.gd`

**Step 1: 添加金币和波次显示**

在 HUD 中添加 Label 节点显示：
- 当前波次
- 波次倒计时
- 金币数量

**Step 2: 更新HUD脚本**

```gdscript
extends CanvasLayer

@onready var hp_bar = $HPBar
@onready var timer_label = $TimerLabel
@onready var wave_label = $WaveLabel
@onready var coin_label = $CoinLabel

var player: Node2D
var wave_manager: Node

func _ready():
    player = get_tree().get_first_node_in_group("player")
    wave_manager = get_node("../WaveManager")

func _process(delta):
    if player:
        hp_bar.value = player.current_hp / player.max_hp * 100
        coin_label.text = "Coins: %d" % player.coins

    if wave_manager:
        timer_label.text = "Time: %.0f" % wave_manager.wave_time_left
        wave_label.text = "Wave: %d/%d" % [wave_manager.current_wave, wave_manager.total_waves]
```

**Step 3: 测试HUD更新**

运行游戏，确认所有信息正确显示

**Step 4: 提交**

```bash
git add scenes/ui/hud.tscn scripts/hud.gd
git commit -m "feat(phase2): 完善HUD显示金币和波次信息"
```

---

## Task 7: 实现波次结束金币飞向玩家

**Files:**
- Modify: `scripts/wave_manager.gd`
- Modify: `scripts/coin.gd`

**Step 1: 修改波次完成逻辑**

在 wave_manager.gd 的 complete_wave() 中：
```gdscript
func complete_wave():
    is_wave_active = false
    attract_all_coins()
    await get_tree().create_timer(2.0).timeout
    clear_all_enemies()
    wave_completed.emit(current_wave)

func attract_all_coins():
    var coins = get_tree().get_nodes_in_group("coins")
    for coin in coins:
        coin.force_attract()
```

**Step 2: 修改金币脚本**

在 coin.gd 中添加：
```gdscript
func _ready():
    add_to_group("coins")
    # ... 其他代码

func force_attract():
    is_attracted = true
    attract_speed = 800.0
```

**Step 3: 测试波次结束**

运行游戏，观察波次结束时金币飞向玩家

**Step 4: 提交**

```bash
git add scripts/wave_manager.gd scripts/coin.gd
git commit -m "feat(phase2): 实现波次结束金币自动飞向玩家"
```

---

## 阶段2完成验证

运行游戏，确认以下功能正常：
- [ ] 3种敌人类型正确生成和行为
- [ ] 3种植物塔功能正常（射击、阻挡、减速）
- [ ] 10波次系统正确运行
- [ ] 难度曲线明显递进
- [ ] 金币掉落、拾取、波次结束飞向玩家
- [ ] HUD正确显示所有信息

全部通过后，进入阶段3。

---

**阶段2预计完成时间**: 2-3天
