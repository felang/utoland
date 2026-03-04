# 阶段 3：商店与成长系统实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 补全游戏流程（商店+成长+完整UI）

**Architecture:** 在阶段2基础上添加完整游戏流程、商店系统、武器选择、被动属性强化、布置系统

**Tech Stack:** Godot 4.6, GDScript, GDAI MCP Plugin

---

## Task 1: 创建开始菜单

**Files:**
- Create: `scenes/ui/start_menu.tscn`
- Create: `scripts/start_menu.gd`

**Step 1: 创建开始菜单场景**

```
mcp__gdai-mcp__create_scene
- file_path: "res://scenes/ui/start_menu.tscn"
- node_type: "Control"
- node_name: "StartMenu"
```

**Step 2: 添加UI元素**

添加 VBoxContainer，包含：
- Label (游戏标题)
- Button (开始游戏)

**Step 3: 编写脚本**

```gdscript
extends Control

func _ready():
    $VBoxContainer/StartButton.pressed.connect(_on_start_pressed)

func _on_start_pressed():
    get_tree().change_scene_to_file("res://scenes/ui/weapon_select.tscn")
```

**Step 4: 提交**

```bash
git add scenes/ui/start_menu.tscn scripts/start_menu.gd
git commit -m "feat(phase3): 添加开始菜单"
```

---

## Task 2: 创建武器选择界面

**Files:**
- Create: `scenes/ui/weapon_select.tscn`
- Create: `scripts/weapon_select.gd`
- Create: `scripts/game_data.gd` (全局数据)

**Step 1: 创建全局游戏数据**

```gdscript
extends Node

var selected_weapon: String = "rifle"
var player_stats = {
    "max_hp": 100.0,
    "hp_regen": 0.0,
    "damage_mult": 1.0,
    "attack_speed_mult": 1.0,
    "move_speed_mult": 1.0,
    "tower_mult": 1.0
}
var coins: int = 50
var current_wave: int = 0
var tower_inventory = []

func reset():
    selected_weapon = "rifle"
    player_stats = {
        "max_hp": 100.0,
        "hp_regen": 0.0,
        "damage_mult": 1.0,
        "attack_speed_mult": 1.0,
        "move_speed_mult": 1.0,
        "tower_mult": 1.0
    }
    coins = 50
    current_wave = 0
    tower_inventory = []
```

在 project.godot 中添加 autoload: GameData

**Step 2: 创建武器选择场景**

添加两个武器选项按钮：
- 速射枪
- 爆裂霰弹

**Step 3: 编写脚本**

```gdscript
extends Control

func _ready():
    $VBoxContainer/RifleButton.pressed.connect(_on_rifle_selected)
    $VBoxContainer/ShotgunButton.pressed.connect(_on_shotgun_selected)

func _on_rifle_selected():
    GameData.selected_weapon = "rifle"
    start_game()

func _on_shotgun_selected():
    GameData.selected_weapon = "shotgun"
    start_game()

func start_game():
    get_tree().change_scene_to_file("res://scenes/placement.tscn")
```

**Step 4: 提交**

```bash
git add scenes/ui/weapon_select.tscn scripts/weapon_select.gd scripts/game_data.gd
git commit -m "feat(phase3): 添加武器选择和全局数据"
```

---

## Task 3: 实现初始布置系统

**Files:**
- Create: `scenes/placement.tscn`
- Create: `scripts/placement.gd`

**Step 1: 创建布置场景**

基于 main.tscn 创建，但不包含敌人生成

**Step 2: 编写布置脚本**

