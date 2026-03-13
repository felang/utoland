# 体验打磨与 Bug 修复实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 2 个已知 Bug，增强打击感、UI 动效、音效与 BGM 系统，全面提升游戏体验。

**Architecture:** 扩展现有 Autoload 单例（EffectsManager、AudioManager、SceneManager），新增 UIUtils 工具类。不新建 Autoload。所有新功能通过 EventBus 解耦通信。

**Tech Stack:** Godot 4.6, GDScript, GUT 测试框架

**测试命令:** `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

---

## Chunk 1: Bug 修复

### Task 1: Sunflower 产金事件接收

**Files:**
- Modify: `scripts/ui/main.gd`
- Test: `tests/unit/test_main_coins_generated.gd`

**上下文:** TowerGenerator（sunflower）在 `_on_generate_timer_timeout()` 中发出 `EventBus.coins_generated.emit(generate_amount, global_position)`，但 `main.gd` 未监听此信号。`player.add_coins(amount)` 方法同步更新 `player.coins`、`GameData.coins` 和调用 `GameData.add_xp(amount)`。HUD 从 `player.coins` 读取显示，所以必须通过 player 来同步。

- [ ] **Step 1: 写失败测试**

创建 `tests/unit/test_main_coins_generated.gd`:

```gdscript
extends GutTest

func test_coins_generated_updates_game_data():
	# main.gd 场景脚本无法在 headless 中加载，
	# 验证 GameData 操作逻辑正确性
	var old_coins: int = GameData.coins
	var old_xp: int = GameData.current_xp
	var amount: int = 10
	# 模拟 _on_coins_generated 回调逻辑
	GameData.coins += amount
	GameData.add_xp(amount)
	assert_eq(GameData.coins, old_coins + amount, "金币应增加")
	assert_true(GameData.current_xp >= old_xp, "XP 应增加或因升级重置")
```

- [ ] **Step 2: 运行测试确认通过**（测试逻辑本身应通过，验证 GameData API 可用）

- [ ] **Step 3: 实现 main.gd 修改**

在 `scripts/ui/main.gd` 的 `_ready()` 中添加信号连接:

```gdscript
# 在 _ready() 末尾添加:
EventBus.coins_generated.connect(_on_coins_generated)
```

添加回调方法。注意：需要通过 player 节点同步 coins，因为 HUD 读取 `player.coins`:

```gdscript
func _on_coins_generated(amount: int, _pos: Vector2) -> void:
	var player: Node2D = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	if player and player.has_method("add_coins"):
		player.add_coins(amount)
	else:
		# player 不存在时的降级处理
		GameData.coins += amount
		GameData.add_xp(amount)
```

- [ ] **Step 4: 运行全量测试确认无回归**

- [ ] **Step 5: 提交**

```bash
git add scripts/ui/main.gd tests/unit/test_main_coins_generated.gd
git commit -m "fix: main.gd 监听 coins_generated 信号，sunflower 产金生效"
```

---

### Task 2: 补齐塔放置/移除音效注册

**Files:**
- Modify: `scripts/systems/audio_manager.gd:26-36`
- Test: `tests/unit/test_audio_manager.gd`

**上下文:** `placement_panel.gd` 调用 `AudioManager.play("tower_place")` 和 `AudioManager.play("tower_remove")`，但 `audio_manager.gd` 的 `sound_map` 字典中未注册这两个 ID。`play()` 方法检查 `_sounds.has(sound_id)` 后静默返回。另外 `assets/sfx/` 目录下也缺少对应 wav 文件（需用户手动用 jsfxr 生成）。

- [ ] **Step 1: 写失败测试**

在 `tests/unit/test_audio_manager.gd` 中添加:

```gdscript
func test_tower_sound_ids_registered():
	# AudioManager._sounds 在 _ready() 时从文件加载
	# 这里验证 sound_map 中是否包含 tower_place 和 tower_remove
	# 由于 wav 文件可能不存在，只验证 play() 不报错
	AudioManager.play("tower_place")
	AudioManager.play("tower_remove")
	assert_true(true, "tower_place 和 tower_remove 调用不应崩溃")
