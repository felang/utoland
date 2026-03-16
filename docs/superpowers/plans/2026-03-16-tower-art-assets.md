# 塔美术资源集成 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 3 座塔（pea_shooter, ice_flower, sunflower）从 tileset 裁切 / ColorRect 占位切换为独立精灵 + AnimatedSprite2D 动画系统，并为 pea_shooter 弹道添加豌豆精灵。

**Architecture:** 每个塔场景中的 Visual 节点从 Sprite2D（tileset region）替换为 AnimatedSprite2D + SpriteFrames 资源。塔基类 `tower.gd` 新增动画控制逻辑（idle/attack 切换），使用 `get_node_or_null` 保证安全引用。TowerData 新增 `projectile_sprite_path` 字段，tower_shooter 在射击时给子弹附加精灵（含方向旋转）。等级装饰通过 Sprite2D 子节点叠加。

**Tech Stack:** Godot 4.6, GDScript, AnimatedSprite2D, SpriteFrames

**Spec:** `docs/superpowers/specs/2026-03-16-tower-art-assets-design.md`

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| Modify | `scripts/entities/towers/tower.gd` | 新增 AnimatedSprite2D 安全引用 + idle/attack 动画切换 + 等级装饰叠加 |
| Modify | `scripts/entities/towers/tower_shooter.gd` | 攻击时播放 attack 动画 + 给弹道附加精灵（含旋转） |
| Modify | `scripts/entities/towers/tower_slow.gd` | 当敌人进入减速区时播放 attack 动画（防重复触发） |
| Modify | `scripts/entities/towers/tower_generator.gd` | 产金时播放 attack 动画 |
| Modify | `scripts/resources/tower_data.gd` | 新增 `projectile_sprite_path: String` |
| Modify | `resources/towers/pea_shooter.tres` | 填入 `icon_path` + `projectile_sprite_path` |
| Modify | `resources/towers/ice_flower.tres` | 填入 `icon_path` |
| Modify | `resources/towers/sunflower.tres` | 填入 `icon_path` |
| Modify | `scenes/entities/towers/tower_pea_shooter.tscn` | Sprite2D → AnimatedSprite2D |
| Modify | `scenes/entities/towers/tower_ice_flower.tscn` | Sprite2D → AnimatedSprite2D |
| Modify | `scenes/entities/towers/tower_sunflower.tscn` | ColorRect → AnimatedSprite2D |
| Create | `assets/towers/pea_shooter/sprite.png` | 占位精灵（24x24） |
| Create | `assets/towers/ice_flower/sprite.png` | 占位精灵（16x16） |
| Create | `assets/towers/sunflower/sprite.png` | 占位精灵（16x16） |
| Create | `assets/towers/shared/lv2_glow.png` | 等级 2 光圈（占位） |
| Create | `assets/towers/shared/lv3_glow.png` | 等级 3 光圈（占位） |
| Create | `assets/projectiles/pea.png` | 豌豆弹道精灵（占位 8x8） |
| Modify | `tests/unit/test_tower_data.gd` | 新增 icon_path 非空测试 |

---

## Chunk 1: TowerData 扩展 + 占位资源 + .tres 更新

### Task 1: TowerData 扩展 + 占位精灵 + .tres 填值

**Files:**
- Modify: `scripts/resources/tower_data.gd:8`
- Create: 占位精灵（6 张）
- Modify: `resources/towers/*.tres`（3 个）
- Test: `tests/unit/test_tower_data.gd`

- [ ] **Step 1: 写失败测试 — icon_path 非空**

在 `tests/unit/test_tower_data.gd` 末尾添加：

```gdscript
func test_all_towers_have_icon_path() -> void:
	for tower_id in GameConfig.towers:
		var td: TowerData = GameConfig.towers[tower_id]
		assert_ne(td.icon_path, "", "%s 缺少 icon_path" % tower_id)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_tower_data.gd`
Expected: FAIL — 3 个塔的 icon_path 都为空字符串

- [ ] **Step 3: TowerData 新增 projectile_sprite_path**

在 `scripts/resources/tower_data.gd` 第 8 行 `icon_path` 下方添加：

```gdscript
@export var projectile_sprite_path: String = ""
```

- [ ] **Step 4: 创建占位精灵文件**

用脚本生成最小 PNG 占位图（纯色方块，后续替换为美术素材）：
- `assets/towers/pea_shooter/sprite.png` — 24x24 绿色
- `assets/towers/ice_flower/sprite.png` — 16x16 蓝色
- `assets/towers/sunflower/sprite.png` — 16x16 黄色
- `assets/projectiles/pea.png` — 8x8 绿色
- `assets/towers/shared/lv2_glow.png` — 32x32 半透明白色光圈
- `assets/towers/shared/lv3_glow.png` — 32x32 半透明金色光圈

