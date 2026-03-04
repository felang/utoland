# 阶段 1：核心战斗原型实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 验证核心手感（走位+自动射击+怪物追击+塔阻挡）

**Architecture:** 创建最小可玩版本，包含玩家、单一敌人类型、预设塔、60秒生存测试

**Tech Stack:** Godot 4.6, GDScript, GDAI MCP Plugin

---

## Task 1: 创建主场景和玩家

**Files:**
- Create: `scenes/main.tscn`
- Create: `scenes/player.tscn`
- Create: `scripts/player.gd`

**Step 1: 创建主场景**

使用 MCP 工具创建主场景：
```
mcp__gdai-mcp__create_scene
- file_path: "res://scenes/main.tscn"
- node_type: "Node2D"
- node_name: "Main"
```

**Step 2: 创建玩家场景**

```
mcp__gdai-mcp__create_scene
- file_path: "res://scenes/player.tscn"
- node_type: "CharacterBody2D"
- node_name: "Player"
```

**Step 3: 添加玩家视觉占位符**

在 player.tscn 中添加 ColorRect：
```
mcp__gdai-mcp__add_node
- parent_node_path: "."
- node_type: "ColorRect"
- node_name: "Visual"
- properties: '{"size": Vector2(32, 32), "position": Vector2(-16, -16), "color": Color(0, 1, 0, 1)}'
```

**Step 4: 编写玩家移动脚本**

创建 `scripts/player.gd`：
```gdscript
extends CharacterBody2D

@export var speed: float = 200.0
@export var max_hp: float = 100.0
var current_hp: float = 100.0

func _physics_process(delta):
    var input_vector = Vector2.ZERO
    input_vector.x = Input.get_axis("ui_left", "ui_right")
    input_vector.y = Input.get_axis("ui_up", "ui_down")

    if input_vector.length() > 0:
        input_vector = input_vector.normalized()

    velocity = input_vector * speed
    move_and_slide()

func take_damage(amount: float):
    current_hp -= amount
    if current_hp <= 0:
        die()

func die():
    print("Player died!")
    get_tree().reload_current_scene()
```

**Step 5: 配置碰撞层**

设置 Player 的 collision_layer = 1, collision_mask = 2

**Step 6: 测试玩家移动**

运行场景，使用 WASD 测试移动

**Step 7: 提交**

```bash
git add scenes/player.tscn scenes/main.tscn scripts/player.gd
git commit -m "feat(phase1): 添加玩家移动功能"
```

---

## Task 2: 添加摄像机跟随

**Files:**
- Modify: `scenes/player.tscn`

**Step 1: 添加 Camera2D 节点**

```
mcp__gdai-mcp__add_node
- parent_node_path: "."
- node_type: "Camera2D"
- node_name: "Camera"
```

**Step 2: 配置摄像机属性**

```
mcp__gdai-mcp__update_property
- node_path: "Camera"
- property_path: "enabled"
- value: "true"
```

**Step 3: 测试摄像机跟随**

运行场景，确认摄像机跟随玩家移动

**Step 4: 提交**

```bash
git add scenes/player.tscn
git commit -m "feat(phase1): 添加摄像机跟随"
```

---

## Task 3: 创建子弹系统

**Files:**
- Create: `scenes/bullet.tscn`
- Create: `scripts/bullet.gd`

**Step 1: 创建子弹场景**

```
mcp__gdai-mcp__create_scene
- file_path: "res://scenes/bullet.tscn"
- node_type: "Area2D"
- node_name: "Bullet"
```

**Step 2: 添加视觉和碰撞**

添加 ColorRect 和 CollisionShape2D

**Step 3: 编写子弹脚本**

```gdscript
extends Area2D

var speed: float = 400.0
var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0

func _ready():
    body_entered.connect(_on_body_entered)

func _physics_process(delta):
    position += direction * speed * delta

func _on_body_entered(body):
    if body.is_in_group("enemies"):
        body.take_damage(damage)
        queue_free()
```