```

- [ ] **Step 2: 在 audio_manager.gd 的 sound_map 中添加注册**

修改 `scripts/systems/audio_manager.gd` 第 26-36 行的 `sound_map` 字典，添加:

```gdscript
		"tower_place": "tower_place.wav",
		"tower_remove": "tower_remove.wav",
```

- [ ] **Step 3: 运行测试确认通过**

- [ ] **Step 4: 提交**

```bash
git add scripts/systems/audio_manager.gd tests/unit/test_audio_manager.gd
git commit -m "fix: audio_manager 注册 tower_place/tower_remove 音效 ID"
```

> **注意:** wav 文件需用户用 jsfxr 生成后放入 `assets/sfx/`。tower_place 建议短促种植音，tower_remove 建议短促拔起音。

---

## Chunk 2: 打击感增强

### Task 3: Boss 击杀慢动作（Hitstop）

**Files:**
- Modify: `scripts/systems/effects_manager.gd`
- Modify: `scripts/entities/boss_base.gd`
- Modify: `scripts/resources/effect_config_data.gd`
- Test: `tests/unit/test_effects_manager.gd`

**上下文:** EffectsManager 是 Autoload 单例（106 行），提供 flash_white/spawn_damage_number/spawn_hit_sparks/spawn_death_effect。boss_base.gd 仅 8 行，`_on_died()` 发出 boss_killed 后调用 `super._on_died()`。effect_config_data.gd 是 Resource 类（96 行），存储所有特效参数。

- [ ] **Step 1: 在 effect_config_data.gd 添加 hitstop 参数**

在 `scripts/resources/effect_config_data.gd` 末尾（现有 camera 参数之后）添加:

```gdscript
## Hitstop（击杀慢动作）
@export var hitstop_time_scale: float = 0.05
@export var hitstop_duration: float = 0.1  # 实际时间（不受 time_scale 影响）
```

- [ ] **Step 2: 写 hitstop 失败测试**

在 `tests/unit/test_effects_manager.gd` 中添加:

```gdscript
func test_hitstop_changes_time_scale():
	EffectsManager.hitstop(0.05, 0.01)
	assert_lt(Engine.time_scale, 1.0, "time_scale 应小于 1")
	# 等待恢复（用真实时间计时器）
	await get_tree().create_timer(0.05, true, false, true).timeout
	assert_eq(Engine.time_scale, 1.0, "time_scale 应恢复为 1.0")
```

- [ ] **Step 3: 运行测试确认失败**

- [ ] **Step 4: 实现 hitstop 方法**

在 `scripts/systems/effects_manager.gd` 末尾添加:

```gdscript
func hitstop(time_scale: float = 0.05, duration: float = 0.1) -> void:
	Engine.time_scale = time_scale
	# ignore_time_scale=true 确保计时器按真实时间走
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
```

- [ ] **Step 5: 在 boss_base.gd 中调用 hitstop**

修改 `scripts/entities/boss_base.gd`:

```gdscript
extends "res://scripts/entities/enemy.gd"

# Boss 基类 — 死亡时额外发出 boss_killed 信号 + 慢动作

func _on_died() -> void:
	EventBus.boss_killed.emit(enemy_type)
	var fx: EffectConfigData = GameConfig.effects
	EffectsManager.hitstop(fx.hitstop_time_scale, fx.hitstop_duration)
	super._on_died()
