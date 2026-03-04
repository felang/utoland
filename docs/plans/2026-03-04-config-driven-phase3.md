# 阶段 3：调试工具开发

**目标:** 实现调试面板、快捷键系统和配置热重载功能

**预计时间:** 60-90 分钟

---

## Task 8: 创建调试管理器单例

**Files:**
- Create: `scripts/debug_manager.gd`

**Step 1: 创建调试管理器骨架**

```gdscript
extends Node

# 调试工具管理器
# 提供游戏内调试功能和快捷键

var debug_panel_scene = null
var debug_panel_instance = null
var debug_info_visible = false

func _ready():
	if not GameConfig.DEBUG_MODE:
		return

	print("=== 调试管理器已启动 ===")
	print("F12: 开关调试面板")
	print("F11: 开关调试信息")
	print("F9:  重载配置")
	print("F1:  无敌模式")
	print("F2:  +1000金币")
	print("F3:  跳到下一波")
	print("F4:  清除所有敌人")
	print("F5:  生成10个测试敌人")

func _input(event):
	if not GameConfig.DEBUG_MODE:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F12:
				toggle_debug_panel()
			KEY_F11:
				toggle_debug_info()
			KEY_F9:
				reload_config()
			KEY_F1:
				toggle_god_mode()
			KEY_F2:
				add_coins(1000)
			KEY_F3:
				next_wave()
			KEY_F4:
				clear_enemies()
			KEY_F5:
				spawn_test_enemies()

func toggle_debug_panel():
	print("[调试] F12: 调试面板功能待实现")

func toggle_debug_info():
	debug_info_visible = not debug_info_visible
	print("[调试] F11: 调试信息显示 ", "开启" if debug_info_visible else "关闭")

func reload_config():
	print("[调试] F9: 配置热重载功能待实现")

func toggle_god_mode():
	print("[调试] F1: 无敌模式功能待实现")

func add_coins(amount: int):
	GameData.coins += amount
	print("[调试] F2: 添加 ", amount, " 金币，当前: ", GameData.coins)

func next_wave():
	print("[调试] F3: 跳波功能待实现")

func clear_enemies():
	print("[调试] F4: 清除敌人功能待实现")

func spawn_test_enemies():
	print("[调试] F5: 生成测试敌人功能待实现")
```

**Step 2: 注册为自动加载单例**

在 Godot 编辑器中：
1. 项目 -> 项目设置 -> 自动加载
2. 路径：`res://scripts/debug_manager.gd`
3. 节点名称：`DebugManager`
4. 勾选"启用"
5. 点击"添加"

**Step 3: 测试基础快捷键**

运行游戏，按 F2 键：

预期输出：
```
[调试] F2: 添加 1000 金币，当前: 1100
```

**Step 4: 提交**

```bash
git add scripts/debug_manager.gd project.godot
git commit -m "feat: 创建调试管理器和基础快捷键"
```

---

## Task 9: 实现调试信息显示

**Files:**
- Create: `scenes/debug/debug_info.tscn`
- Create: `scripts/debug_info.gd`

**Step 1: 创建调试信息场景**