删除已放入实际资源的塔目录下的 `.gitkeep` 文件（pea_shooter、ice_flower、sunflower）。

- [ ] **Step 5: 更新 .tres 资源文件**

`resources/towers/pea_shooter.tres` — 将 `icon_path = ""` 改为：
```
icon_path = "res://assets/towers/pea_shooter/sprite.png"
projectile_sprite_path = "res://assets/projectiles/pea.png"
```

`resources/towers/ice_flower.tres` — 将 `icon_path = ""` 改为：
```
icon_path = "res://assets/towers/ice_flower/sprite.png"
```

`resources/towers/sunflower.tres` — 将 `icon_path = ""` 改为：
```
icon_path = "res://assets/towers/sunflower/sprite.png"
```

- [ ] **Step 6: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit -gtest=test_tower_data.gd`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add scripts/resources/tower_data.gd resources/towers/ assets/towers/pea_shooter/ assets/towers/ice_flower/ assets/towers/sunflower/ assets/towers/shared/ assets/projectiles/pea.png tests/unit/test_tower_data.gd
git commit -m "feat: 塔 TowerData 扩展 + 占位精灵 + icon_path 填入"
```

---

## Chunk 2: 场景改造（原子化：基类 + 3 场景一次提交）

> **重要**：tower.gd 基类的 AnimatedSprite2D 引用和 3 个场景的 Visual 节点改造必须原子化完成，避免中间状态导致运行时错误。

### Task 2: tower.gd 基类动画支持 + 所有场景改造

**Files:**
- Modify: `scripts/entities/towers/tower.gd`
- Modify: `scripts/entities/towers/tower_shooter.gd`
- Modify: `scripts/entities/towers/tower_slow.gd`
- Modify: `scripts/entities/towers/tower_generator.gd`
- Modify: `scenes/entities/towers/tower_pea_shooter.tscn`
- Modify: `scenes/entities/towers/tower_ice_flower.tscn`
- Modify: `scenes/entities/towers/tower_sunflower.tscn`

- [ ] **Step 1: tower.gd 新增动画引用和等级装饰逻辑**

在 `tower.gd` 变量区域添加（`@onready var health` 上方）：

```gdscript
# 动画节点引用 — 使用 get_node_or_null 保证安全（场景改造过渡期兼容）
var visual: AnimatedSprite2D = null

# 等级装饰
var _level_glow: Sprite2D = null

const LV2_GLOW_PATH: String = "res://assets/towers/shared/lv2_glow.png"
const LV3_GLOW_PATH: String = "res://assets/towers/shared/lv3_glow.png"
```

修改 `_ready()` 为：

```gdscript
func _ready() -> void:
	visual = get_node_or_null("Visual") as AnimatedSprite2D
	_apply_level_stats()
	_setup_level_glow()
	health.death_color = Color.GREEN
	health.died.connect(_on_died)
	add_to_group(Enums.Group.TOWERS)
	# 播放待机动画
	if visual and visual.sprite_frames and visual.sprite_frames.has_animation("idle"):
		visual.play("idle")
```

在文件末尾（`_on_died()` 之后）添加：

```gdscript
func _setup_level_glow() -> void:
	if current_level < 2:
		return
	var glow_path: String = LV2_GLOW_PATH if current_level == 2 else LV3_GLOW_PATH
	if ResourceLoader.exists(glow_path):
		_level_glow = Sprite2D.new()
		_level_glow.texture = load(glow_path)
		_level_glow.z_index = -1
		add_child(_level_glow)

func play_attack_animation() -> void:
	if not visual or not visual.sprite_frames:
		return
	if not visual.sprite_frames.has_animation("attack"):
		return
	visual.play("attack")
	if not visual.animation_finished.is_connected(_on_attack_animation_finished):
		visual.animation_finished.connect(_on_attack_animation_finished, CONNECT_ONE_SHOT)

func _on_attack_animation_finished() -> void:
	if visual and visual.sprite_frames and visual.sprite_frames.has_animation("idle"):
		visual.play("idle")
```

- [ ] **Step 2: 改造 tower_pea_shooter.tscn**

用 MCP 工具或手动编辑 `.tscn`：
1. 移除旧 `ext_resource` tileset 引用
2. 添加新 `ext_resource` 指向 `assets/towers/pea_shooter/sprite.png`
3. 创建 `SpriteFrames` sub_resource，包含：
   - `idle` 动画：1 帧，使用 sprite.png，**loop = true**
   - `attack` 动画：1 帧，使用 sprite.png，**loop = false**（关键：非循环，确保 `animation_finished` 信号触发）