```gdscript
extends Node2D

const GRID_SIZE = 32
var selected_tower_type: String = ""
var preview_tower: Node2D = null
var tower_scenes = {
    "shooter": preload("res://scenes/towers/tower_shooter.tscn"),
    "wall": preload("res://scenes/towers/tower_wall.tscn"),
    "slow": preload("res://scenes/towers/tower_slow.tscn")
}
var tower_costs = {
    "shooter": 30,
    "wall": 40,
    "slow": 35
}

func _ready():
    update_ui()

func _input(event):
    if event is InputEventMouseMotion and preview_tower:
        var grid_pos = get_grid_position(get_global_mouse_position())
        preview_tower.global_position = grid_pos

    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT and preview_tower:
            place_tower()
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            cancel_placement()

func select_tower(type: String):
    if GameData.coins < tower_costs[type]:
        return

    selected_tower_type = type
    if preview_tower:
        preview_tower.queue_free()

    preview_tower = tower_scenes[type].instantiate()
    preview_tower.modulate = Color(1, 1, 1, 0.5)
    add_child(preview_tower)

func place_tower():
    if not can_place_at(preview_tower.global_position):
        return

    GameData.coins -= tower_costs[selected_tower_type]
    preview_tower.modulate = Color(1, 1, 1, 1)
    preview_tower = null
    selected_tower_type = ""
    update_ui()

func can_place_at(pos: Vector2) -> bool:
    # 检查是否与其他塔重叠
    var towers = get_tree().get_nodes_in_group("towers")
    for tower in towers:
        if tower.global_position.distance_to(pos) < GRID_SIZE:
            return false
    return true

func get_grid_position(pos: Vector2) -> Vector2:
    return Vector2(
        floor(pos.x / GRID_SIZE) * GRID_SIZE + GRID_SIZE / 2,
        floor(pos.y / GRID_SIZE) * GRID_SIZE + GRID_SIZE / 2
    )

func start_battle():
    # 保存塔的位置到 GameData
    var towers = get_tree().get_nodes_in_group("towers")
    GameData.tower_inventory = []
    for tower in towers:
        GameData.tower_inventory.append({
            "type": tower.name,
            "position": tower.global_position
        })

    get_tree().change_scene_to_file("res://scenes/main.tscn")
```

**Step 3: 添加UI按钮**

添加塔选择按钮和"开始战斗"按钮

**Step 4: 提交**

```bash
git add scenes/placement.tscn scripts/placement.gd
git commit -m "feat(phase3): 实现初始布置系统"
```

---

## Task 4: 创建商店系统

**Files:**
- Create: `scenes/ui/shop.tscn`
- Create: `scripts/shop_manager.gd`

**Step 1: 创建商店场景**

全屏 Control，包含：
- 4个商品槽位
- 刷新按钮
- 确认按钮
- 金币显示

**Step 2: 编写商店管理器**

```gdscript
extends Control

const REFRESH_COST = 10

var shop_items = []
var passive_upgrades = [
    {"name": "最大生命值+20", "cost": 25, "stat": "max_hp", "value": 20},
    {"name": "生命回复+5/5秒", "cost": 20, "stat": "hp_regen", "value": 5},
    {"name": "伤害+10%", "cost": 30, "stat": "damage_mult", "value": 0.1},
    {"name": "攻击速度+15%", "cost": 25, "stat": "attack_speed_mult", "value": 0.15},
    {"name": "移动速度+10%", "cost": 20, "stat": "move_speed_mult", "value": 0.1},
    {"name": "工程学+20%", "cost": 35, "stat": "tower_mult", "value": 0.2}
]
var tower_items = [
    {"name": "豌豆射手", "cost": 30, "type": "shooter"},
    {"name": "坚果墙", "cost": 40, "type": "wall"},
    {"name": "冰雪菇", "cost": 35, "type": "slow"}
]
var consumables = [
    {"name": "医疗包", "cost": 15, "effect": "heal", "value": 50}
]

func _ready():
    refresh_shop()
    update_ui()

func refresh_shop():
    shop_items = []
    for i in range(4):
        var rand = randf()
        if rand < 0.6:  # 60% 被动属性
            shop_items.append(passive_upgrades.pick_random())
        elif rand < 0.9:  # 30% 植物塔
            shop_items.append(tower_items.pick_random())
        else:  # 10% 消耗品
            shop_items.append(consumables.pick_random())

    display_items()

func buy_item(index: int):
    var item = shop_items[index]
    if GameData.coins < item["cost"]:
        return

    GameData.coins -= item["cost"]

    if item.has("stat"):  # 被动属性
        if item["stat"].ends_with("_mult"):
            GameData.player_stats[item["stat"]] += item["value"]
        else:
            GameData.player_stats[item["stat"]] += item["value"]
    elif item.has("type"):  # 植物塔
        GameData.tower_inventory.append(item["type"])
    elif item.has("effect"):  # 消耗品
        apply_consumable(item)

    update_ui()

func apply_consumable(item):
    if item["effect"] == "heal":
        # 在战斗场景中应用
        pass

func on_refresh_pressed():
    if GameData.coins < REFRESH_COST:
        return
    GameData.coins -= REFRESH_COST
    refresh_shop()

func on_confirm_pressed():
    if GameData.tower_inventory.size() > 0:
        get_tree().change_scene_to_file("res://scenes/placement.tscn")
    else:
        start_next_wave()

func start_next_wave():
    get_tree().change_scene_to_file("res://scenes/main.tscn")
```