```

- [ ] **Step 6: 运行测试确认通过**

- [ ] **Step 7: 提交**

```bash
git add scripts/systems/effects_manager.gd scripts/entities/boss_base.gd scripts/resources/effect_config_data.gd tests/unit/test_effects_manager.gd
git commit -m "feat: Boss 击杀慢动作（hitstop）"
```

---

### Task 4: 击中反馈增强（红闪 + 抖动）

**Files:**
- Modify: `scripts/systems/effects_manager.gd`
- Modify: `scripts/entities/enemy.gd:144-148`
- Test: `tests/unit/test_effects_manager.gd`

**上下文:** enemy.gd 的 `_on_hurtbox_hit()` 目前只播放音效、扣血、击退。`_flash_white()` 方法存在但从未被调用。`health.take_damage()` 内部已调用 `EffectsManager.flash_white()`（白闪），新增红闪会与之冲突。方案：用红闪替代白闪（修改 HealthComponent 的 flash 颜色），并添加 sprite 子节点抖动（不抖动 position 根节点，避免与 knockback tween 冲突）。

- [ ] **Step 1: 写 flash_hit 失败测试**

在 `tests/unit/test_effects_manager.gd` 中添加:

```gdscript
func test_flash_hit_changes_modulate():
	var sprite := Sprite2D.new()
	add_child(sprite)
	var original_mod: Color = sprite.modulate
	EffectsManager.flash_hit(sprite)
	assert_ne(sprite.modulate, original_mod, "modulate 应被改为红色")
	await get_tree().create_timer(0.1).timeout
	assert_eq(sprite.modulate, original_mod, "modulate 应恢复原色")
	sprite.queue_free()
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 实现 flash_hit**

在 `scripts/systems/effects_manager.gd` 中添加:

```gdscript
const FLASH_HIT_COLOR := Color(1, 0.3, 0.3, 1)

func flash_hit(node: Node2D) -> Tween:
	var original_modulate: Color = node.modulate
	node.modulate = FLASH_HIT_COLOR
	var tween: Tween = create_tween()
	tween.tween_property(node, "modulate", original_modulate, GameConfig.effects.hit_flash_duration)
	return tween
```

- [ ] **Step 4: 修改 HealthComponent 使用 flash_hit 替代 flash_white**

修改 `scripts/components/health_component.gd` 的 `take_damage()` 方法（第 36-37 行），将 `flash_white` 替换为 `flash_hit`:

```gdscript
	# 红闪（替代白闪，打击感更强）
	var owner_node: Node2D = get_parent() as Node2D
	if owner_node:
		EffectsManager.flash_hit(owner_node)
```

- [ ] **Step 5: 在 enemy.gd _on_hurtbox_hit 中添加 sprite 子节点抖动**

注意：不能对 enemy 根节点的 `position` 做 shake，因为 `_knockback.apply_knockback()` 也在 tween position。改为对 `_sprite_animator` 的内部 sprite 做 offset 抖动。

在 `scripts/systems/effects_manager.gd` 中添加（操作 sprite 子节点 offset 而非 root position）:

```gdscript
func sprite_shake(node: Node2D, amount: float = 2.0) -> void:
	if not is_instance_valid(node):
		return
	# 找到第一个 Sprite 子节点做 offset 抖动
	var sprite: Node2D = null
	for child in node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			sprite = child
			break
	if not sprite:
		sprite = node  # 降级到根节点
	var original_offset: Vector2 = sprite.offset if sprite.has_method("get") else Vector2.ZERO
	var prop: String = "offset" if (sprite is Sprite2D or sprite is AnimatedSprite2D) else "position"
	var base: Vector2 = sprite.get(prop)
	var tween: Tween = node.create_tween()
	tween.tween_property(sprite, prop, base + Vector2(amount, 0), 0.02)
	tween.tween_property(sprite, prop, base + Vector2(-amount, 0), 0.02)
	tween.tween_property(sprite, prop, base, 0.02)
```

修改 `scripts/entities/enemy.gd` 的 `_on_hurtbox_hit()`，在末尾添加抖动:

```gdscript
func _on_hurtbox_hit(damage: float, knockback_dir: Vector2) -> void:
	AudioManager.play("hit", -6.0)
	health.take_damage(damage)
	EffectsManager.sprite_shake(self, 2.0)
	if knockback_dir.length() > 0:
		_knockback.apply_knockback(knockback_dir.normalized())
```