**Step 4: 配置碰撞层**

collision_layer = 4, collision_mask = 2

**Step 5: 提交**

```bash
git add scenes/bullet.tscn scripts/bullet.gd
git commit -m "feat(phase1): 添加子弹系统"
```

---

## Task 4: 实现自动射击

**Files:**
- Modify: `scripts/player.gd`

**Step 1: 添加武器变量和射击逻辑**

在 player.gd 中添加：
```gdscript
@export var weapon_range: float = 300.0
@export var fire_rate: float = 0.1
var shoot_timer: float = 0.0
var bullet_scene = preload("res://scenes/bullet.tscn")

func _process(delta):
    shoot_timer -= delta
    if shoot_timer <= 0:
        auto_shoot()

func auto_shoot():
    var enemies = get_tree().get_nodes_in_group("enemies")
    var closest_enemy = null
    var min_distance = weapon_range

    for enemy in enemies:
        var distance = global_position.distance_to(enemy.global_position)
        if distance < min_distance:
            min_distance = distance
            closest_enemy = enemy

    if closest_enemy:
        shoot_bullet(closest_enemy.global_position)
        shoot_timer = fire_rate

func shoot_bullet(target_pos: Vector2):
    var bullet = bullet_scene.instantiate()
    bullet.global_position = global_position
    bullet.direction = global_position.direction_to(target_pos)
    get_parent().add_child(bullet)
```

**Step 2: 测试射击**

暂时无法测试（需要敌人），继续下一步

**Step 3: 提交**

```bash
git add scripts/player.gd
git commit -m "feat(phase1): 实现自动射击系统"
```

---

## Task 5: 创建敌人系统

**Files:**
- Create: `scenes/enemies/enemy_normal.tscn`
- Create: `scripts/enemy.gd`

**Step 1: 创建敌人场景**

```
mcp__gdai-mcp__create_scene
- file_path: "res://scenes/enemies/enemy_normal.tscn"
- node_type: "CharacterBody2D"
- node_name: "EnemyNormal"
```

**Step 2: 添加视觉占位符**

添加红色 ColorRect (32x32)

**Step 3: 编写敌人脚本**

```gdscript
extends CharacterBody2D

enum State { CHASE_PLAYER, ATTACK_TOWER }

@export var speed: float = 150.0
@export var max_hp: float = 30.0
@export var touch_damage: float = 10.0
@export var tower_attack_damage: float = 5.0
@export var tower_attack_rate: float = 1.0

var current_hp: float = 30.0
var current_state = State.CHASE_PLAYER
var target_tower = null
var attack_timer: float = 0.0
var player: Node2D = null

func _ready():
    add_to_group("enemies")
    player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
    attack_timer -= delta

    match current_state:
        State.CHASE_PLAYER:
            chase_player()
        State.ATTACK_TOWER:
            attack_tower(delta)

func chase_player():
    if player:
        velocity = position.direction_to(player.global_position) * speed
        move_and_slide()

        for i in get_slide_collision_count():
            var collision = get_slide_collision(i)
            if collision.get_collider().is_in_group("towers"):
                current_state = State.ATTACK_TOWER
                target_tower = collision.get_collider()
                velocity = Vector2.ZERO

func attack_tower(delta):
    if not is_instance_valid(target_tower):
        current_state = State.CHASE_PLAYER
        return

    if attack_timer <= 0:
        target_tower.take_damage(tower_attack_damage)
        attack_timer = tower_attack_rate

func take_damage(amount: float):
    current_hp -= amount
    if current_hp <= 0:
        die()

func die():
    queue_free()
```

**Step 4: 配置碰撞层**

collision_layer = 2, collision_mask = 1 | 3

**Step 5: 添加玩家组标记**

在 player.gd 的 _ready() 中添加：
```gdscript
add_to_group("player")
```

**Step 6: 提交**

```bash
git add scenes/enemies/enemy_normal.tscn scripts/enemy.gd
git commit -m "feat(phase1): 添加敌人追击和攻击塔逻辑"
```