**Step 3: 连接到波次系统**

修改 wave_manager.gd，波次结束后打开商店

**Step 4: 提交**

```bash
git add scenes/ui/shop.tscn scripts/shop_manager.gd
git commit -m "feat(phase3): 实现商店系统"
```

---

## Task 5: 创建结算界面

**Files:**
- Create: `scenes/ui/result.tscn`
- Create: `scripts/result.gd`

**Step 1: 创建结算场景**

显示：
- 胜利/失败文本
- 存活波次
- 击杀数
- 重新开始按钮
- 退出按钮

**Step 2: 编写脚本**

```gdscript
extends Control

func _ready():
    if GameData.current_wave >= 10:
        $Label.text = "胜利！"
    else:
        $Label.text = "失败"

    $WaveLabel.text = "存活波次: %d" % GameData.current_wave
    $RestartButton.pressed.connect(_on_restart)
    $QuitButton.pressed.connect(_on_quit)

func _on_restart():
    GameData.reset()
    get_tree().change_scene_to_file("res://scenes/ui/start_menu.tscn")

func _on_quit():
    get_tree().quit()
```

**Step 3: 连接到游戏失败/胜利**

修改 player.gd 和 wave_manager.gd

**Step 4: 提交**

```bash
git add scenes/ui/result.tscn scripts/result.gd
git commit -m "feat(phase3): 实现结算界面"
```

---

## Task 6: 整合完整游戏流程

**Files:**
- Modify: `scripts/player.gd`
- Modify: `scripts/wave_manager.gd`
- Modify: `scenes/main.tscn`

**Step 1: 应用玩家属性**

在 player.gd 的 _ready() 中：
```gdscript
func _ready():
    max_hp = GameData.player_stats["max_hp"]
    current_hp = max_hp
    speed = 200.0 * (1.0 + GameData.player_stats["move_speed_mult"])

    # 应用武器
    if GameData.selected_weapon == "rifle":
        fire_rate = 0.1 * (1.0 - GameData.player_stats["attack_speed_mult"])
        weapon_damage = 10.0 * GameData.player_stats["damage_mult"]
    elif GameData.selected_weapon == "shotgun":
        fire_rate = 1.5 * (1.0 - GameData.player_stats["attack_speed_mult"])
        weapon_damage = 50.0 * GameData.player_stats["damage_mult"]
```

**Step 2: 恢复塔的位置**

在 main.tscn 的脚本中加载保存的塔

**Step 3: 连接场景转换**

- 玩家死亡 → result.tscn
- 第10波完成 → result.tscn
- 波次完成 → shop.tscn

**Step 4: 完整测试**

从开始菜单到结算的完整流程

**Step 5: 提交**

```bash
git add scripts/player.gd scripts/wave_manager.gd scenes/main.tscn
git commit -m "feat(phase3): 整合完整游戏流程"
```

---

## Task 7: 最终调优和测试

**Step 1: 平衡性测试**

测试10波是否可以通关，调整：
- 金币掉落数量
- 商品价格
- 敌人血量和伤害
- 塔的效果

**Step 2: 修复bug**

测试并修复发现的问题

**Step 3: 最终提交**

```bash
git add .
git commit -m "feat(phase3): 阶段3完成，MVP可玩"
```

---

**阶段3完成标志**：
- 可以从开始菜单完整游玩到结算
- 商店系统正常工作
- 被动属性生效
- 布置系统可用
- 10波难度递进合理