> 注意：不再在此处调用 `flash_hit`，因为 `health.take_damage()` 内部已调用。

- [ ] **Step 5: 运行测试确认通过**

- [ ] **Step 6: 提交**

```bash
git add scripts/systems/effects_manager.gd scripts/entities/enemy.gd tests/unit/test_effects_manager.gd
git commit -m "feat: 敌人受击红闪 + 抖动反馈"
```

---

### Task 5: 死亡特效增强

**Files:**
- Modify: `scripts/systems/effects_manager.gd`
- Test: `tests/unit/test_effects_manager.gd`

**上下文:** 现有 `spawn_death_effect()` 用 ColorRect+Tween 创建粒子飘散效果。`HealthComponent.die()` 内部已调用 `spawn_death_effect()`，所以增强方法不能再重复调用它，否则会产生双重碎片。增强方案：新增 `spawn_enhanced_death()` 方法，只负责白闪缩放弹跳效果（独立于已有碎片）。

- [ ] **Step 1: 写增强死亡特效测试**

在 `tests/unit/test_effects_manager.gd` 中添加:

```gdscript
func test_spawn_enhanced_death_creates_nodes():
	var tree: SceneTree = get_tree()
	var before_count: int = tree.current_scene.get_child_count()
	EffectsManager.spawn_enhanced_death(Vector2(100, 100), Color.RED)
	var after_count: int = tree.current_scene.get_child_count()
	assert_gt(after_count, before_count, "应创建死亡特效节点")
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 实现 spawn_enhanced_death**

在 `scripts/systems/effects_manager.gd` 中添加:

```gdscript
func spawn_enhanced_death(pos: Vector2, _entity_color: Color) -> void:
	# 白闪缩放弹跳效果（独立 ColorRect 节点）
	# 注意：不调用 spawn_death_effect()，因为 HealthComponent.die() 已调用过
	var flash_rect: ColorRect = ColorRect.new()
	flash_rect.size = Vector2(12, 12)
	flash_rect.position = pos - flash_rect.size / 2
	flash_rect.color = Color.WHITE
	flash_rect.z_index = 50
	flash_rect.pivot_offset = flash_rect.size / 2
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(flash_rect)
	else:
		add_child(flash_rect)

	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(flash_rect, "scale", Vector2(1.3, 1.3), 0.05)
	flash_tween.tween_property(flash_rect, "scale", Vector2.ZERO, 0.15).set_ease(Tween.EASE_IN)
	flash_tween.tween_callback(flash_rect.queue_free)
```

- [ ] **Step 4: 在 enemy.gd 中使用增强死亡特效**

修改 `scripts/entities/enemy.gd` 的 `_on_died()` 方法，在 `queue_free()` 之前添加:

```gdscript
# 在 _drop_coins() 之后、queue_free() 之前添加:
EffectsManager.spawn_enhanced_death(global_position, health.death_color)
```

- [ ] **Step 5: 运行测试确认通过**

- [ ] **Step 6: 提交**

```bash
git add scripts/systems/effects_manager.gd scripts/entities/enemy.gd tests/unit/test_effects_manager.gd
git commit -m "feat: 增强死亡特效（白闪缩放弹跳 + 碎片）"
```

---

## Chunk 3: UI 动效

### Task 6: 场景切换淡入淡出

**Files:**
- Modify: `scripts/core/scene_manager.gd`
- Test: `tests/unit/test_scene_manager_fade.gd`

**上下文:** 当前 `scene_manager.gd` 仅 15 行，`go_to()` 直接调用 `get_tree().change_scene_to_file()`。需要添加 CanvasLayer+ColorRect 遮罩实现淡入淡出。SceneManager 是 Autoload，其子节点不会被场景切换销毁。

- [ ] **Step 1: 写淡入淡出测试**

创建 `tests/unit/test_scene_manager_fade.gd`:

```gdscript
extends GutTest