---

## Task 6: 创建敌人生成器

**Files:**
- Create: `scripts/enemy_spawner.gd`
- Modify: `scenes/main.tscn`

**Step 1: 在主场景添加生成器节点**

```
mcp__gdai-mcp__add_node
- parent_node_path: "."
- node_type: "Node"
- node_name: "EnemySpawner"
```

**Step 2: 编写生成器脚本**

```gdscript
extends Node

@export var spawn_interval: float = 5.0
@export var max_enemies: int = 20
@export var spawn_distance: float = 600.0

var enemy_scene = preload("res://scenes/enemies/enemy_normal.tscn")
var spawn_timer: float = 0.0
var player: Node2D = null

func _ready():
    player = get_tree().get_first_node_in_group("player")

func _process(delta):
    spawn_timer -= delta

    if spawn_timer <= 0:
        var current_enemies = get_tree().get_nodes_in_group("enemies").size()
        if current_enemies < max_enemies:
            spawn_enemy()
        spawn_timer = spawn_interval

func spawn_enemy():
    if not player:
        return

    var angle = randf() * TAU
    var offset = Vector2(cos(angle), sin(angle)) * spawn_distance
    var spawn_pos = player.global_position + offset

    var enemy = enemy_scene.instantiate()
    enemy.global_position = spawn_pos
    get_parent().add_child(enemy)
```

**Step 3: 附加脚本到节点**

```
mcp__gdai-mcp__attach_script
- node_path: "EnemySpawner"
- script_path: "res://scripts/enemy_spawner.gd"
```

**Step 4: 测试敌人生成和追击**

运行场景，观察敌人生成并追击玩家

**Step 5: 提交**

```bash
git add scripts/enemy_spawner.gd scenes/main.tscn
git commit -m "feat(phase1): 添加敌人生成器"
```

---

## Task 7: 创建植物塔（坚果墙）

**Files:**
- Create: `scenes/towers/tower_wall.tscn`
- Create: `scripts/tower.gd`

**Step 1: 创建塔场景**

```
mcp__gdai-mcp__create_scene
- file_path: "res://scenes/towers/tower_wall.tscn"
- node_type: "StaticBody2D"
- node_name: "TowerWall"
```

**Step 2: 添加视觉占位符**

添加棕色 ColorRect (48x48)

**Step 3: 编写塔脚本**

```gdscript
extends StaticBody2D

@export var max_hp: float = 300.0
var current_hp: float = 300.0

func _ready():
    add_to_group("towers")

func take_damage(amount: float):
    current_hp -= amount
    if current_hp <= 0:
        die()

func die():
    queue_free()
```

**Step 4: 配置碰撞层**

collision_layer = 3, collision_mask = 2

**Step 5: 在主场景预设3个塔**

在 main.tscn 中手动放置3个 TowerWall 实例在地图中央附近

**Step 6: 测试塔阻挡**

运行场景，观察敌人碰到塔后停止并攻击

**Step 7: 提交**

```bash
git add scenes/towers/tower_wall.tscn scripts/tower.gd scenes/main.tscn
git commit -m "feat(phase1): 添加坚果墙和阻挡机制"
```

---

## Task 8: 添加简单HUD

**Files:**
- Create: `scenes/ui/hud.tscn`
- Create: `scripts/hud.gd`
- Modify: `scenes/main.tscn`

**Step 1: 创建HUD场景**

```
mcp__gdai-mcp__create_scene
- file_path: "res://scenes/ui/hud.tscn"
- node_type: "CanvasLayer"
- node_name: "HUD"
```

**Step 2: 添加UI元素**

添加 Label 节点显示血条和倒计时

**Step 3: 编写HUD脚本**

```gdscript
extends CanvasLayer

@onready var hp_label = $HPLabel
@onready var timer_label = $TimerLabel

var player: Node2D = null

func _ready():
    player = get_tree().get_first_node_in_group("player")

func _process(delta):
    if player:
        hp_label.text = "HP: %.0f" % player.current_hp
```