在 Godot 编辑器中：
1. 创建新场景
2. 根节点类型：CanvasLayer
3. 添加子节点：Label
4. Label 设置：
   - Name: DebugLabel
   - Position: (10, 10)
   - Theme Overrides -> Font Size: 14
   - Theme Overrides -> Font Color: 黄色 (#FFFF00)
5. 保存为 `scenes/debug/debug_info.tscn`

**Step 2: 创建调试信息脚本**

创建 `scripts/debug_info.gd`：

```gdscript
extends CanvasLayer

@onready var label = $DebugLabel

func _ready():
	visible = false

func _process(_delta):
	if not visible:
		return

	update_debug_info()

func update_debug_info():
	var fps = Engine.get_frames_per_second()
	var wave = GameData.current_wave
	var total_waves = GameConfig.WAVES["total_waves"]
	var coins = GameData.coins
	var hp = 0
	var max_hp = 0

	# 获取玩家血量
	var player = get_tree().get_first_node_in_group("player")
	if player:
		hp = int(player.current_hp) if "current_hp" in player else 0
		max_hp = int(player.max_hp) if "max_hp" in player else 0

	# 获取敌人数量
	var enemy_count = get_tree().get_nodes_in_group("enemies").size()

	# 获取塔数量
	var tower_count = GameData.tower_inventory.size()

	var text = "=== 调试信息 ===\n"
	text += "FPS: %d\n" % fps
	text += "波次: %d/%d\n" % [wave, total_waves]
	text += "敌人数: %d\n" % enemy_count
	text += "金币: %d\n" % coins
	text += "玩家: %d/%d HP\n" % [hp, max_hp]
	text += "塔数量: %d" % tower_count

	label.text = text

func set_visible(is_visible: bool):
	visible = is_visible
```

**Step 3: 将脚本附加到场景**

1. 打开 `scenes/debug/debug_info.tscn`
2. 选择根节点（CanvasLayer）
3. 附加脚本：`scripts/debug_info.gd`
4. 保存场景

**Step 4: 在调试管理器中集成**

修改 `scripts/debug_manager.gd`：

```gdscript
var debug_info_scene = preload("res://scenes/debug/debug_info.tscn")
var debug_info_instance = null

func _ready():
	if not GameConfig.DEBUG_MODE:
		return

	# 实例化调试信息显示
	debug_info_instance = debug_info_scene.instantiate()
	get_tree().root.add_child(debug_info_instance)

	# ... 其他代码

func toggle_debug_info():
	if debug_info_instance:
		debug_info_visible = not debug_info_visible
		debug_info_instance.set_visible(debug_info_visible)
		print("[调试] F11: 调试信息显示 ", "开启" if debug_info_visible else "关闭")
```

**Step 5: 测试调试信息显示**

运行游戏，按 F11 键：

预期：屏幕左上角显示调试信息

**Step 6: 提交**

```bash
git add scenes/debug/debug_info.tscn scripts/debug_info.gd scripts/debug_manager.gd
git commit -m "feat: 实现调试信息显示（F11）"
```

---

## Task 10: 实现游戏控制快捷键

**Files:**
- Modify: `scripts/debug_manager.gd`

**Step 1: 实现无敌模式**

```gdscript
var god_mode_enabled = false

func toggle_god_mode():
	god_mode_enabled = not god_mode_enabled

	var player = get_tree().get_first_node_in_group("player")
	if player and "god_mode" in player:
		player.god_mode = god_mode_enabled

	print("[调试] F1: 无敌模式 ", "开启" if god_mode_enabled else "关闭")
```

**Step 2: 在玩家脚本中支持无敌模式**

修改 `scripts/player.gd`，添加无敌模式支持：

```gdscript
var god_mode = false  # 调试用无敌模式

# 在受伤逻辑中添加检查
func take_damage(amount):
	if god_mode:
		return
	# ... 原有受伤逻辑
```

**Step 3: 实现跳波功能**

```gdscript
func next_wave():
	var wave_manager = get_tree().get_first_node_in_group("wave_manager")
	if wave_manager and wave_manager.has_method("skip_to_next_wave"):
		wave_manager.skip_to_next_wave()
		print("[调试] F3: 跳到下一波")
	else:
		print("[调试] F3: 未找到波次管理器")
```

**Step 4: 在波次管理器中添加跳波方法**

修改 `scripts/wave_manager.gd`：

```gdscript
func skip_to_next_wave():
	# 结束当前波次
	wave_timer = 0
	# 清除所有敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		enemy.queue_free()
	# 触发波次结束
	_on_wave_complete()
```

**Step 5: 实现清除敌人功能**

```gdscript
func clear_enemies():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var count = enemies.size()
	for enemy in enemies:
		enemy.queue_free()
	print("[调试] F4: 清除了 ", count, " 个敌人")
```

**Step 6: 实现生成测试敌人功能**

```gdscript
func spawn_test_enemies():
	var enemy_spawner = get_tree().get_first_node_in_group("enemy_spawner")
	if enemy_spawner and enemy_spawner.has_method("spawn_test_enemies"):
		enemy_spawner.spawn_test_enemies(10)
		print("[调试] F5: 生成 10 个测试敌人")
	else:
		print("[调试] F5: 未找到敌人生成器")
```

**Step 7: 在敌人生成器中添加测试生成方法**

修改 `scripts/enemy_spawner.gd`：

```gdscript
func spawn_test_enemies(count: int):
	for i in range(count):
		spawn_enemy()
```

**Step 8: 测试所有快捷键**

运行游戏，测试：
- F1: 无敌模式（受到伤害不扣血）
- F2: 添加金币
- F3: 跳到下一波
- F4: 清除所有敌人
- F5: 生成 10 个敌人

预期：所有功能正常工作

**Step 9: 提交**

```bash
git add scripts/debug_manager.gd scripts/player.gd scripts/wave_manager.gd scripts/enemy_spawner.gd
git commit -m "feat: 实现游戏控制快捷键（F1-F5）"
```

---

## Task 11: 实现配置热重载

**Files:**
- Modify: `scripts/debug_manager.gd`
- Modify: `game_config.gd`

**Step 1: 在 GameConfig 中添加重载方法**

修改 `game_config.gd`，添加：

```gdscript
# 配置热重载（仅开发模式）
func reload():
	if not DEBUG_MODE:
		return false

	print("=== 重新加载配置 ===")

	# 通知所有使用配置的对象更新
	get_tree().call_group("config_reloadable", "on_config_reloaded")

	print("=== 配置重载完成 ===")
	return true
```

**Step 2: 实现热重载功能**

修改 `scripts/debug_manager.gd`：

```gdscript
func reload_config():
	if GameConfig.reload():
		print("[调试] F9: 配置已重新加载")

		# 显示提示信息
		show_notification("配置已重新加载")
	else:
		print("[调试] F9: 配置重载失败")

func show_notification(message: String):
	print("[通知] ", message)
	# TODO: 可以添加屏幕提示
```

**Step 3: 让玩家响应配置重载**

修改 `scripts/player.gd`，添加到 `player` 组并实现重载方法：

```gdscript
func _ready():
	add_to_group("config_reloadable")
	# ... 其他初始化代码

func on_config_reloaded():
	# 重新读取武器配置
	var weapon_data = GameConfig.WEAPONS[GameData.selected_weapon]
	fire_rate = weapon_data["fire_rate"]
	damage = weapon_data["damage"]
	# ... 其他需要更新的属性
	print("[玩家] 配置已更新")
```

**Step 4: 让敌人响应配置重载**

修改 `scripts/enemy.gd`：

```gdscript
func _ready():
	add_to_group("config_reloadable")
	# ... 其他初始化代码

func on_config_reloaded():
	# 重新读取敌人配置
	var enemy_data = GameConfig.ENEMIES[enemy_type]
	# 注意：不要重置当前血量，只更新最大血量
	max_hp = enemy_data["hp"]
	speed = enemy_data["speed"]
	damage = enemy_data["damage"]
	print("[敌人] 配置已更新: ", enemy_type)
```

**Step 5: 测试配置热重载**

1. 运行游戏
2. 修改 `game_config.gd` 中的某个数值（如步枪伤害）
3. 保存文件
4. 按 F9 键

预期：控制台输出配置重载信息

**注意**：Godot 的脚本热重载机制有限，某些情况下可能需要重启游戏才能完全生效。

**Step 6: 提交**

```bash
git add scripts/debug_manager.gd game_config.gd scripts/player.gd scripts/enemy.gd
git commit -m "feat: 实现配置热重载功能（F9）"
```

---

## Task 12: 创建调试面板UI（可选）

**说明**：这是一个可选任务。如果快捷键已经足够使用，可以跳过此任务。

**Files:**
- Create: `scenes/debug/debug_panel.tscn`
- Create: `scripts/debug_panel.gd`

**Step 1: 创建调试面板场景**

在 Godot 编辑器中：
1. 创建新场景
2. 根节点：CanvasLayer
3. 添加子节点：Panel
   - Size: (400, 600)
   - Position: 居中
4. 在 Panel 下添加：
   - VBoxContainer
   - 多个 Button（跳波、清敌人、加金币等）
   - 多个 HSlider（调整数值）
5. 保存为 `scenes/debug/debug_panel.tscn`

**Step 2: 创建调试面板脚本**

创建 `scripts/debug_panel.gd`：

```gdscript
extends CanvasLayer

func _ready():
	visible = false

func toggle():
	visible = not visible

func _on_add_coins_pressed():
	DebugManager.add_coins(1000)

func _on_next_wave_pressed():
	DebugManager.next_wave()

func _on_clear_enemies_pressed():
	DebugManager.clear_enemies()

func _on_close_pressed():
	visible = false
```

**Step 3: 在调试管理器中集成**

修改 `scripts/debug_manager.gd`：

```gdscript
var debug_panel_scene = preload("res://scenes/debug/debug_panel.tscn")
var debug_panel_instance = null

func _ready():
	# ... 其他代码

	# 实例化调试面板
	debug_panel_instance = debug_panel_scene.instantiate()
	get_tree().root.add_child(debug_panel_instance)

func toggle_debug_panel():
	if debug_panel_instance:
		debug_panel_instance.toggle()
		print("[调试] F12: 调试面板 ", "开启" if debug_panel_instance.visible else "关闭")
```

**Step 4: 测试调试面板**

运行游戏，按 F12 键：

预期：显示调试面板UI

**Step 5: 提交**

```bash
git add scenes/debug/debug_panel.tscn scripts/debug_panel.gd scripts/debug_manager.gd
git commit -m "feat: 实现调试面板UI（F12）"
```

---

## 阶段 3 验收

- [ ] 调试管理器创建并注册为自动加载
- [ ] F11 可以开关调试信息显示
- [ ] F1-F5 快捷键功能正常
- [ ] F9 配置热重载功能实现
- [ ] （可选）F12 调试面板UI实现
- [ ] 所有调试功能仅在 DEBUG_MODE 下启用
- [ ] 提交 4-5 次

**下一步:** 执行阶段 4 - 难度平衡调整