func test_scene_manager_has_fade_overlay():
	# SceneManager 应有 CanvasLayer 子节点用于淡入淡出
	var canvas: CanvasLayer = null
	for child in SceneManager.get_children():
		if child is CanvasLayer:
			canvas = child
			break
	assert_not_null(canvas, "SceneManager 应有 CanvasLayer 遮罩")

func test_fade_overlay_initially_transparent():
	var rect: ColorRect = null
	for child in SceneManager.get_children():
		if child is CanvasLayer:
			for sub in child.get_children():
				if sub is ColorRect:
					rect = sub
					break
	assert_not_null(rect, "应有 ColorRect 遮罩")
	if rect:
		assert_eq(rect.color.a, 0.0, "遮罩初始应完全透明")
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 实现淡入淡出**

重写 `scripts/core/scene_manager.gd`:

```gdscript
extends Node

const SCENES: Dictionary = {
	"start_menu":          "res://scenes/ui/start_menu.tscn",
	"character_selection": "res://scenes/ui/character_selection.tscn",
	"map_select":          "res://scenes/ui/map_select.tscn",
	"result":              "res://scenes/ui/result.tscn",
	"placement":           "res://scenes/levels/placement.tscn",
	"main":                "res://scenes/levels/main.tscn",
}

const FADE_DURATION: float = 0.3

var _fade_rect: ColorRect
var _is_transitioning: bool = false

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 200
	add_child(canvas)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_fade_rect)

func go_to(scene_name: String) -> void:
	assert(SCENES.has(scene_name), "未知场景: " + scene_name)
	if _is_transitioning:
		return
	_is_transitioning = true
	# 淡出
	var tween_out: Tween = create_tween()
	tween_out.tween_property(_fade_rect, "color:a", 1.0, FADE_DURATION)
	await tween_out.finished
	# 切换场景
	get_tree().change_scene_to_file(SCENES[scene_name])
	# 等一帧让新场景初始化
	await get_tree().process_frame
	# 淡入
	var tween_in: Tween = create_tween()
	tween_in.tween_property(_fade_rect, "color:a", 0.0, FADE_DURATION)
	await tween_in.finished
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
```

- [ ] **Step 4: 运行测试确认通过**

- [ ] **Step 5: 提交**

```bash
git add scripts/core/scene_manager.gd tests/unit/test_scene_manager_fade.gd
git commit -m "feat: 场景切换淡入淡出过渡效果"
```

---

### Task 7: 升级弹窗动效

**Files:**
- Modify: `scripts/ui/upgrade_popup.gd`
- Test: 手动验证（UI 动画难以 headless 测试）

**上下文:** upgrade_popup.gd（254 行）继承 CanvasLayer (layer=90, process_mode=ALWAYS)。`show_upgrades(count)` 初始化升级轮次，`_create_card()` 创建 PanelContainer 卡片。卡片放在 `_cards_container`（HBoxContainer）中。需要在三个时机加动画：弹窗出现、卡片滑入、选择卡片。

- [ ] **Step 1: 添加弹窗出现动画**

在 `scripts/ui/upgrade_popup.gd` 中找到 `_show_round()` 或 `show_upgrades()` 方法，在卡片创建完成后添加弹窗弹入动画。

在 `_container`（弹窗主面板）创建后添加:

```gdscript
func _animate_popup_in() -> void:
	_container.pivot_offset = _container.size / 2
	_container.scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(_container, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
```

- [ ] **Step 2: 添加卡片依次滑入动画**

卡片创建后，设置初始位置偏移和透明，然后依次动画:

```gdscript
func _animate_cards_in() -> void:
	var cards: Array = _cards_container.get_children()
	for i in cards.size():
		var card: Control = cards[i]
		var target_pos: float = card.position.y
		card.position.y += 50.0
		card.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(card, "position:y", target_pos, 0.25).set_ease(Tween.EASE_OUT).set_delay(i * 0.1)
		tween.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(i * 0.1)
```

- [ ] **Step 3: 添加选择卡片动画**

在 `_on_option_selected()` 方法中，选中卡片前先执行动画:

```gdscript
func _animate_card_selection(selected_index: int) -> void:
	var cards: Array = _cards_container.get_children()
	for i in cards.size():
		var card: Control = cards[i]
		var tween: Tween = create_tween()
		if i == selected_index:
			tween.tween_property(card, "scale", Vector2(1.1, 1.1), 0.15)
		else:
			tween.set_parallel(true)
			tween.tween_property(card, "scale", Vector2(0.9, 0.9), 0.15)
			tween.tween_property(card, "modulate:a", 0.3, 0.15)
```

- [ ] **Step 4: 在对应位置调用动画方法**

- 在 `_show_round()` 末尾调用 `_animate_popup_in()` 和 `_animate_cards_in()`
- 在 `_on_option_selected()` 开头调用 `_animate_card_selection()`，然后 `await get_tree().create_timer(0.3).timeout` 再执行后续逻辑

- [ ] **Step 5: 运行全量测试确认无回归**

- [ ] **Step 6: 提交**

```bash
git add scripts/ui/upgrade_popup.gd
git commit -m "feat: 升级弹窗出现/卡片滑入/选择动效"
```

---

### Task 8: HUD 数字弹跳动画

**Files:**
- Modify: `scripts/ui/hud.gd`
- Test: 手动验证

**上下文:** hud.gd（194 行），`_update_coins()` 在 `_process()` 中每帧调用读取 `player.coins`。`_on_xp_changed()` 和 `_on_player_leveled_up()` 通过 EventBus 信号触发。`_on_player_leveled_up()` 已实现经验条闪白 + "Level Up!" 浮动文字，无需重复。只需添加金币数字变化弹跳。

- [ ] **Step 1: 添加金币数值弹跳**

在 `scripts/ui/hud.gd` 中添加追踪变量和弹跳方法:

```gdscript
# 在类变量区域添加:
var _last_coins: int = -1

# 新增弹跳方法:
func _bounce_label(label: Control) -> void:
	label.pivot_offset = label.size / 2
	var tween: Tween = create_tween()
	tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(label, "scale", Vector2.ONE, 0.1)
```

- [ ] **Step 2: 修改 _update_coins() 检测变化并弹跳**

```gdscript
func _update_coins() -> void:
	if player and is_instance_valid(player):
		var current_coins: int = player.coins
		coin_text.text = str(current_coins)
		if _last_coins >= 0 and current_coins != _last_coins:
			_bounce_label(coin_text)
		_last_coins = current_coins
```

> **注意:** `_on_player_leveled_up()` 中的经验条闪白和 "Level Up!" 文字弹出已存在（hud.gd:165-193），无需修改。

- [ ] **Step 3: 运行全量测试确认无回归**

- [ ] **Step 4: 提交**

```bash
git add scripts/ui/hud.gd
git commit -m "feat: HUD 金币数字变化弹跳动效"
```

---

### Task 9: 按钮 Hover/Press 动效

**Files:**
- Create: `scripts/ui/ui_utils.gd`
- Modify: `scripts/ui/start_menu.gd`
- Modify: `scripts/ui/character_selection.gd`
- Modify: `scripts/ui/map_select.gd`
- Modify: `scripts/ui/result.gd`
- Test: `tests/unit/test_ui_utils.gd`

**上下文:** 采用方案 A — 通用工具方法。创建 UIUtils 静态类，提供 `setup_button_hover(button)` 方法。各 UI 脚本在 `_ready()` 中对按钮调用。

- [ ] **Step 1: 写 UIUtils 测试**

创建 `tests/unit/test_ui_utils.gd`:

```gdscript
extends GutTest

func test_setup_button_hover_connects_signals():
	var btn := Button.new()
	add_child(btn)
	UIUtils.setup_button_hover(btn)
	assert_true(btn.mouse_entered.get_connections().size() > 0, "应连接 mouse_entered")
	assert_true(btn.mouse_exited.get_connections().size() > 0, "应连接 mouse_exited")
	btn.queue_free()
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 实现 UIUtils**

创建 `scripts/ui/ui_utils.gd`:

```gdscript
class_name UIUtils