**Step 4: 添加到主场景**

将 HUD 实例添加到 main.tscn

**Step 5: 提交**

```bash
git add scenes/ui/hud.tscn scripts/hud.gd scenes/main.tscn
git commit -m "feat(phase1): 添加简单HUD显示"
```

---

## Task 9: 实现60秒生存测试

**Files:**
- Create: `scripts/wave_manager.gd`
- Modify: `scenes/main.tscn`

**Step 1: 添加波次管理器节点**

```
mcp__gdai-mcp__add_node
- parent_node_path: "."
- node_type: "Node"
- node_name: "WaveManager"
```

**Step 2: 编写波次管理器脚本**

```gdscript
extends Node

@export var wave_duration: float = 60.0
var time_remaining: float = 60.0

func _ready():
    pass

func _process(delta):
    time_remaining -= delta

    if time_remaining <= 0:
        victory()

func victory():
    print("Victory! You survived 60 seconds!")
    get_tree().reload_current_scene()
```

**Step 3: 更新HUD显示倒计时**

在 hud.gd 中添加：
```gdscript
var wave_manager: Node = null

func _ready():
    player = get_tree().get_first_node_in_group("player")
    wave_manager = get_tree().get_first_node_in_group("wave_manager")

func _process(delta):
    if player:
        hp_label.text = "HP: %.0f" % player.current_hp
    if wave_manager:
        timer_label.text = "Time: %.0f" % wave_manager.time_remaining
```

在 wave_manager.gd 的 _ready() 中添加：
```gdscript
add_to_group("wave_manager")
```

**Step 4: 测试完整流程**

运行场景，测试60秒生存

**Step 5: 提交**

```bash
git add scripts/wave_manager.gd scripts/hud.gd scenes/main.tscn
git commit -m "feat(phase1): 实现60秒生存测试"
```

---

## Task 10: 添加玩家受伤机制

**Files:**
- Modify: `scripts/player.gd`
- Modify: `scripts/enemy.gd`

**Step 1: 在玩家添加受伤冷却**

在 player.gd 中添加：
```gdscript
@export var invincible_duration: float = 0.5
var invincible_timer: float = 0.0

func _process(delta):
    invincible_timer -= delta
    shoot_timer -= delta
    if shoot_timer <= 0:
        auto_shoot()

func _physics_process(delta):
    var input_vector = Vector2.ZERO
    input_vector.x = Input.get_axis("ui_left", "ui_right")
    input_vector.y = Input.get_axis("ui_up", "ui_down")

    if input_vector.length() > 0:
        input_vector = input_vector.normalized()

    velocity = input_vector * speed
    move_and_slide()

    check_enemy_collision()

func check_enemy_collision():
    for i in get_slide_collision_count():
        var collision = get_slide_collision(i)
        if collision.get_collider().is_in_group("enemies"):
            if invincible_timer <= 0:
                var enemy = collision.get_collider()
                take_damage(enemy.touch_damage)
                invincible_timer = invincible_duration

func take_damage(amount: float):
    current_hp -= amount
    print("Player HP: ", current_hp)
    if current_hp <= 0:
        die()
```

**Step 2: 测试受伤机制**

运行场景，让敌人触碰玩家，观察血量下降

**Step 3: 提交**

```bash
git add scripts/player.gd
git commit -m "feat(phase1): 添加玩家受伤和无敌时间"
```

---

## 阶段1完成检查清单

- [ ] 玩家可以用WASD移动
- [ ] 摄像机跟随玩家
- [ ] 玩家自动射击最近的敌人
- [ ] 敌人从屏幕边缘生成并追击玩家
- [ ] 敌人碰到塔后停止并攻击塔
- [ ] 玩家被敌人触碰会受伤
- [ ] HUD显示血条和倒计时
- [ ] 60秒后显示胜利
- [ ] 血量归零后重新开始

---

**阶段1预计完成时间**: 2-3天