4. 将 `Visual` 节点类型从 `Sprite2D` 改为 `AnimatedSprite2D`，挂载 SpriteFrames
5. 移除 `region_enabled` 和 `region_rect` 属性

- [ ] **Step 3: tower_shooter.gd 攻击时播放动画 + 弹道精灵**

修改 `_shoot_nearest_enemy()` 为：

```gdscript
func _shoot_nearest_enemy() -> void:
	var enemies: Array[Node2D] = detect_area.get_overlapping_bodies()
	var closest: Node2D = null
	var min_dist: float = attack_range

	for enemy: Node2D in enemies:
		if enemy.is_in_group(Enums.Group.ENEMIES):
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy

	if closest:
		var bullet: BulletProjectile = SceneFactory.create_bullet_projectile()
		var direction: Vector2 = global_position.direction_to(closest.global_position)
		# 弹道精灵（附加到 bullet，跟随方向旋转）
		if data.projectile_sprite_path != "" and ResourceLoader.exists(data.projectile_sprite_path):
			var proj_sprite: Sprite2D = Sprite2D.new()
			proj_sprite.texture = load(data.projectile_sprite_path)
			proj_sprite.rotation = direction.angle()
			bullet.add_child(proj_sprite)
		get_parent().add_child(bullet)
		bullet.setup(attack_damage, 0.0, global_position, direction)
		# 攻击动画
		play_attack_animation()
```

- [ ] **Step 4: 改造 tower_ice_flower.tscn**

与 pea_shooter 同理：
1. 移除 tileset `ext_resource`
2. 添加 `ice_flower/sprite.png` 的 `ext_resource`
3. 创建 `SpriteFrames`：`idle`（loop=true）、`attack`（loop=false）
4. `Visual` 从 `Sprite2D` 改为 `AnimatedSprite2D`

- [ ] **Step 5: tower_slow.gd 敌人进入时播放 attack 动画（防重复触发）**

修改 `_on_enemy_entered()` 为：

```gdscript
func _on_enemy_entered(body: Node2D) -> void:
	if body.is_in_group(Enums.Group.ENEMIES) and body.has_method("apply_slow"):
		body.apply_slow(slow_percent, str(get_instance_id()))
		# 仅在未播放攻击动画时触发（防止多个敌人快速进入重复打断）
		if visual and visual.animation != "attack":
			play_attack_animation()
```

- [ ] **Step 6: 改造 tower_sunflower.tscn**

1. 删除 `ColorRect` 节点（当前命名为 `ColorRect`，不是 `Visual`）
2. 添加 `AnimatedSprite2D` 命名 `Visual`
3. 创建 `SpriteFrames`：`idle`（loop=true）、`attack`（loop=false）

- [ ] **Step 7: tower_generator.gd 产金时播放 attack 动画**

修改 `_on_generate_timer_timeout()` 为：

```gdscript
func _on_generate_timer_timeout() -> void:
	EventBus.coins_generated.emit(generate_amount, global_position)
	play_attack_animation()
```

- [ ] **Step 8: 运行全部测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全部 PASS

- [ ] **Step 9: Commit（原子提交）**

```bash
git add scripts/entities/towers/ scenes/entities/towers/
git commit -m "feat: 塔场景改造为 AnimatedSprite2D + 动画系统 + 弹道精灵"
```

---

## Chunk 3: 清理 + 最终验证

### Task 3: 清理旧资源

**Files:**
- Delete: `assets/towers/tileset_towers.png` + `.import`

> 注意：不删除未使用塔的空目录（bamboo、cactus 等），这些保留给未来塔扩展使用。

- [ ] **Step 1: 删除 tileset**

```bash
rm assets/towers/tileset_towers.png
rm assets/towers/tileset_towers.png.import
```

- [ ] **Step 2: 运行全部测试确认无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全部 PASS

- [ ] **Step 3: Commit**

```bash
git add -A assets/towers/tileset_towers.png assets/towers/tileset_towers.png.import
git commit -m "chore: 删除不再使用的 tileset_towers.png"
```

### Task 4: 端到端验证

- [ ] **Step 1: 在编辑器中运行游戏**

验证清单：
- pea_shooter：显示占位精灵，射击时弹道有豌豆精灵（带旋转），idle 动画播放
- ice_flower：显示占位精灵，敌人进入减速区时 attack 动画播放，无重复触发
- sunflower：显示占位精灵（不再是黄色方块），产金时 attack 动画播放
- Lv2/Lv3 塔：有光圈叠加装饰
- 无控制台报错

- [ ] **Step 2: 确认后提交最终状态**

如有修复，追加 commit。