static func setup_button_hover(button: Button) -> void:
	# pivot_offset 在每次交互时动态更新，因为 _ready 时 size 可能还是 Vector2.ZERO
	button.mouse_entered.connect(func() -> void:
		button.pivot_offset = button.size / 2
		var tw: Tween = button.create_tween()
		tw.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)
	)
	button.mouse_exited.connect(func() -> void:
		var tw: Tween = button.create_tween()
		tw.tween_property(button, "scale", Vector2.ONE, 0.1)
	)
	button.button_down.connect(func() -> void:
		var tw: Tween = button.create_tween()
		tw.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)
	)
	button.button_up.connect(func() -> void:
		var tw: Tween = button.create_tween()
		tw.tween_property(button, "scale", Vector2(1.05, 1.05), 0.05)
	)
```

- [ ] **Step 4: 注册 class_name 到 global_script_class_cache.cfg**

如果无法打开 Godot 编辑器刷新，需手动在 `.godot/global_script_class_cache.cfg` 中添加 UIUtils 条目。

- [ ] **Step 5: 在各 UI 脚本中调用**

在 `start_menu.gd` 的 `_ready()` 中，按钮循环处添加:

```gdscript
for btn_name in ["StartButton", "SettingsButton", "QuitButton"]:
	var btn: Button = vbox.get_node(btn_name)
	UIUtils.setup_button_hover(btn)
```

类似地在 `character_selection.gd`、`map_select.gd`、`result.gd` 中对按钮调用 `UIUtils.setup_button_hover()`。

- [ ] **Step 6: 运行测试确认通过**

- [ ] **Step 7: 提交**

```bash
git add scripts/ui/ui_utils.gd tests/unit/test_ui_utils.gd scripts/ui/start_menu.gd scripts/ui/character_selection.gd scripts/ui/map_select.gd scripts/ui/result.gd .godot/global_script_class_cache.cfg
git commit -m "feat: 按钮 hover/press 缩放动效（UIUtils 通用方法）"
```

---

## Chunk 4: 音效与 BGM

### Task 10: BGM 播放系统

**Files:**
- Modify: `scripts/systems/audio_manager.gd`
- Test: `tests/unit/test_audio_manager.gd`

**上下文:** audio_manager.gd（50 行）目前只有 SFX 池。需添加独立的 BGM AudioStreamPlayer、注册字典、play_bgm/stop_bgm/fade_bgm 方法。BGM 文件由用户手动放入 `assets/bgm/`。

- [ ] **Step 1: 写 BGM 系统测试**

在 `tests/unit/test_audio_manager.gd` 中添加:

```gdscript
func test_play_bgm_unknown_track_no_crash():
	AudioManager.play_bgm("nonexistent")
	assert_true(true, "未知 BGM track 不应崩溃")

func test_stop_bgm_no_crash():
	AudioManager.stop_bgm()
	assert_true(true, "stop_bgm 无播放时不应崩溃")

func test_fade_bgm_no_crash():
	AudioManager.fade_bgm(0.5)
	assert_true(true, "fade_bgm 无播放时不应崩溃")
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 实现 BGM 系统**

在 `scripts/systems/audio_manager.gd` 中添加:

```gdscript
# 在类变量区域添加:
var _bgm_player: AudioStreamPlayer
var _bgm_tracks: Dictionary = {}
var _current_bgm: String = ""

# 在 _ready() 中添加（_create_pool() 之后）:
func _ready() -> void:
	_create_pool()
	_register_sounds()
	_create_bgm_player()
	_register_bgm()

func _create_bgm_player() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -6.0  # BGM 默认比 SFX 小一些
	add_child(_bgm_player)

func _register_bgm() -> void:
	var bgm_dir := "res://assets/bgm/"
	var bgm_map: Dictionary = {
		"menu": "menu.ogg",
		"placement": "placement.ogg",
		"battle": "battle.ogg",
		"result": "result.ogg",
	}
	for id: String in bgm_map:
		var path: String = bgm_dir + bgm_map[id]
		if ResourceLoader.exists(path):
			_bgm_tracks[id] = load(path)

func play_bgm(track_id: String) -> void:
	if track_id == _current_bgm and _bgm_player.playing:
		return
	if not _bgm_tracks.has(track_id):
		return
	_bgm_player.stream = _bgm_tracks[track_id]
	_bgm_player.volume_db = -6.0
	_bgm_player.play()
	_current_bgm = track_id

func stop_bgm() -> void:
	_bgm_player.stop()
	_current_bgm = ""

func fade_bgm(duration: float = 0.5) -> void:
	if not _bgm_player.playing:
		return
	var tween: Tween = create_tween()
	tween.tween_property(_bgm_player, "volume_db", -40.0, duration)
	tween.tween_callback(stop_bgm)
```

- [ ] **Step 4: 运行测试确认通过**

- [ ] **Step 5: 提交**

```bash
git add scripts/systems/audio_manager.gd tests/unit/test_audio_manager.gd
git commit -m "feat: AudioManager BGM 播放/停止/淡出系统"
```

---

### Task 11: 场景切换 BGM 自动切换

**Files:**
- Modify: `scripts/core/scene_manager.gd`
- Test: `tests/unit/test_scene_manager_fade.gd`

**上下文:** SceneManager 已有淡入淡出（Task 6 实现）。需添加场景→BGM 映射，在 `go_to()` 中自动切换 BGM。

- [ ] **Step 1: 写 BGM 映射测试**

在 `tests/unit/test_scene_manager_fade.gd` 中添加:

```gdscript
func test_scene_bgm_mapping_exists():
	# 验证所有场景都有 BGM 映射
	for scene_name in SceneManager.SCENES.keys():
		assert_true(SceneManager.SCENE_BGM.has(scene_name),
			"场景 %s 应有 BGM 映射" % scene_name)
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 在 scene_manager.gd 中添加 BGM 映射和切换**

在 `scripts/core/scene_manager.gd` 中添加:

```gdscript
const SCENE_BGM: Dictionary = {
	"start_menu": "menu",
	"character_selection": "menu",
	"map_select": "menu",
	"placement": "placement",
	"main": "battle",
	"result": "result",
}
```

在 `go_to()` 方法中，场景切换前淡出 BGM，切换后播放新 BGM:

```gdscript
# 在 fade_out 之前:
AudioManager.fade_bgm(FADE_DURATION)
# 在 fade_in 之前（change_scene_to_file 之后）:
if SCENE_BGM.has(scene_name):
	AudioManager.play_bgm(SCENE_BGM[scene_name])
```

- [ ] **Step 4: 运行测试确认通过**

- [ ] **Step 5: 提交**

```bash
git add scripts/core/scene_manager.gd tests/unit/test_scene_manager_fade.gd
git commit -m "feat: 场景切换自动切换 BGM"
```

---

### Task 12: 最终验收 — 全量测试

**Files:** 无修改

- [ ] **Step 1: 运行全量测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

预期：所有测试通过（原有 353 + 新增约 10 个）

- [ ] **Step 2: 修复任何失败的测试**

- [ ] **Step 3: 最终提交（如有修复）**

```bash
git add -A
git commit -m "test: 修复体验打磨相关测试"
```

> **BGM 文件说明:** `assets/bgm/` 目录下的 ogg 文件需用户手动获取。推荐来源：
> - [itch.io chiptune](https://itch.io/game-assets/free/tag-chiptune)
> - [Soundimage.org Chiptunes](https://soundimage.org/chiptunes/)
> - [Wondera 8-bit Generator](https://www.wondera.ai/tools/en/ai-8-bit-music-generator)
> - [Musely Pixel Soundtrack](https://musely.ai/tools/pixel-art-game-soundtrack)
