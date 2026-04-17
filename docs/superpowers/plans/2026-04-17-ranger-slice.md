# 游侠垂直切片 (#2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 utoland 从"装备栏 + 武器合成"模式彻底切换到"英雄自动技能 + 专属 perk 池"模式，以游侠为垂直切片验证端到端流程。

**Architecture:** 三件事并行 — (1) 拆：移除武器装备栏/合成/人口/老角色/老被动系统；(2) 建：扩展 CharacterData + 新增能力组件体系（4 个独立 Node 挂 Player 下，Resource 驱动数值）+ PerkManager 改造为按 `max_level` 限流的分类抽取；(3) 补：新增游侠角色 + 基础自动攻击 + 3 个自动技能（疾风箭/箭雨/猎杀标记）+ 18 个专属 perk + 扩充到 20 波。

**Tech Stack:** Godot 4.6 (GDScript)，GUT 测试框架。

**Spec:** `docs/superpowers/specs/2026-04-17-ranger-slice-design.md`

---

## File Structure

### 新增文件

| 文件 | 职责 |
|---|---|
| `scripts/resources/hero_abilities/auto_attack_data.gd` | 基础自动攻击 Resource |
| `scripts/resources/hero_abilities/gust_arrow_data.gd` | 疾风箭 Resource |
| `scripts/resources/hero_abilities/arrow_rain_data.gd` | 箭雨 Resource |
| `scripts/resources/hero_abilities/hunt_mark_data.gd` | 猎杀标记 Resource |
| `scripts/components/hero_abilities/auto_attack_component.gd` + `.tscn` | 基础自动攻击组件 |
| `scripts/components/hero_abilities/gust_arrow_skill_component.gd` + `.tscn` | 疾风箭组件 |
| `scripts/components/hero_abilities/arrow_rain_skill_component.gd` + `.tscn` | 箭雨组件 |
| `scripts/components/hero_abilities/hunt_mark_skill_component.gd` + `.tscn` | 猎杀标记组件 |
| `scenes/entities/projectiles/gust_arrow.tscn` | 疾风箭投射物场景 |
| `scenes/entities/effects/arrow_rain_effect.tscn` | 箭雨 AoE 场景 |
| `scenes/entities/effects/hunt_mark_indicator.tscn` | 猎杀标记头顶视觉 |
| `resources/hero_abilities/ranger/auto_attack.tres` | 基础攻击数值配置 |
| `resources/hero_abilities/ranger/gust_arrow.tres` | 疾风箭数值配置 |
| `resources/hero_abilities/ranger/arrow_rain.tres` | 箭雨数值配置 |
| `resources/hero_abilities/ranger/hunt_mark.tres` | 猎杀标记数值配置 |
| `resources/characters/ranger.tres` | 游侠 CharacterData |
| `resources/exp/ranger_exp.tres` | 游侠专属 ExpConfig |
| `resources/perks/ranger/*.tres` × 18 | 18 个游侠专属 perk |
| `assets/characters/ranger/` | 游侠精灵素材（占位） |
| `resources/waves/forest/wave_13.tres` ～ `wave_20.tres` | 新增 8 波 |
| `tests/unit/test_perk_data_max_level.gd` | PerkData 字段校验 |
| `tests/unit/test_perk_manager_category.gd` | 改写 PerkManager 测试 |
| `tests/unit/test_tower_cost_progression.gd` | 塔价格递增 |
| `tests/unit/test_auto_attack_component.gd` | 基础攻击组件 |
| `tests/unit/test_gust_arrow_component.gd` | 疾风箭组件 |
| `tests/unit/test_arrow_rain_component.gd` | 箭雨组件 |
| `tests/unit/test_hunt_mark_component.gd` | 猎杀标记组件 |
| `tests/unit/test_character_data_abilities.gd` | CharacterData 新字段 |
| `tests/integration/test_ranger_flow.gd` | 游侠升级 + perk 全链路 |

### 修改文件

| 文件 | 改动摘要 |
|---|---|
| `scripts/resources/perk_data.gd` | 加 `max_level: int` + `category: Category` 枚举 |
| `scripts/resources/character_data.gd` | 删被动字段，加 `ability_scenes` / `exp_config` / `perk_pool` |
| `scripts/resources/exp_config.gd` | 删 `initial_population` / `population_per_level` |
| `scripts/resources/shop_config.gd` | 加 `tower_cost_base` + `tower_cost_per_same_type` |
| `scripts/core/perk_manager.gd` | 从 `CharacterData.perk_pool` 加载，按 category 4 类抽 3 类各 1；`max_level` 限流；`_perk_levels` 字典 |
| `scripts/core/inventory_manager.gd` | 删 `deployed_weapons` + 武器合成；`deploy_pending_tower` 用 `buy_cost` 递增 |
| `scripts/core/player_progression.gd` | 删 `get_population_cap()` |
| `scripts/core/player_state.gd` | 删被动字段；从 `CharacterData.exp_config` 注入；`player_stats` 去 `POPULATION_BONUS` / `MELEE_*` / `HP_MULT` / `DAMAGE_MULT` / `ATTACK_SPEED_MULT` / `TOWER_MULT` |
| `scripts/core/enums.gd` | 删 `Character.DORA/GORG/KAZE/MERLIN/NEMO`；加 `Character.RANGER`；`Stat` 清理无用 key；`WeaponId` 整个删 |
| `scripts/core/event_bus.gd` | 加 `hunt_mark_applied(enemy)` / `hunt_mark_cleared(enemy)` / `no_perk_available()` |
| `scripts/entities/player.gd` | 删被动系统 + WeaponManager；加 `$Abilities` 容器挂载能力组件；`_apply_level_growth` 移除老 passive 相关 |
| `scripts/entities/enemy.gd` | `_apply_damage` 或 `Hurtbox` 处检查 `has_meta("hunt_marked")` 应用伤害倍率 |
| `scenes/entities/player.tscn` | 删 `WeaponManager` 子节点，加 `Abilities: Node` 子节点 |
| `scripts/ui/battle_hud.gd` + `.tscn` | 删装备栏 + 人口显示；加猎杀充能条 + 箭雨 CD 指示 |
| `scripts/ui/perk_selection_overlay.gd` | 卡片显示 `[n/max]` 堆叠 |
| `scripts/ui/character_selection.gd` + `.tscn` | 只显示 ranger + 5 个"敬请期待"占位 |
| `scripts/ui/upgrade_card_builder.gd` | 删武器相关逻辑 |
| `project.godot` | 从 Autoload 列表确认仍正常（不变更） |

### 删除文件

| 文件 | 原因 |
|---|---|
| `scripts/entities/weapons/weapon_manager.gd` + `.uid` | 武器系统整个移除（spec §3.1） |
| `resources/weapons/bow.tres` / `shuriken.tres` / `sword.tres` | 武器资源 |
| `scripts/resources/weapon_data.gd` + `.uid` | 武器 Resource 类 |
| `scripts/resources/melee_config.gd` + `.uid` | 近战配置（武器专用） |
| `scripts/components/melee_attack_component.gd` + `.uid` | 近战组件（武器专用） |
| `resources/characters/dora.tres` / `gorg.tres` / `kaze.tres` / `merlin.tres` / `nemo.tres` | 老角色 |
| `assets/characters/dora/` / `gorg/` / `kaze/` / `merlin/` / `nemo/` | 老角色素材 |
| `scripts/resources/passive_evolution_data.gd` (若存在) | 老被动进化 |
| `resources/passives/` 目录（若存在） | 老被动数据 |
| `resources/perks/expansion.tres` | 人口 perk 删除 |
| `tests/unit/test_character_balance.gd` | 老角色平衡测试 |
| `tests/unit/test_inventory_pending.gd` 的武器合成部分 | 武器合成测试 |
| `tests/unit/test_perk_manager.gd` | 被 `test_perk_manager_category.gd` 替代 |

---

## 通用工具

### 运行所有测试

```bash
cd /Users/langtao/utoland
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

### 运行单个测试文件

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_perk_data_max_level.gd -gexit
```

### 提交格式

`<type>(#2): <中文描述>`，type = feat / fix / refactor / test / docs / chore。

### headless 测试刷新 class_name

新增带 `class_name` 的脚本后，若 headless 测试识别不到该类名，手动在 `.godot/global_script_class_cache.cfg` 中补充对应条目。通常 Godot 编辑器打开后会自动刷新。

---

## Task 1：删除武器系统（WeaponManager + 武器资源 + 武器相关 API）

**目的**：在不引入新能力系统的情况下，完全切除装备栏 + 合成 + 武器运行时代码。期间 Player 无攻击能力（会被敌人打死），只需保证编译通过 + 非武器测试通过。后续 Task 会加回游侠的能力。

**Files:**
- Delete: `scripts/entities/weapons/weapon_manager.gd` + `.uid`
- Delete: `resources/weapons/bow.tres` / `shuriken.tres` / `sword.tres`
- Delete: `scripts/resources/weapon_data.gd` + `.uid`
- Delete: `scripts/resources/melee_config.gd` + `.uid`
- Delete: `scripts/components/melee_attack_component.gd` + `.uid`
- Modify: `scripts/core/inventory_manager.gd`
- Modify: `scripts/core/player_state.gd`
- Modify: `scripts/core/enums.gd`
- Modify: `scripts/core/game_config.gd`
- Modify: `scripts/entities/player.gd`
- Modify: `scenes/entities/player.tscn`
- Modify: `scripts/ui/upgrade_card_builder.gd`
- Modify: `scripts/resources/character_data.gd`（暂不删 `starting_weapon` 字段，避免 .tres 报错；Task 2 跟老角色一起删）

- [ ] **Step 1.1：删除武器 Resource 类与配置**

```bash
cd /Users/langtao/utoland
rm scripts/entities/weapons/weapon_manager.gd scripts/entities/weapons/weapon_manager.gd.uid
rm scripts/resources/weapon_data.gd scripts/resources/weapon_data.gd.uid
rm scripts/resources/melee_config.gd scripts/resources/melee_config.gd.uid
rm scripts/components/melee_attack_component.gd scripts/components/melee_attack_component.gd.uid
rm resources/weapons/bow.tres resources/weapons/shuriken.tres resources/weapons/sword.tres
rmdir scripts/entities/weapons resources/weapons
```

- [ ] **Step 1.2：修改 `scripts/core/inventory_manager.gd` — 删除 deployed_weapons 与武器操作**

替换整个文件为：

```gdscript
extends Node

# 装备与经济管理（塔、金币、合成、Roll/Pending、价格递增）

var coins: int = GameConfig.PLAYER["initial_coins"]
var deployed_towers: Array[Dictionary] = []
var _next_deploy_id: int = 1

# 待建造栏(roll 出来选的塔卡片,等待拖到地图上放置)
var pending_towers: Array[String] = []  # 元素是 tower_id

# Roll 管理器(惰性初始化)
var _roll_manager: TowerRollManager = null

# 当前 Roll 出来的 3 个候选
var _current_roll_offer: Array[String] = []

func buy_and_place_tower(tower_id: String, cost: int, grid_pos: Vector2i) -> int:
    if coins < cost:
        return 0
    coins -= cost
    var deploy_id: int = _next_deploy_id
    _next_deploy_id += 1
    deployed_towers.append({id = tower_id, level = 1, grid_pos = grid_pos, deploy_id = deploy_id})
    var item := {id = tower_id, type = "tower", level = 1}
    EventBus.item_purchased.emit(item)
    EventBus.coins_changed.emit(-cost, coins)
    return deploy_id

func move_tower(deploy_id: int, new_grid_pos: Vector2i) -> bool:
    if new_grid_pos.x < 0 or new_grid_pos.x >= GameConfig.MAP_GRID_WIDTH:
        return false
    if new_grid_pos.y < 0 or new_grid_pos.y >= GameConfig.MAP_GRID_HEIGHT:
        return false
    var tower_index := -1
    for i in range(deployed_towers.size()):
        if deployed_towers[i].deploy_id == deploy_id:
            tower_index = i
            break
    if tower_index == -1:
        return false
    for i in range(deployed_towers.size()):
        if i != tower_index and deployed_towers[i].grid_pos == new_grid_pos:
            return false
    var old_pos: Vector2i = deployed_towers[tower_index].grid_pos
    deployed_towers[tower_index].grid_pos = new_grid_pos
    EventBus.tower_moved.emit(deploy_id, old_pos, new_grid_pos)
    return true

func sell_from_deployed_tower(deploy_id: int) -> int:
    var tower_index := -1
    for i in range(deployed_towers.size()):
        if deployed_towers[i].deploy_id == deploy_id:
            tower_index = i
            break
    if tower_index == -1:
        return 0
    var entry: Dictionary = deployed_towers[tower_index]
    deployed_towers.remove_at(tower_index)
    var item := {id = entry.id, type = "tower", level = entry.level}
    return _apply_sell(item)

func _apply_sell(item: Dictionary) -> int:
    var data: Resource = GameConfig.towers[item.id]
    var base_value: int = data.sell_price_per_level[item.level - 1]
    var ratio: float = GameConfig.shop_config.sell_return_ratio
    var refund: int = int(round(base_value * ratio))
    coins += refund
    EventBus.item_sold.emit(item, refund)
    EventBus.coins_changed.emit(refund, coins)
    return refund

func _check_merge(item_id: String, item_level: int) -> void:
    if item_level >= 3:
        return
    var count: int = 0
    var pair_indices: Array[int] = []
    for i in range(deployed_towers.size()):
        if deployed_towers[i].id == item_id and deployed_towers[i].level == item_level:
            pair_indices.append(i)
            if pair_indices.size() >= 2:
                break
    if pair_indices.size() < 2:
        return
    var kept_idx: int = pair_indices[0]
    var removed_idx: int = pair_indices[1]
    var kept_pos: Vector2i = deployed_towers[kept_idx].grid_pos
    var kept_deploy_id: int = deployed_towers[kept_idx].deploy_id
    deployed_towers.remove_at(removed_idx)
    deployed_towers.remove_at(kept_idx)
    var new_level: int = item_level + 1
    deployed_towers.append({id = item_id, level = new_level, grid_pos = kept_pos, deploy_id = kept_deploy_id})
    EventBus.item_merged.emit(item_id, new_level)
    _check_merge(item_id, new_level)

func merge_tower(deploy_id: int) -> bool:
    var clicked_index: int = -1
    for i in range(deployed_towers.size()):
        if deployed_towers[i].deploy_id == deploy_id:
            clicked_index = i
            break
    if clicked_index == -1:
        return false
    var entry: Dictionary = deployed_towers[clicked_index]
    var item_id: String = entry.id
    var item_level: int = entry.level
    if item_level >= 3:
        return false
    var pair_index: int = -1
    for i in range(deployed_towers.size()):
        if i != clicked_index and deployed_towers[i].id == item_id and deployed_towers[i].level == item_level:
            pair_index = i
            break
    if pair_index == -1:
        return false
    deployed_towers.remove_at(pair_index)
    var actual_index: int = clicked_index if pair_index > clicked_index else clicked_index - 1
    deployed_towers[actual_index].level = item_level + 1
    EventBus.item_merged.emit(item_id, item_level + 1)
    return true

func reset() -> void:
    var char_data: CharacterData = GameConfig.characters[PlayerState.current_character]
    coins = GameConfig.PLAYER["initial_coins"] + char_data.starting_gold
    deployed_towers = []
    _next_deploy_id = 1
    pending_towers = []
    _current_roll_offer = []

# ===== Roll / Pending 管理 =====

func _get_roll_manager() -> TowerRollManager:
    if _roll_manager == null:
        _roll_manager = TowerRollManager.new()
    return _roll_manager

func roll_tower() -> bool:
    var cost: int = GameConfig.shop_config.roll_cost
    if coins < cost:
        return false
    if pending_towers.size() >= GameConfig.shop_config.pending_queue_size:
        return false
    if not _current_roll_offer.is_empty():
        return false
    coins -= cost
    EventBus.coins_changed.emit(-cost, coins)
    _current_roll_offer = []
    for tid in _get_roll_manager().roll_three(PlayerProgression.player_level):
        _current_roll_offer.append(tid)
    EventBus.tower_rolled.emit(_current_roll_offer.duplicate())
    return true

func confirm_roll_pick(candidate_index: int) -> bool:
    if candidate_index < 0 or candidate_index >= _current_roll_offer.size():
        return false
    var tower_id: String = _current_roll_offer[candidate_index]
    pending_towers.append(tower_id)
    _current_roll_offer = []
    EventBus.tower_added_to_queue.emit(tower_id)
    return true

func cancel_roll() -> void:
    if _current_roll_offer.is_empty():
        return
    var refund: int = GameConfig.shop_config.roll_cost
    coins += refund
    EventBus.coins_changed.emit(refund, coins)
    _current_roll_offer = []
    EventBus.tower_roll_canceled.emit()

func consume_pending(index: int) -> String:
    if index < 0 or index >= pending_towers.size():
        return ""
    var tid: String = pending_towers[index]
    pending_towers.remove_at(index)
    EventBus.tower_consumed_from_queue.emit(index)
    return tid

func can_roll() -> bool:
    return (coins >= GameConfig.shop_config.roll_cost
        and pending_towers.size() < GameConfig.shop_config.pending_queue_size
        and _current_roll_offer.is_empty())

func get_current_roll_offer() -> Array[String]:
    return _current_roll_offer.duplicate()

## 部署一个 pending 塔(从队列取出 + 扣金币 + 放置 + 自动合成)
## 失败返回 {}，不扣金币；成功返回 {tower_id, deploy_id, level, merged_away}
func deploy_pending_tower(pending_index: int, grid_pos: Vector2i) -> Dictionary:
    if pending_index < 0 or pending_index >= pending_towers.size():
        return {}
    var tower_id: String = pending_towers[pending_index]
    # Task 14 将加 buy_cost 递增扣金币
    var old_ids: Array[int] = []
    for entry in deployed_towers:
        old_ids.append(entry.deploy_id)
    pending_towers.remove_at(pending_index)
    EventBus.tower_consumed_from_queue.emit(pending_index)
    var deploy_id: int = _next_deploy_id
    _next_deploy_id += 1
    deployed_towers.append({
        id = tower_id, level = 1,
        grid_pos = grid_pos, deploy_id = deploy_id,
    })
    EventBus.tower_placed.emit(tower_id, Vector2(grid_pos))
    EventBus.item_purchased.emit({id = tower_id, type = "tower", level = 1})
    _check_merge(tower_id, 1)
    var current_ids: Array[int] = []
    for entry in deployed_towers:
        current_ids.append(entry.deploy_id)
    var merged_away: Array[int] = []
    for old_id in old_ids:
        if old_id not in current_ids:
            merged_away.append(old_id)
    var final_level: int = 1
    for entry in deployed_towers:
        if entry.deploy_id == deploy_id:
            final_level = entry.level
            break
    return {
        "tower_id": tower_id,
        "deploy_id": deploy_id,
        "level": final_level,
        "merged_away": merged_away,
    }
```

- [ ] **Step 1.3：修改 `scripts/entities/player.gd` — 删除 WeaponManager 引用与动态伤害回调**

删除以下行（可能分散在多处）：
- `@onready var _weapon_manager: WeaponManager = $WeaponManager`
- `_weapon_manager.initialize(...)` / `set_dynamic_damage_mult_getter(...)` / `weapon_attack_executed.connect(...)` / `refresh_passive_multipliers()` / `tick_visual()` / `tick_combat()`
- `_on_weapon_attack_executed`、`_get_dynamic_damage_mult`、`get_combo_damage_mult`、`update_combo_target`、`get_blood_rage_mult` 方法
- `_combo_target`、`_combo_stacks`、`_fortify_regen_timer`、`_passive_evolution`、`_current_passive_tier`、`_kill_heal_amount` 字段
- `_init_passives`、`_apply_passive_tier`、`_on_enemy_killed_heal`、`_process_passives`、`_count_fortify_units` 方法

`_process(delta)` 中删除 `_weapon_manager.tick_visual(delta)` 和 `_process_passives(delta)`。
`_physics_process(delta)` 中删除 `_weapon_manager.tick_combat(delta)`。
`_on_level_up(new_level)` 中删除 `_apply_passive_tier(new_level)` 和 `_weapon_manager.refresh_passive_multipliers()`。

`_ready()` 中删除武器/被动相关行，保留 HP/move_speed/perk/character 精灵设置等核心逻辑。Player 本 Task 后**无攻击能力**（等 Task 13 挂能力）。

- [ ] **Step 1.4：修改 `scenes/entities/player.tscn` — 删除 WeaponManager 子节点**

打开 `scenes/entities/player.tscn`（文本模式），找到 `[node name="WeaponManager" type="Node2D" parent="."]` 整个节点块，删除。如果有 `ext_resource` 指向 `weapon_manager.gd` 也删除。

保留 Player 本身、HealthComponent、Hurtbox、SpriteAnimator 等其它节点。

- [ ] **Step 1.5：修改 `scripts/core/enums.gd` — 删除 WeaponId 类**

删除整个：

```gdscript
class WeaponId:
    const BOW = "bow"
    const SHURIKEN = "shuriken"
    const SWORD = "sword"
```

- [ ] **Step 1.6：修改 `scripts/core/game_config.gd` — 删除 weapons 加载**

删除 `weapons: Dictionary` 字段及其加载逻辑（查找 `weapons[` 引用），从 `_load_resources()` 或类似方法中移除 `resources/weapons/` 的加载分支。

- [ ] **Step 1.7：修改 `scripts/core/player_state.gd` — 删除 HP_MULT / DAMAGE_MULT / ATTACK_SPEED_MULT / TOWER_MULT / MELEE_* 运行时字段**

```gdscript
# player_stats 字典初始化改为（删除老字段）:
var player_stats: Dictionary = {
    Enums.Stat.MAX_HP: 100.0,
    # Perk bonus(战斗中累加,reset 重置)
    Enums.Stat.HP_BONUS_PERCENT: 0.0,
    Enums.Stat.MOVE_SPEED_BONUS_PERCENT: 0.0,
    Enums.Stat.DAMAGE_BONUS_PERCENT: 0.0,
    Enums.Stat.ATTACK_SPEED_BONUS_PERCENT: 0.0,
    Enums.Stat.PICKUP_RADIUS_BONUS_PERCENT: 0.0,
    Enums.Stat.COIN_DROP_BONUS_PERCENT: 0.0,
    Enums.Stat.EXP_GAIN_BONUS_PERCENT: 0.0,
    Enums.Stat.POPULATION_BONUS: 0,  # Task 3 删除
}
```

删除 `character_damage_mult`、`character_attack_speed_mult` 字段（保留 `character_max_hp` 和 `character_speed`，这两个还会用）。

`init_character` 中移除对这两字段的赋值。

`reset` 同步更新 `player_stats` 初始化的列表。

- [ ] **Step 1.8：修改 `scripts/ui/upgrade_card_builder.gd` — 删除武器分支**

删除任何用到 `WeaponData` / `wd.attack_config` / `weapon_id` / `weapons` 字典的分支。保留 tower 相关。若文件整体围绕武器升级卡构建，则查看是否还有调用者；若无调用者，整个文件可删。

- [ ] **Step 1.9：运行测试验证（预期若干失败，确认剩余失败与武器无关）**

```bash
cd /Users/langtao/utoland
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -40
```

预期多个武器相关测试失败（`test_inventory_pending.gd` 等），但**编译通过**（不出现 `Parse Error`）。若有非武器相关的 parse error，修复后再继续。

- [ ] **Step 1.10：删除武器/合成相关测试**

```bash
rm tests/unit/test_inventory_pending.gd tests/unit/test_inventory_pending.gd.uid
```

（可能还有其它武器测试，通过 `grep -rln "deployed_weapons\|WeaponManager\|WeaponData" tests/` 全找出来删掉或清理。）

- [ ] **Step 1.11：再次运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

目标：**编译无 Parse Error**，测试数量减少（已删武器测试）但**剩余测试若有失败应是 Task 2/3 要处理的老被动/人口相关**。

- [ ] **Step 1.12：Commit**

```bash
git add -u
git add scripts/core/inventory_manager.gd
git commit -m "refactor(#2): 删除武器系统 (WeaponManager / 武器资源 / 装备栏 API)"
```

---

## Task 2：删除老角色与被动系统

**Files:**
- Delete: `resources/characters/dora.tres` / `gorg.tres` / `kaze.tres` / `merlin.tres` / `nemo.tres`
- Delete: `assets/characters/dora/` / `gorg/` / `kaze/` / `merlin/` / `nemo/`
- Delete: `scripts/resources/passive_evolution_data.gd` + `.uid`（若存在）
- Delete: `resources/passives/`（若存在）
- Modify: `scripts/resources/character_data.gd`
- Modify: `scripts/core/player_state.gd`
- Modify: `scripts/core/enums.gd`
- Modify: `scripts/entities/player.gd`

- [ ] **Step 2.1：删除老角色素材与资源**

```bash
cd /Users/langtao/utoland
rm -rf assets/characters/dora assets/characters/gorg assets/characters/kaze assets/characters/merlin assets/characters/nemo
rm resources/characters/dora.tres resources/characters/gorg.tres resources/characters/kaze.tres resources/characters/merlin.tres resources/characters/nemo.tres
# 删除被动数据（若存在）
if [ -f scripts/resources/passive_evolution_data.gd ]; then rm scripts/resources/passive_evolution_data.gd scripts/resources/passive_evolution_data.gd.uid; fi
if [ -d resources/passives ]; then rm -rf resources/passives; fi
```

- [ ] **Step 2.2：修改 `scripts/resources/character_data.gd` — 删除被动/武器字段**

替换整个文件为：

```gdscript
class_name CharacterData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var max_hp: float = 100.0
@export var speed: float = 100.0
@export var starting_gold: int = 0

## 精灵 SpriteFrames 资源路径（Aseprite Wizard 导出的 .res）
@export var sprite_frames_path: String = ""
## 头像 PNG 路径
@export var portrait_path: String = ""
## 原始精灵像素尺寸，用于缩放计算
@export var sprite_pixel_size: float = 16.0

## 专属经验曲线（null 时后备 GameConfig.exp_config）
@export var exp_config: ExpConfig = null
## 专属 perk 池（空数组表示无升级可选）
@export var perk_pool: Array[PerkData] = []
## 升级时挂到 Player $Abilities 下的能力组件场景，按顺序实例化
@export var ability_scenes: Array[PackedScene] = []
```

- [ ] **Step 2.3：修改 `scripts/core/enums.gd` — 替换角色枚举**

```gdscript
# 角色 ID
class Character:
    const RANGER = "ranger"

# Stat 类清理：删除 HP_MULT / DAMAGE_MULT / ATTACK_SPEED_MULT / TOWER_MULT / MELEE_DAMAGE_MULT / MELEE_ATTACK_SPEED_MULT
class Stat:
    const MAX_HP = "max_hp"
    # Perk bonus(战斗中 3 选 1 累加)
    const HP_BONUS_PERCENT = "hp_bonus_percent"
    const MOVE_SPEED_BONUS_PERCENT = "move_speed_bonus_percent"
    const DAMAGE_BONUS_PERCENT = "damage_bonus_percent"
    const ATTACK_SPEED_BONUS_PERCENT = "attack_speed_bonus_percent"
    const PICKUP_RADIUS_BONUS_PERCENT = "pickup_radius_bonus_percent"
    const COIN_DROP_BONUS_PERCENT = "coin_drop_bonus_percent"
    const EXP_GAIN_BONUS_PERCENT = "exp_gain_bonus_percent"
    const POPULATION_BONUS = "population_bonus"  # Task 3 移除
```

- [ ] **Step 2.4：修改 `scripts/core/player_state.gd` — 删除被动字段与老默认角色**

```gdscript
extends Node

# 角色身份与属性状态
var current_character: String = Enums.Character.RANGER
var selected_map: String = Enums.Map.FOREST
var current_wave: int = 0

# 角色属性（从 CharacterData 初始化）
var character_max_hp: float = 0.0
var character_speed: float = 0.0

# 运行时属性集
var player_stats: Dictionary = {
    Enums.Stat.MAX_HP: 100.0,
    Enums.Stat.HP_BONUS_PERCENT: 0.0,
    Enums.Stat.MOVE_SPEED_BONUS_PERCENT: 0.0,
    Enums.Stat.DAMAGE_BONUS_PERCENT: 0.0,
    Enums.Stat.ATTACK_SPEED_BONUS_PERCENT: 0.0,
    Enums.Stat.PICKUP_RADIUS_BONUS_PERCENT: 0.0,
    Enums.Stat.COIN_DROP_BONUS_PERCENT: 0.0,
    Enums.Stat.EXP_GAIN_BONUS_PERCENT: 0.0,
    Enums.Stat.POPULATION_BONUS: 0,  # Task 3 移除
}

func _ready() -> void:
    # 在 GameConfig 已注册 ranger 之前不初始化，避免报错
    pass

func init_character(character_id: String) -> void:
    if not GameConfig.characters.has(character_id):
        push_error("未知角色: " + character_id)
        return
    current_character = character_id
    var char_data: CharacterData = GameConfig.characters[character_id]
    character_max_hp = char_data.max_hp
    character_speed = char_data.speed

func reset() -> void:
    init_character(current_character)
    selected_map = Enums.Map.FOREST
    current_wave = 0
    player_stats = {
        Enums.Stat.MAX_HP: character_max_hp,
        Enums.Stat.HP_BONUS_PERCENT: 0.0,
        Enums.Stat.MOVE_SPEED_BONUS_PERCENT: 0.0,
        Enums.Stat.DAMAGE_BONUS_PERCENT: 0.0,
        Enums.Stat.ATTACK_SPEED_BONUS_PERCENT: 0.0,
        Enums.Stat.PICKUP_RADIUS_BONUS_PERCENT: 0.0,
        Enums.Stat.COIN_DROP_BONUS_PERCENT: 0.0,
        Enums.Stat.EXP_GAIN_BONUS_PERCENT: 0.0,
        Enums.Stat.POPULATION_BONUS: 0,
    }
```

> 注意：`pending_heal` 字段已删。若 Player/其它地方有引用，顺带清理。

- [ ] **Step 2.5：修改 `scripts/entities/player.gd` — 删除所有被动方法与字段**

在 Task 1 删 WeaponManager 的基础上，再删除以下所有被动相关代码：

- 字段：`_base_max_hp`、`_base_speed`、`_combo_target`、`_combo_stacks`、`_fortify_regen_timer`、`_passive_evolution`、`_current_passive_tier`、`_kill_heal_amount`
- 方法：`_init_passives`、`_apply_passive_tier`、`_on_enemy_killed_heal`、`_process_passives`、`_count_fortify_units`、`_get_dynamic_damage_mult`、`get_combo_damage_mult`、`update_combo_target`、`get_blood_rage_mult`、`_flash_white`、`_start_invincible_blink`（保留`_flash_white` 如被其它逻辑依赖）
- 常量 `_COMBO_MAX_STACKS`、`_FORTIFY_REGEN_INTERVAL`

保留：HP/速度初始化、`_apply_level_growth`（清理里面被动相关部分，只保留 HP/speed/pickup 成长 + perk bonus 应用）、`_on_perk_applied`、`_on_died`、`add_exp`、`add_coins`、`heal_hp`、hurtbox hit 处理、移动逻辑。

`_ready()` 简化为：

```gdscript
func _ready() -> void:
    add_to_group(Enums.Group.PLAYER)
    var base_hp: float = PlayerState.player_stats[Enums.Stat.MAX_HP]
    _base_max_hp = base_hp
    _base_speed = PlayerState.character_speed
    speed = _base_speed
    health.initialize(base_hp)

    coins = InventoryManager.coins

    health.died.connect(_on_died)
    $Hurtbox.hit_taken.connect(_on_hurtbox_hit)

    var char_data: CharacterData = GameConfig.characters[PlayerState.current_character]
    var sprite_frames: SpriteFrames = load(char_data.sprite_frames_path)
    _sprite_animator.setup_from_sprite_frames(sprite_frames, char_data.sprite_pixel_size, GameConfig.ENTITY_SIZE_STANDARD)

    EventBus.player_level_changed.connect(_on_level_up)
    _apply_level_growth(PlayerProgression.player_level)
    EventBus.perk_applied.connect(_on_perk_applied)
```

保留 `_base_max_hp` 和 `_base_speed` 字段（`_apply_level_growth` 用）。

`_on_level_up(new_level)` 简化为：

```gdscript
func _on_level_up(new_level: int) -> void:
    _apply_level_growth(new_level)
```

`_apply_level_growth` 保留 HP/speed/pickup_range 与 perk bonus 组合（参考 §2.5 原文），但删除对 `MELEE_DAMAGE_MULT / MELEE_ATTACK_SPEED_MULT` 的任何引用。

- [ ] **Step 2.6：清理 player_state.pending_heal 引用**

```bash
grep -rn "pending_heal" scripts/ 2>&1 | grep -v "\.uid"
```

在输出的每个文件里删除相关行（预期 player.gd 已有使用）。

- [ ] **Step 2.7：运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -40
```

预期：许多测试因角色/被动相关失败（test_character_balance 等）。编译通过即可继续。

- [ ] **Step 2.8：删除被动/角色相关测试**

```bash
rm tests/unit/test_character_balance.gd tests/unit/test_character_balance.gd.uid
# 其它可能受影响测试通过 grep 找到
grep -rln "new_passive_id\|passive_evolution\|DORA\|KAZE\|NEMO\|GORG\|MERLIN" tests/
```

对输出文件逐个审视：若整文件围绕老角色，删除；若只是小引用，修正。

- [ ] **Step 2.9：Commit**

```bash
git add -u
git commit -m "refactor(#2): 删除 5 个老角色与老被动系统"
```

---

## Task 3：删除人口系统

**Files:**
- Modify: `scripts/core/player_progression.gd`
- Modify: `scripts/core/player_state.gd`
- Modify: `scripts/core/enums.gd`
- Modify: `scripts/resources/perk_data.gd`
- Modify: `scripts/resources/exp_config.gd`
- Modify: `scripts/core/perk_manager.gd`
- Modify: `scripts/core/inventory_manager.gd`（如仍有 `can_deploy` / `can_buy_item` / `get_population_used` 等 Task 1 可能留下的残留）
- Delete: `resources/perks/expansion.tres`
- Modify: `scripts/ui/battle_hud.gd` + `.tscn`（删除人口显示）

- [ ] **Step 3.1：删除 expansion perk**

```bash
rm resources/perks/expansion.tres
```

- [ ] **Step 3.2：修改 `scripts/core/perk_manager.gd` — 移除 expansion 引用**

在 `PERK_FILES` 数组中删除 `"res://resources/perks/expansion.tres"` 这一行（若仍在）。

`_apply_effect` 中移除 `PerkData.EffectType.POPULATION_FLAT` 分支。

- [ ] **Step 3.3：修改 `scripts/resources/perk_data.gd` — 移除 POPULATION_FLAT 枚举**

```gdscript
enum EffectType {
    HP_PERCENT,
    MOVE_SPEED_PERCENT,
    DAMAGE_PERCENT,
    ATTACK_SPEED_PERCENT,
    PICKUP_RADIUS_PERCENT,
    COIN_DROP_PERCENT,
    EXP_GAIN_PERCENT,
    # POPULATION_FLAT 已删除
    ABILITY_CUSTOM,  # 新增：能力组件自己按 id 识别的 perk（Task 4 再加）
}
```

（本 Task 先删 `POPULATION_FLAT`，`ABILITY_CUSTOM` 留到 Task 4 正式加。）

- [ ] **Step 3.4：修改 `scripts/resources/exp_config.gd` — 删除人口字段**

```gdscript
class_name ExpConfig
extends Resource

## 经验升级公式参数：exp_for_level(n) = floor(base_exp * n ^ exp_exponent)
@export var base_exp: float = 5.0
@export var exp_exponent: float = 2.0
```

- [ ] **Step 3.5：修改 `scripts/core/player_progression.gd` — 删除 get_population_cap**

```gdscript
extends Node

# 经验与等级系统

var player_level: int = 1
var current_exp: int = 0
var total_exp_earned: int = 0

func exp_for_level(level: int) -> int:
    var config: ExpConfig = _get_exp_config()
    return int(floor(config.base_exp * pow(level, config.exp_exponent)))

func _get_exp_config() -> ExpConfig:
    var char_data: CharacterData = GameConfig.characters.get(PlayerState.current_character)
    if char_data and char_data.exp_config:
        return char_data.exp_config
    return GameConfig.exp_config

func add_exp(amount: int) -> void:
    var bonus: float = PlayerState.player_stats.get(Enums.Stat.EXP_GAIN_BONUS_PERCENT, 0.0)
    var actual: int = int(round(amount * (1.0 + bonus)))
    current_exp += actual
    total_exp_earned += actual
    while current_exp >= exp_for_level(player_level + 1):
        player_level += 1
        EventBus.player_level_changed.emit(player_level)
    var next_threshold: int = exp_for_level(player_level + 1)
    EventBus.exp_changed.emit(current_exp, next_threshold)

func reset() -> void:
    player_level = 1
    current_exp = 0
    total_exp_earned = 0
```

> 这个实现也顺便接上了 spec §5（专属 ExpConfig 加载），`CharacterData.exp_config` 字段在 Task 2 已加。

- [ ] **Step 3.6：修改 `scripts/core/enums.gd` — 删除 POPULATION_BONUS**

从 `Stat` 类删除 `const POPULATION_BONUS = "population_bonus"` 一行。

- [ ] **Step 3.7：修改 `scripts/core/player_state.gd` — 删除 POPULATION_BONUS**

从 `player_stats` 字典初始化和 `reset` 中删除 `Enums.Stat.POPULATION_BONUS: 0` 两行。

- [ ] **Step 3.8：修改 `scripts/core/inventory_manager.gd` — 删除人口相关残留**

检查是否有任何引用：
```bash
grep -n "can_deploy\|can_buy_item\|get_population_used\|get_population_cap\|POPULATION_BONUS" scripts/core/inventory_manager.gd
```

若仍有（Task 1 改写时已删，但调用处可能遗漏），删除调用。

- [ ] **Step 3.9：全局检查人口引用残留**

```bash
grep -rn "get_population_cap\|get_population_used\|POPULATION_BONUS\|POPULATION_FLAT\|can_buy_item\|can_deploy" scripts/ 2>&1 | grep -v "\.uid"
```

对每个输出定位 + 删除/修正。常见位置：`scripts/systems/drag_manager.gd`、`scripts/ui/battle_hud.gd` 人口显示区域。

- [ ] **Step 3.10：修改 `scripts/ui/battle_hud.gd` + `.tscn` — 删除人口显示**

打开 `battle_hud.gd`，删除 `人口` 或 `population` 相关 Label 字段的 `@onready` 引用、`_update_population_label` 或类似方法、信号连接。

打开 `battle_hud.tscn`（文本模式），找到显示人口的 Label（通常名 `PopulationLabel` 或类似），删除该节点。

- [ ] **Step 3.11：运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -40
```

编译通过即可。**残留的测试失败**（比如 `test_perk_manager.gd` 引用的 expansion）在 Task 4/5 正式重写。

- [ ] **Step 3.12：Commit**

```bash
git add -u
git commit -m "refactor(#2): 删除人口系统 (get_population_cap / POPULATION_BONUS / expansion perk)"
```

---

## Task 4：扩展 PerkData（max_level + category）

**Files:**
- Modify: `scripts/resources/perk_data.gd`
- Create: `tests/unit/test_perk_data_max_level.gd`
- Modify: `resources/perks/*.tres`（回填 category=GENERIC + max_level=5）

- [ ] **Step 4.1：写失败测试 `tests/unit/test_perk_data_max_level.gd`**

```gdscript
extends GutTest

func test_default_max_level_is_5():
    var perk: PerkData = PerkData.new()
    assert_eq(perk.max_level, 5, "PerkData.max_level 默认应为 5")

func test_category_enum_exists_with_generic_default():
    var perk: PerkData = PerkData.new()
    assert_eq(perk.category, PerkData.Category.GENERIC, "PerkData.category 默认应为 GENERIC")

func test_category_enum_has_ranger_values():
    assert_true(PerkData.Category.has("RANGER_GUST"), "Category 应包含 RANGER_GUST") \
        if PerkData.Category is Dictionary else \
        assert_eq(typeof(PerkData.Category.RANGER_GUST), TYPE_INT, "RANGER_GUST 应为 int")
    assert_eq(typeof(PerkData.Category.RANGER_RAIN), TYPE_INT)
    assert_eq(typeof(PerkData.Category.RANGER_MARK), TYPE_INT)
    assert_eq(typeof(PerkData.Category.RANGER_UTILITY), TYPE_INT)
```

- [ ] **Step 4.2：运行测试确认失败**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_perk_data_max_level.gd -gexit 2>&1 | tail -15
```

预期：FAIL（max_level / category 字段不存在）。

- [ ] **Step 4.3：修改 `scripts/resources/perk_data.gd`**

```gdscript
class_name PerkData
extends Resource

enum EffectType {
    HP_PERCENT,
    MOVE_SPEED_PERCENT,
    DAMAGE_PERCENT,
    ATTACK_SPEED_PERCENT,
    PICKUP_RADIUS_PERCENT,
    COIN_DROP_PERCENT,
    EXP_GAIN_PERCENT,
    ABILITY_CUSTOM,  # 能力组件按 perk id 自己识别，effect_value 可作为每级数值
}

enum Category {
    GENERIC,          # 通用（#1 原 6 个）
    RANGER_GUST,      # 疾风箭方向（4 个）
    RANGER_RAIN,      # 箭雨方向（4 个）
    RANGER_MARK,      # 猎杀标记方向（4 个）
    RANGER_UTILITY,   # 游侠移动/生存方向（6 个）
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export_file("*.png") var icon_path: String = ""
@export var effect_type: EffectType = EffectType.HP_PERCENT
@export var effect_value: float = 0.0
@export var max_level: int = 5
@export var category: Category = Category.GENERIC
```

- [ ] **Step 4.4：运行测试确认通过**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_perk_data_max_level.gd -gexit 2>&1 | tail -15
```

预期：PASS。

- [ ] **Step 4.5：回填现有 6 个通用 perk 的 category 与 max_level**

打开 `resources/perks/vitality.tres` / `swift.tres` / `power.tres` / `rapid.tres` / `reach.tres` / `study.tres`（文本模式），在每个文件的最后添加：

```
max_level = 5
category = 0
```

（category 0 = `Category.GENERIC`）

> 对于加成型 perk（以上 6 个都是）`max_level = 5` 合理。若 `greed` 仍注释未启用，暂不处理。

- [ ] **Step 4.6：Commit**

```bash
git add scripts/resources/perk_data.gd resources/perks/*.tres tests/unit/test_perk_data_max_level.gd tests/unit/test_perk_data_max_level.gd.uid
git commit -m "feat(#2): PerkData 加 max_level 与 Category 枚举"
```

---

## Task 5：扩展 CharacterData 字段校验测试

> Task 2 已改 `character_data.gd`，本 Task 补一个最小的字段校验测试 + 加一个 `test_character_data_abilities.gd` 桩。

**Files:**
- Create: `tests/unit/test_character_data_abilities.gd`

- [ ] **Step 5.1：写测试**

```gdscript
extends GutTest

func test_character_data_has_new_fields():
    var cd: CharacterData = CharacterData.new()
    assert_eq(cd.ability_scenes.size(), 0, "ability_scenes 默认为空数组")
    assert_eq(cd.perk_pool.size(), 0, "perk_pool 默认为空数组")
    assert_null(cd.exp_config, "exp_config 默认为 null")

func test_character_data_no_old_passive_fields():
    var cd: CharacterData = CharacterData.new()
    # 通过 get_property_list 确认老字段已删
    var prop_names: Array = []
    for prop in cd.get_property_list():
        prop_names.append(prop.name)
    assert_false("passive_type" in prop_names, "passive_type 应已删除")
    assert_false("new_passive_id" in prop_names, "new_passive_id 应已删除")
    assert_false("passive_evolution" in prop_names, "passive_evolution 应已删除")
    assert_false("starting_weapon" in prop_names, "starting_weapon 应已删除")
    assert_false("recommended_weapon" in prop_names, "recommended_weapon 应已删除")
    assert_false("recommended_tower" in prop_names, "recommended_tower 应已删除")
```

- [ ] **Step 5.2：运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_character_data_abilities.gd -gexit 2>&1 | tail -15
```

预期：PASS（Task 2 已改完）。如某项失败说明 Task 2 清理不彻底，回 Task 2 补。

- [ ] **Step 5.3：Commit**

```bash
git add tests/unit/test_character_data_abilities.gd tests/unit/test_character_data_abilities.gd.uid
git commit -m "test(#2): CharacterData 新字段校验测试"
```

---

## Task 6：PerkManager 改造（分类抽取 + max_level 限流 + 角色专属池）

**Files:**
- Delete: `tests/unit/test_perk_manager.gd` + `.uid`
- Modify: `scripts/core/perk_manager.gd`
- Modify: `scripts/core/event_bus.gd`
- Create: `tests/unit/test_perk_manager_category.gd`

- [ ] **Step 6.1：修改 `scripts/core/event_bus.gd` — 加 `no_perk_available` 信号**

找到信号声明区，添加：

```gdscript
signal no_perk_available()
signal hunt_mark_applied(enemy: Node2D)
signal hunt_mark_cleared(enemy: Node2D)
```

> `hunt_mark_*` 是 Task 11 用到的，本 Task 一起加避免后续改 EventBus 又 commit 一次。

- [ ] **Step 6.2：删除旧测试 + 写新失败测试**

```bash
rm tests/unit/test_perk_manager.gd tests/unit/test_perk_manager.gd.uid
```

创建 `tests/unit/test_perk_manager_category.gd`：

```gdscript
extends GutTest

var _perks_by_category: Dictionary = {}

func before_each() -> void:
    _perks_by_category = {}
    # 伪造 4 类各 3 个 PerkData（测试用 in-memory 资源，不依赖 .tres）
    var categories := [
        PerkData.Category.RANGER_GUST,
        PerkData.Category.RANGER_RAIN,
        PerkData.Category.RANGER_MARK,
        PerkData.Category.RANGER_UTILITY,
    ]
    var pool: Array[PerkData] = []
    for cat in categories:
        for i in range(3):
            var p := PerkData.new()
            p.id = "cat%d_perk%d" % [cat, i]
            p.display_name = p.id
            p.category = cat
            p.max_level = 2
            p.effect_type = PerkData.EffectType.HP_PERCENT
            p.effect_value = 0.05
            pool.append(p)
    PerkManager.set_pool_for_test(pool)
    PerkManager.reset()

func after_all() -> void:
    PerkManager.reset()

func test_draw_three_spans_three_categories():
    var offer: Array = PerkManager.draw_three_for_test()
    assert_eq(offer.size(), 3, "应抽 3 个")
    var cats: Array = []
    for p in offer:
        assert_false(p.category in cats, "抽的 perk 应来自不同 category")
        cats.append(p.category)

func test_max_level_filters_exhausted_perks():
    # 手动把 RANGER_GUST 类的 3 个 perk 全部升到满级
    for p in PerkManager.get_pool_for_test():
        if p.category == PerkData.Category.RANGER_GUST:
            PerkManager.force_level_for_test(p.id, p.max_level)
    var offer: Array = PerkManager.draw_three_for_test()
    for p in offer:
        assert_ne(p.category, PerkData.Category.RANGER_GUST, "满级类别不应被抽到")

func test_reset_clears_perk_levels():
    for p in PerkManager.get_pool_for_test():
        PerkManager.force_level_for_test(p.id, 1)
    PerkManager.reset()
    for p in PerkManager.get_pool_for_test():
        assert_eq(PerkManager.get_perk_level(p.id), 0, "reset 后等级应为 0")

func test_all_exhausted_emits_no_perk_available():
    for p in PerkManager.get_pool_for_test():
        PerkManager.force_level_for_test(p.id, p.max_level)
    watch_signals(EventBus)
    PerkManager.trigger_offer_for_test()
    assert_signal_emitted(EventBus, "no_perk_available")
```

- [ ] **Step 6.3：改写 `scripts/core/perk_manager.gd`**

完全替换为：

```gdscript
extends Node
## Perk 管理器 — 按当前角色的 CharacterData.perk_pool 加载
## 升级触发 → 4 类随机选 3 类各抽 1 未满级 perk → 发 perk_offered → 玩家选 → 应用 → emit perk_applied
## 支持 max_level 限流；全部满级时 emit no_perk_available 让 UI 走空流程

var _all_perks: Array[PerkData] = []
var _current_offer: Array[PerkData] = []
var _pending_levelups: int = 0
var _perk_levels: Dictionary = {}  # perk_id -> int (当前堆叠)

func _ready() -> void:
    EventBus.player_level_changed.connect(_on_player_level_changed)
    # 延迟到 PlayerState 就绪后加载（main 场景 _ready 会 refresh）
    call_deferred("refresh_pool_for_current_character")

func refresh_pool_for_current_character() -> void:
    _all_perks.clear()
    var char_data: CharacterData = GameConfig.characters.get(PlayerState.current_character)
    if char_data and char_data.perk_pool:
        for p in char_data.perk_pool:
            if p:
                _all_perks.append(p)

func _on_player_level_changed(_new_level: int) -> void:
    _pending_levelups += 1
    if _current_offer.is_empty():
        _offer_next()

func _offer_next() -> void:
    if _pending_levelups <= 0:
        return
    _pending_levelups -= 1
    var drawn: Array[PerkData] = _draw_three()
    if drawn.is_empty():
        EventBus.no_perk_available.emit()
        return
    _current_offer = drawn
    EventBus.perk_offered.emit(_current_offer)

func _draw_three() -> Array[PerkData]:
    var by_cat: Dictionary = {}  # Category -> Array[PerkData]（过滤未满级）
    for p in _all_perks:
        if get_perk_level(p.id) >= p.max_level:
            continue
        if not by_cat.has(p.category):
            by_cat[p.category] = []
        by_cat[p.category].append(p)
    var cats: Array = by_cat.keys()
    if cats.is_empty():
        return []
    cats.shuffle()
    var picked: Array[PerkData] = []
    for cat in cats:
        if picked.size() >= 3:
            break
        var arr: Array = by_cat[cat]
        if arr.is_empty():
            continue
        picked.append(arr[randi() % arr.size()])
    return picked

func select_perk(perk_id: String) -> bool:
    var picked: PerkData = null
    for p in _current_offer:
        if p.id == perk_id:
            picked = p
            break
    if picked == null:
        return false
    _apply_effect(picked)
    _perk_levels[perk_id] = get_perk_level(perk_id) + 1
    EventBus.perk_selected.emit(perk_id)
    EventBus.perk_applied.emit(perk_id)
    _current_offer = []
    if _pending_levelups > 0:
        _offer_next()
    return true

func _apply_effect(perk: PerkData) -> void:
    match perk.effect_type:
        PerkData.EffectType.HP_PERCENT:
            _add(Enums.Stat.HP_BONUS_PERCENT, perk.effect_value)
        PerkData.EffectType.MOVE_SPEED_PERCENT:
            _add(Enums.Stat.MOVE_SPEED_BONUS_PERCENT, perk.effect_value)
        PerkData.EffectType.DAMAGE_PERCENT:
            _add(Enums.Stat.DAMAGE_BONUS_PERCENT, perk.effect_value)
        PerkData.EffectType.ATTACK_SPEED_PERCENT:
            _add(Enums.Stat.ATTACK_SPEED_BONUS_PERCENT, perk.effect_value)
        PerkData.EffectType.PICKUP_RADIUS_PERCENT:
            _add(Enums.Stat.PICKUP_RADIUS_BONUS_PERCENT, perk.effect_value)
        PerkData.EffectType.COIN_DROP_PERCENT:
            _add(Enums.Stat.COIN_DROP_BONUS_PERCENT, perk.effect_value)
        PerkData.EffectType.EXP_GAIN_PERCENT:
            _add(Enums.Stat.EXP_GAIN_BONUS_PERCENT, perk.effect_value)
        PerkData.EffectType.ABILITY_CUSTOM:
            pass  # 能力组件按 id 自己识别
        _:
            push_warning("未知 perk effect_type: " + str(perk.effect_type))

func _add(stat_key: String, delta: float) -> void:
    var cur: float = PlayerState.player_stats.get(stat_key, 0.0)
    PlayerState.player_stats[stat_key] = cur + delta

func reset() -> void:
    _current_offer = []
    _pending_levelups = 0
    _perk_levels.clear()

func has_pending() -> bool:
    return not _current_offer.is_empty() or _pending_levelups > 0

func get_current_offer() -> Array[PerkData]:
    return _current_offer.duplicate()

func get_perk_level(perk_id: String) -> int:
    return _perk_levels.get(perk_id, 0)

# ===== 测试辅助 =====

func set_pool_for_test(pool: Array[PerkData]) -> void:
    _all_perks = pool.duplicate()

func get_pool_for_test() -> Array[PerkData]:
    return _all_perks

func force_level_for_test(perk_id: String, level: int) -> void:
    _perk_levels[perk_id] = level

func draw_three_for_test() -> Array[PerkData]:
    return _draw_three()

func trigger_offer_for_test() -> void:
    _pending_levelups = maxi(_pending_levelups, 1)
    _offer_next()
```

- [ ] **Step 6.4：运行测试确认通过**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_perk_manager_category.gd -gexit 2>&1 | tail -20
```

预期：PASS。

- [ ] **Step 6.5：Commit**

```bash
git add -u
git add tests/unit/test_perk_manager_category.gd tests/unit/test_perk_manager_category.gd.uid
git commit -m "refactor(#2): PerkManager 改造 — 4 类分组抽取 + max_level 限流 + 专属 pool"
```

---

## Task 7：创建 4 个能力 Resource 类

**Files:**
- Create: `scripts/resources/hero_abilities/auto_attack_data.gd`
- Create: `scripts/resources/hero_abilities/gust_arrow_data.gd`
- Create: `scripts/resources/hero_abilities/arrow_rain_data.gd`
- Create: `scripts/resources/hero_abilities/hunt_mark_data.gd`

- [ ] **Step 7.1：新建目录 + `auto_attack_data.gd`**

```bash
mkdir -p scripts/resources/hero_abilities resources/hero_abilities/ranger
```

`scripts/resources/hero_abilities/auto_attack_data.gd`：

```gdscript
class_name AutoAttackData
extends Resource

## 基础自动攻击数值
@export var attack_range: float = 240.0        # 射程（px）
@export var cooldown: float = 0.4               # 秒/发，受 ATTACK_SPEED_BONUS_PERCENT 缩短
@export var damage: float = 10.0                # 基础伤害
@export var projectile_scene: PackedScene = null
```

- [ ] **Step 7.2：`gust_arrow_data.gd`**

```gdscript
class_name GustArrowData
extends Resource

## 疾风箭数值
@export var trigger_distance: float = 160.0    # 累计移动 px 后触发
@export var damage: float = 25.0
@export var pierce_count: int = 3
@export var slow_ratio: float = 0.4             # 减速比例
@export var slow_duration: float = 1.0
@export var projectile_scene: PackedScene = null
```

- [ ] **Step 7.3：`arrow_rain_data.gd`**

```gdscript
class_name ArrowRainData
extends Resource

## 箭雨数值
@export var cooldown: float = 10.0
@export var radius: float = 96.0                # AoE 半径
@export var duration: float = 2.0
@export var tick_interval: float = 0.3
@export var damage_per_tick: float = 8.0
@export var effect_scene: PackedScene = null
```

- [ ] **Step 7.4：`hunt_mark_data.gd`**

```gdscript
class_name HuntMarkData
extends Resource

## 猎杀标记数值
@export var charge_per_kill: float = 1.0
@export var charge_per_elite: float = 5.0       # 精英倍率（叠在 charge_per_kill 上绝对值）
@export var charge_required: float = 35.0
@export var mark_duration: float = 8.0
@export var damage_multiplier: float = 2.0
@export var kill_refund_ratio: float = 0.5
```

- [ ] **Step 7.5：验证资源类加载**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 | tail -5
```

预期：无 Parse Error。

- [ ] **Step 7.6：Commit**

```bash
git add scripts/resources/hero_abilities/
git commit -m "feat(#2): 新增 4 个能力 Resource 类 (AutoAttack/GustArrow/ArrowRain/HuntMark)"
```

---

## Task 8：AutoAttackComponent（基础自动攻击组件）

**Files:**
- Create: `scripts/components/hero_abilities/auto_attack_component.gd`
- Create: `scripts/components/hero_abilities/auto_attack_component.tscn`
- Create: `tests/unit/test_auto_attack_component.gd`

- [ ] **Step 8.1：写失败测试 `tests/unit/test_auto_attack_component.gd`**

```gdscript
extends GutTest

var _component: AutoAttackComponent = null
var _host: Node2D = null
var _data: AutoAttackData = null

func before_each() -> void:
    _data = AutoAttackData.new()
    _data.attack_range = 200.0
    _data.cooldown = 0.5
    _data.damage = 10.0

    _host = Node2D.new()
    _host.add_to_group(Enums.Group.PLAYER)
    add_child_autofree(_host)

    var holder := Node.new()
    _host.add_child(holder)
    _component = AutoAttackComponent.new()
    _component.data = _data
    holder.add_child(_component)

func test_target_nullable_no_spawn():
    var spawned := [0]
    _component.projectile_spawned.connect(func(_p): spawned[0] += 1)
    _component.tick(10.0)
    assert_eq(spawned[0], 0, "无目标不 spawn")

func test_cooldown_gates_spawn():
    # 注入一个假目标
    _component.set_debug_target(_host)  # 指向自己作为占位
    var spawned := [0]
    _component.projectile_spawned.connect(func(_p): spawned[0] += 1)
    # 第 1 次 tick 达到 cooldown 应触发
    _component.tick(_data.cooldown + 0.01)
    assert_eq(spawned[0], 1, "cooldown 到期应 spawn 1 次")
    # 第 2 次 tick 未达 cooldown，不应再 spawn
    _component.tick(0.1)
    assert_eq(spawned[0], 1, "未到 cooldown 不 spawn")

func test_attack_speed_bonus_shortens_cooldown():
    PlayerState.player_stats[Enums.Stat.ATTACK_SPEED_BONUS_PERCENT] = 1.0  # +100% = 2x 速度
    _component.set_debug_target(_host)
    _component._recalculate_params()
    var spawned := [0]
    _component.projectile_spawned.connect(func(_p): spawned[0] += 1)
    _component.tick(_data.cooldown * 0.5 + 0.01)  # 应已到有效冷却
    assert_eq(spawned[0], 1, "ATTACK_SPEED_BONUS_PERCENT=1.0 时 cooldown 减半应触发")
    PlayerState.player_stats[Enums.Stat.ATTACK_SPEED_BONUS_PERCENT] = 0.0
```

- [ ] **Step 8.2：运行测试确认失败**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_auto_attack_component.gd -gexit 2>&1 | tail -15
```

预期：FAIL（AutoAttackComponent 未定义）。

- [ ] **Step 8.3：实现 `scripts/components/hero_abilities/auto_attack_component.gd`**

```gdscript
class_name AutoAttackComponent
extends Node

## 基础自动攻击：自动寻敌 + 冷却触发 + spawn 投射物

signal projectile_spawned(proj: Node2D)

@export var data: AutoAttackData = null

var _host: Node2D = null
var _target_finder: TargetFinderComponent = null
var _cooldown_timer: float = 0.0
var _current_damage: float = 0.0
var _current_cooldown: float = 0.5
var _current_range: float = 240.0
var _debug_target: Node2D = null  # 测试注入

func _ready() -> void:
    _host = _resolve_host()
    if _host == null or data == null:
        push_error("AutoAttackComponent: _host 或 data 缺失，禁用")
        set_physics_process(false)
        return
    _setup_target_finder()
    _recalculate_params()
    EventBus.perk_applied.connect(_on_perk_applied)

func _resolve_host() -> Node2D:
    var p: Node = get_parent()
    while p:
        if p is Node2D and p.is_in_group(Enums.Group.PLAYER):
            return p
        p = p.get_parent()
    # 测试场景兜底
    if get_tree() and get_tree().current_scene:
        for n in get_tree().current_scene.get_children():
            if n is Node2D:
                return n
    return null

func _setup_target_finder() -> void:
    _target_finder = TargetFinderComponent.new()
    _target_finder.name = "_AutoAttackFinder"
    _target_finder.detection_radius = _current_range
    _target_finder.target_group = Enums.Group.ENEMIES
    add_child(_target_finder)

func _physics_process(delta: float) -> void:
    tick(delta)

func tick(delta: float) -> void:
    _cooldown_timer -= delta
    if _cooldown_timer > 0.0:
        return
    var tgt: Node2D = _get_target()
    if tgt == null:
        return
    _spawn_projectile(tgt)
    _cooldown_timer = _current_cooldown

func _get_target() -> Node2D:
    if _debug_target and is_instance_valid(_debug_target):
        return _debug_target
    if _target_finder:
        return _target_finder.get_target()
    return null

func set_debug_target(t: Node2D) -> void:
    _debug_target = t

func _spawn_projectile(target: Node2D) -> void:
    if data.projectile_scene == null:
        projectile_spawned.emit(null)  # 测试环境场景为空时也发信号
        return
    var proj: Node2D = data.projectile_scene.instantiate()
    var container: Node = SceneFactory.get_projectile_layer() if SceneFactory else null
    if container == null:
        container = _host.get_parent()  # 兜底
    proj.global_position = _host.global_position
    var dir: Vector2 = (target.global_position - _host.global_position).normalized()
    if proj.has_method("setup"):
        proj.setup(null, _current_damage, _host, dir)
    container.add_child(proj)
    projectile_spawned.emit(proj)

func _recalculate_params() -> void:
    if data == null:
        return
    var dmg_bonus: float = PlayerState.player_stats.get(Enums.Stat.DAMAGE_BONUS_PERCENT, 0.0)
    var spd_bonus: float = PlayerState.player_stats.get(Enums.Stat.ATTACK_SPEED_BONUS_PERCENT, 0.0)
    _current_damage = data.damage * (1.0 + dmg_bonus)
    _current_cooldown = data.cooldown / max(1.0 + spd_bonus, 0.01)
    _current_range = data.attack_range
    if _target_finder:
        _target_finder.detection_radius = _current_range

func _on_perk_applied(_perk_id: String) -> void:
    _recalculate_params()
```

> 注意：`_spawn_projectile` 里 `proj.setup(null, ...)` 的第一个参数 `null` 占位 ProjectileData，需要 Task 12 提供 ranger_arrow 场景或复用 arrow.tscn 时适配。`Projectile.setup` 的签名参见 `scripts/entities/projectiles/projectile.gd` 现有实现。

- [ ] **Step 8.4：创建 `auto_attack_component.tscn`**

用 Godot 编辑器创建或手写：

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/components/hero_abilities/auto_attack_component.gd" id="1"]
[node name="AutoAttackComponent" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 8.5：运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_auto_attack_component.gd -gexit 2>&1 | tail -15
```

预期：PASS。

- [ ] **Step 8.6：Commit**

```bash
git add scripts/components/hero_abilities/auto_attack_component.gd scripts/components/hero_abilities/auto_attack_component.gd.uid scripts/components/hero_abilities/auto_attack_component.tscn tests/unit/test_auto_attack_component.gd tests/unit/test_auto_attack_component.gd.uid
git commit -m "feat(#2): AutoAttackComponent 基础自动攻击组件"
```

---

## Task 9：GustArrowSkillComponent（疾风箭）

**Files:**
- Create: `scripts/components/hero_abilities/gust_arrow_skill_component.gd`
- Create: `scripts/components/hero_abilities/gust_arrow_skill_component.tscn`
- Create: `scenes/entities/projectiles/gust_arrow.tscn`（若复用 arrow.tscn 则跳过）
- Create: `tests/unit/test_gust_arrow_component.gd`

- [ ] **Step 9.1：写失败测试**

```gdscript
extends GutTest

var _c: GustArrowSkillComponent = null
var _host: Node2D = null
var _data: GustArrowData = null

func before_each() -> void:
    _data = GustArrowData.new()
    _data.trigger_distance = 100.0
    _data.damage = 20.0
    _data.pierce_count = 2

    _host = Node2D.new()
    _host.add_to_group(Enums.Group.PLAYER)
    add_child_autofree(_host)

    var holder := Node.new()
    _host.add_child(holder)
    _c = GustArrowSkillComponent.new()
    _c.data = _data
    holder.add_child(_c)

func test_static_no_trigger():
    var count := [0]
    _c.gust_triggered.connect(func(_d, _p): count[0] += 1)
    _host.set("velocity", Vector2.ZERO)
    _c._test_set_velocity(Vector2.ZERO)
    _c._test_accumulate_distance(_data.trigger_distance + 10.0)
    _c._test_tick()
    assert_eq(count[0], 0, "静止时不触发")

func test_moving_triggers_after_distance():
    var count := [0]
    _c.gust_triggered.connect(func(_d, _p): count[0] += 1)
    _c._test_set_velocity(Vector2(100, 0))
    _c._test_accumulate_distance(_data.trigger_distance + 10.0)
    _c._test_tick()
    assert_eq(count[0], 1, "移动 + 累积距离达阈值应触发")

func test_overflow_preserved_across_triggers():
    var count := [0]
    _c.gust_triggered.connect(func(_d, _p): count[0] += 1)
    _c._test_set_velocity(Vector2(100, 0))
    _c._test_accumulate_distance(_data.trigger_distance * 2 + 10.0)
    _c._test_tick()
    # 2 倍距离应触发 2 次（溢出累计）
    assert_eq(count[0], 2, "双倍距离触发 2 次")

func test_fanshot_spawns_three():
    _c._test_set_velocity(Vector2(100, 0))
    _c.set_fanshot_for_test(true)
    var count := [0]
    _c.gust_triggered.connect(func(_d, _p): count[0] += 1)
    _c._test_accumulate_distance(_data.trigger_distance + 1.0)
    _c._test_tick()
    assert_eq(count[0], 3, "扇形开启后每次触发应发 3 发")
```

- [ ] **Step 9.2：运行测试确认失败**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_gust_arrow_component.gd -gexit 2>&1 | tail -15
```

预期：FAIL（未定义）。

- [ ] **Step 9.3：实现组件**

`scripts/components/hero_abilities/gust_arrow_skill_component.gd`：

```gdscript
class_name GustArrowSkillComponent
extends Node

## 疾风箭：移动累积距离触发，朝移动方向射穿透箭

signal gust_triggered(dir: Vector2, proj: Node2D)

const FAN_ANGLE_DEG: float = 15.0

@export var data: GustArrowData = null

var _host: Node2D = null
var _accum: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _current_trigger_distance: float = 160.0
var _current_damage: float = 0.0
var _current_pierce: int = 3
var _has_fanshot: bool = false
var _has_bounce: bool = false
var _test_velocity: Vector2 = Vector2.ZERO
var _test_mode: bool = false

func _ready() -> void:
    _host = _resolve_host()
    if _host == null or data == null:
        push_error("GustArrowSkillComponent: _host 或 data 缺失，禁用")
        set_physics_process(false)
        return
    _last_pos = _host.global_position
    _recalculate_params()
    EventBus.perk_applied.connect(_on_perk_applied)

func _resolve_host() -> Node2D:
    var p: Node = get_parent()
    while p:
        if p is Node2D and p.is_in_group(Enums.Group.PLAYER):
            return p
        p = p.get_parent()
    return null

func _physics_process(_delta: float) -> void:
    if _test_mode:
        return
    _accum += _host.global_position.distance_to(_last_pos)
    _last_pos = _host.global_position
    _try_trigger(_get_current_velocity())

func _try_trigger(vel: Vector2) -> void:
    while _accum >= _current_trigger_distance:
        _accum -= _current_trigger_distance
        if vel == Vector2.ZERO:
            # 静止时不触发，但保留累计等再跑就放
            _accum = _current_trigger_distance  # 卡在阈值等下一帧
            return
        var dir: Vector2 = vel.normalized()
        _spawn_arrow(dir)
        if _has_fanshot:
            _spawn_arrow(dir.rotated(deg_to_rad(FAN_ANGLE_DEG)))
            _spawn_arrow(dir.rotated(deg_to_rad(-FAN_ANGLE_DEG)))

func _spawn_arrow(dir: Vector2) -> void:
    if data.projectile_scene == null:
        gust_triggered.emit(dir, null)
        return
    var proj: Node2D = data.projectile_scene.instantiate()
    var container: Node = SceneFactory.get_projectile_layer() if SceneFactory else null
    if container == null:
        container = _host.get_parent()
    proj.global_position = _host.global_position
    if proj.has_method("setup"):
        proj.setup(null, _current_damage, _host, dir)
    # 运行时配置 pierce
    var pierce = proj.get_node_or_null("PierceComponent")
    if pierce:
        pierce.pierce_count = _current_pierce
    if _has_bounce and proj.get_node_or_null("BounceOnHitComponent") == null:
        # 动态添加 bounce
        var bounce = load("res://scripts/components/bounce_on_hit_component.gd").new()
        proj.add_child(bounce)
    container.add_child(proj)
    gust_triggered.emit(dir, proj)

func _get_current_velocity() -> Vector2:
    if _test_mode:
        return _test_velocity
    if _host and _host.has_method("get") and _host.get("velocity") is Vector2:
        return _host.get("velocity")
    return Vector2.ZERO

func _recalculate_params() -> void:
    if data == null:
        return
    _current_damage = data.damage * (1.0 + PlayerState.player_stats.get(Enums.Stat.DAMAGE_BONUS_PERCENT, 0.0))
    _current_pierce = data.pierce_count
    var interval_mod: float = 1.0
    var lvl_interval: int = PerkManager.get_perk_level("gust_interval_down")
    interval_mod = maxf(1.0 - 0.2 * lvl_interval, 0.2)
    _current_pierce += PerkManager.get_perk_level("gust_pierce_plus")
    _has_fanshot = PerkManager.get_perk_level("gust_fanshot") > 0
    _has_bounce = PerkManager.get_perk_level("gust_bounce") > 0
    _current_trigger_distance = data.trigger_distance * interval_mod

func _on_perk_applied(_perk_id: String) -> void:
    _recalculate_params()

# ===== 测试辅助 =====

func _test_set_velocity(v: Vector2) -> void:
    _test_mode = true
    _test_velocity = v

func _test_accumulate_distance(d: float) -> void:
    _accum += d

func _test_tick() -> void:
    _try_trigger(_get_current_velocity())

func set_fanshot_for_test(on: bool) -> void:
    _has_fanshot = on
```

- [ ] **Step 9.4：创建 `gust_arrow.tscn` 投射物场景**

查看现有 `scenes/entities/projectiles/arrow.tscn` 的结构，复制一份命名 `gust_arrow.tscn`，确认包含：
- `Projectile`（根节点，继承 `projectile.gd`）
- `LinearMovementComponent`
- `PierceComponent`（子节点）
- `SlowOnHitComponent`（新加，若 arrow.tscn 没有）
- `Hitbox`

若 arrow.tscn 已含 LinearMovement + Pierce + SlowOnHit，可以直接复用 arrow.tscn 在 `gust_arrow.tres` 的 `projectile_scene` 指向它。

为简化，先**复用 arrow.tscn**（Task 12 填 `gust_arrow.tres` 时指向 `res://scenes/entities/projectiles/arrow.tscn`）；若玩起来视觉冲突（疾风箭和基础攻击同视觉）再考虑新建 scene。

- [ ] **Step 9.5：创建 `.tscn` 组件场景**

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/components/hero_abilities/gust_arrow_skill_component.gd" id="1"]
[node name="GustArrowSkillComponent" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 9.6：运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_gust_arrow_component.gd -gexit 2>&1 | tail -15
```

预期：PASS。

- [ ] **Step 9.7：Commit**

```bash
git add scripts/components/hero_abilities/gust_arrow_skill_component.gd scripts/components/hero_abilities/gust_arrow_skill_component.gd.uid scripts/components/hero_abilities/gust_arrow_skill_component.tscn tests/unit/test_gust_arrow_component.gd tests/unit/test_gust_arrow_component.gd.uid
git commit -m "feat(#2): GustArrowSkillComponent 疾风箭组件"
```

---

## Task 10：ArrowRainSkillComponent（箭雨）

**Files:**
- Create: `scripts/components/hero_abilities/arrow_rain_skill_component.gd`
- Create: `scripts/components/hero_abilities/arrow_rain_skill_component.tscn`
- Create: `scenes/entities/effects/arrow_rain_effect.tscn`
- Create: `scripts/entities/effects/arrow_rain_effect.gd`
- Create: `tests/unit/test_arrow_rain_component.gd`

- [ ] **Step 10.1：写失败测试**

```gdscript
extends GutTest

var _c: ArrowRainSkillComponent = null
var _host: Node2D = null
var _data: ArrowRainData = null

func before_each() -> void:
    _data = ArrowRainData.new()
    _data.cooldown = 2.0
    _data.radius = 50.0
    _data.duration = 1.0
    _data.damage_per_tick = 5.0

    _host = Node2D.new()
    _host.add_to_group(Enums.Group.PLAYER)
    add_child_autofree(_host)

    var holder := Node.new()
    _host.add_child(holder)
    _c = ArrowRainSkillComponent.new()
    _c.data = _data
    holder.add_child(_c)

func test_cooldown_not_reached_no_spawn():
    var count := [0]
    _c.rain_spawned.connect(func(_pos): count[0] += 1)
    _c._test_tick(0.5)
    assert_eq(count[0], 0, "未到 cooldown 不 spawn")

func test_cooldown_without_enemies_holds_full_charge():
    _c._test_tick(_data.cooldown + 0.1)
    # 场上无敌人，CD 不应重置
    assert_true(_c._test_is_ready(), "无敌人时 CD 保持 ready 态")

func test_cooldown_with_enemies_spawns():
    # 创建一个敌人占位
    var e := Node2D.new()
    e.add_to_group(Enums.Group.ENEMIES)
    e.global_position = Vector2(100, 0)
    add_child_autofree(e)

    var count := [0]
    _c.rain_spawned.connect(func(_pos): count[0] += 1)
    _c._test_tick(_data.cooldown + 0.1)
    assert_eq(count[0], 1, "CD 到 + 有敌人时 spawn 1 次")
```

- [ ] **Step 10.2：运行确认失败**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_arrow_rain_component.gd -gexit 2>&1 | tail -15
```

预期：FAIL。

- [ ] **Step 10.3：实现组件**

```gdscript
class_name ArrowRainSkillComponent
extends Node

signal rain_spawned(position: Vector2)

@export var data: ArrowRainData = null

var _host: Node2D = null
var _cooldown_timer: float = 0.0
var _current_cooldown: float = 10.0
var _current_radius: float = 96.0
var _has_knockback: bool = false
var _has_dot_field: bool = false

func _ready() -> void:
    _host = _resolve_host()
    if _host == null or data == null:
        set_physics_process(false)
        return
    _recalculate_params()
    _cooldown_timer = _current_cooldown  # 开局进入冷却态等首次到期
    EventBus.perk_applied.connect(_on_perk_applied)

func _resolve_host() -> Node2D:
    var p: Node = get_parent()
    while p:
        if p is Node2D and p.is_in_group(Enums.Group.PLAYER):
            return p
        p = p.get_parent()
    return null

func _physics_process(delta: float) -> void:
    _test_tick(delta)

func _test_tick(delta: float) -> void:
    if _cooldown_timer > 0.0:
        _cooldown_timer -= delta
        if _cooldown_timer > 0.0:
            return
    # CD 到期
    var tgt: Node2D = _find_nearest_enemy()
    if tgt == null:
        _cooldown_timer = 0.0  # 保持 ready
        return
    _spawn_rain(tgt.global_position)
    _cooldown_timer = _current_cooldown

func _test_is_ready() -> bool:
    return _cooldown_timer <= 0.0

func _find_nearest_enemy() -> Node2D:
    var enemies: Array = get_tree().get_nodes_in_group(Enums.Group.ENEMIES) if get_tree() else []
    var nearest: Node2D = null
    var best_dist: float = INF
    for e in enemies:
        if not (e is Node2D):
            continue
        var d: float = _host.global_position.distance_squared_to(e.global_position)
        if d < best_dist:
            best_dist = d
            nearest = e
    return nearest

func _spawn_rain(pos: Vector2) -> void:
    if data.effect_scene == null:
        rain_spawned.emit(pos)
        return
    var fx: Node2D = data.effect_scene.instantiate()
    var container: Node = SceneFactory.get_projectile_layer() if SceneFactory else _host.get_parent()
    fx.global_position = pos
    if fx.has_method("setup"):
        fx.setup(data, _current_radius, _has_knockback, _has_dot_field)
    container.add_child(fx)
    rain_spawned.emit(pos)

func _recalculate_params() -> void:
    if data == null:
        return
    var radius_mod: float = 1.0
    var cd_mod: float = 1.0
    # PerkManager 是 Autoload，全局可用
    if true:
        radius_mod = 1.0 + 0.2 * PerkManager.get_perk_level("rain_radius")
        cd_mod = maxf(1.0 - 0.15 * PerkManager.get_perk_level("rain_cooldown"), 0.3)
        _has_knockback = PerkManager.get_perk_level("rain_knockback") > 0
        _has_dot_field = PerkManager.get_perk_level("rain_dot_field") > 0
    _current_radius = data.radius * radius_mod
    _current_cooldown = data.cooldown * cd_mod

func _on_perk_applied(_perk_id: String) -> void:
    _recalculate_params()
```

- [ ] **Step 10.4：实现 `arrow_rain_effect.gd` + `.tscn`**

`scripts/entities/effects/arrow_rain_effect.gd`：

```gdscript
class_name ArrowRainEffect
extends Node2D

## AoE 场景：Timer + Area2D，持续 duration 秒每 tick_interval 广发伤害

@onready var _area: Area2D = $Area2D
@onready var _shape: CollisionShape2D = $Area2D/CollisionShape2D

var _data: ArrowRainData = null
var _radius: float = 96.0
var _knockback: bool = false
var _dot_field: bool = false
var _tick_timer: float = 0.0
var _total_elapsed: float = 0.0
var _first_tick_done: bool = false

func setup(data: ArrowRainData, radius: float, knockback: bool, dot_field: bool) -> void:
    _data = data
    _radius = radius
    _knockback = knockback
    _dot_field = dot_field

func _ready() -> void:
    var circle := CircleShape2D.new()
    circle.radius = _radius
    _shape.shape = circle

func _physics_process(delta: float) -> void:
    if _data == null:
        return
    _total_elapsed += delta
    _tick_timer -= delta
    if _tick_timer <= 0.0:
        _do_tick()
        _tick_timer = _data.tick_interval
    if _total_elapsed >= _data.duration:
        queue_free()
        # TODO: _dot_field 启用时 spawn 持续 DoT 场景

func _do_tick() -> void:
    var targets: Array = _area.get_overlapping_bodies()
    var is_first := not _first_tick_done
    _first_tick_done = true
    for body in targets:
        if not body.is_in_group(Enums.Group.ENEMIES):
            continue
        # 通过 HealthComponent 直接扣血（AoE 无投射物）
        var hc = body.get_node_or_null("HealthComponent")
        if hc:
            hc.take_damage_no_sparks(_data.damage_per_tick)
        if _knockback and is_first:
            var kb = body.get_node_or_null("KnockbackHandler")
            if kb and kb.has_method("apply_knockback"):
                var dir: Vector2 = (body.global_position - global_position).normalized()
                kb.apply_knockback(dir * 200.0)
```

`scenes/entities/effects/arrow_rain_effect.tscn`（文本模式）：

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/entities/effects/arrow_rain_effect.gd" id="1"]

[node name="ArrowRainEffect" type="Node2D"]
script = ExtResource("1")

[node name="Area2D" type="Area2D" parent="."]
collision_layer = 0
collision_mask = 2  # Enemy layer

[node name="CollisionShape2D" type="CollisionShape2D" parent="Area2D"]
```

- [ ] **Step 10.5：创建 `arrow_rain_skill_component.tscn`**

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/components/hero_abilities/arrow_rain_skill_component.gd" id="1"]
[node name="ArrowRainSkillComponent" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 10.6：运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_arrow_rain_component.gd -gexit 2>&1 | tail -15
```

预期：PASS。

- [ ] **Step 10.7：Commit**

```bash
git add -A scripts/components/hero_abilities/arrow_rain_skill_component.gd scripts/components/hero_abilities/arrow_rain_skill_component.tscn scripts/entities/effects/arrow_rain_effect.gd scenes/entities/effects/arrow_rain_effect.tscn tests/unit/test_arrow_rain_component.gd
git commit -m "feat(#2): ArrowRainSkillComponent 箭雨组件 + AoE 效果场景"
```

---

## Task 11：HuntMarkSkillComponent（猎杀标记）

**Files:**
- Create: `scripts/components/hero_abilities/hunt_mark_skill_component.gd`
- Create: `scripts/components/hero_abilities/hunt_mark_skill_component.tscn`
- Create: `scenes/entities/effects/hunt_mark_indicator.tscn` + `scripts/entities/effects/hunt_mark_indicator.gd`
- Modify: `scripts/entities/enemy.gd`（`_apply_damage` 检查 `has_meta("hunt_marked")` 应用 2x 倍率）
- Create: `tests/unit/test_hunt_mark_component.gd`

- [ ] **Step 11.1：写失败测试**

```gdscript
extends GutTest

var _c: HuntMarkSkillComponent = null
var _host: Node2D = null
var _data: HuntMarkData = null

func before_each() -> void:
    _data = HuntMarkData.new()
    _data.charge_per_kill = 1.0
    _data.charge_per_elite = 5.0
    _data.charge_required = 5.0
    _data.mark_duration = 10.0
    _data.damage_multiplier = 2.0
    _data.kill_refund_ratio = 0.5

    _host = Node2D.new()
    _host.add_to_group(Enums.Group.PLAYER)
    add_child_autofree(_host)

    var holder := Node.new()
    _host.add_child(holder)
    _c = HuntMarkSkillComponent.new()
    _c.data = _data
    holder.add_child(_c)

func test_charge_per_normal_kill():
    _c._on_enemy_killed("normal", Vector2.ZERO, false)
    assert_almost_eq(_c.get_charge(), 1.0, 0.01)

func test_elite_multiplier():
    _c._on_enemy_killed("normal", Vector2.ZERO, true)
    assert_almost_eq(_c.get_charge(), 5.0, 0.01)

func test_full_charge_picks_highest_hp_enemy():
    var e1: Node2D = _spawn_enemy(Vector2(50, 0), 50.0)
    var e2: Node2D = _spawn_enemy(Vector2(150, 0), 200.0)
    for i in range(5):
        _c._on_enemy_killed("normal", Vector2.ZERO, false)
    assert_eq(_c.get_marked_target(), e2, "应锁定最高 HP 敌人")

func test_kill_refunds_charge():
    var e: Node2D = _spawn_enemy(Vector2(100, 0), 100.0)
    for i in range(5):
        _c._on_enemy_killed("normal", Vector2.ZERO, false)
    # 模拟 marked target 死亡
    e.queue_free()
    await get_tree().process_frame
    _c._on_marked_target_died(e)
    # 返还 0.5 * 5.0 = 2.5
    assert_almost_eq(_c.get_charge(), 2.5, 0.01)
    assert_null(_c.get_marked_target())

func _spawn_enemy(pos: Vector2, hp: float) -> Node2D:
    var e := Node2D.new()
    e.add_to_group(Enums.Group.ENEMIES)
    e.global_position = pos
    var hc := HealthComponent.new()
    hc.name = "HealthComponent"
    hc.initialize(hp)
    e.add_child(hc)
    add_child_autofree(e)
    return e
```

- [ ] **Step 11.2：实现组件 `hunt_mark_skill_component.gd`**

```gdscript
class_name HuntMarkSkillComponent
extends Node

@export var data: HuntMarkData = null

enum State { IDLE, MARKED }

var _host: Node2D = null
var _charge: float = 0.0
var _state: int = State.IDLE
var _marked_target: Node2D = null
var _mark_timer: float = 0.0
var _indicator: Node2D = null
var _has_chain: bool = false
var _has_self_damage: bool = false

func _ready() -> void:
    _host = _resolve_host()
    if _host == null or data == null:
        set_physics_process(false)
        return
    EventBus.enemy_killed.connect(_on_enemy_killed)
    EventBus.perk_applied.connect(_on_perk_applied)
    _recalculate_params()

func _resolve_host() -> Node2D:
    var p: Node = get_parent()
    while p:
        if p is Node2D and p.is_in_group(Enums.Group.PLAYER):
            return p
        p = p.get_parent()
    return null

func _physics_process(delta: float) -> void:
    if _state != State.MARKED:
        return
    _mark_timer -= delta
    if not is_instance_valid(_marked_target):
        _on_marked_target_died(null)
        return
    if _mark_timer <= 0.0:
        _clear_mark(false)

func _on_enemy_killed(enemy_type: String, _pos: Vector2, is_elite: bool) -> void:
    # 若击杀的是当前 marked target，走死亡流程
    if _state == State.MARKED and _marked_target and not is_instance_valid(_marked_target):
        _on_marked_target_died(null)
        return
    if _state == State.MARKED:
        return  # 已在标记态，不再充能
    var gain: float = data.charge_per_elite if is_elite else data.charge_per_kill
    var lvl: int = 0
    # PerkManager 是 Autoload，全局可用
    if true:
        lvl = PerkManager.get_perk_level("mark_charge_speed")
    gain *= (1.0 + 0.25 * lvl)
    _charge += gain
    if _charge >= data.charge_required:
        _activate_mark()

func _activate_mark() -> void:
    _charge = data.charge_required  # 封顶
    var tgt: Node2D = _find_highest_hp_enemy()
    if tgt == null:
        # 没敌人，等下次击杀或 enemy 出现再触发
        return
    _marked_target = tgt
    _state = State.MARKED
    _mark_timer = _current_duration()
    _marked_target.set_meta("hunt_marked", true)
    # TODO: spawn indicator scene
    EventBus.hunt_mark_applied.emit(_marked_target)
    if not _marked_target.tree_exited.is_connected(Callable(self, "_on_marked_target_died").bind(_marked_target)):
        _marked_target.tree_exited.connect(Callable(self, "_on_marked_target_died").bind(_marked_target), CONNECT_ONE_SHOT)

func _find_highest_hp_enemy() -> Node2D:
    var enemies: Array = get_tree().get_nodes_in_group(Enums.Group.ENEMIES) if get_tree() else []
    var best: Node2D = null
    var best_hp: float = -1.0
    for e in enemies:
        if not (e is Node2D):
            continue
        var hc = e.get_node_or_null("HealthComponent")
        if hc == null:
            continue
        if hc.current_hp > best_hp:
            best_hp = hc.current_hp
            best = e
    return best

func _on_marked_target_died(enemy: Node2D) -> void:
    if _state != State.MARKED:
        return
    var refund: float = data.charge_required * data.kill_refund_ratio
    _charge = refund
    _clear_mark_internals()
    if _has_chain:
        _activate_mark()
    else:
        _state = State.IDLE

func _clear_mark(emit_event: bool = true) -> void:
    _charge = 0.0
    _clear_mark_internals()
    _state = State.IDLE

func _clear_mark_internals() -> void:
    if is_instance_valid(_marked_target):
        _marked_target.set_meta("hunt_marked", null)
        EventBus.hunt_mark_cleared.emit(_marked_target)
    _marked_target = null
    if is_instance_valid(_indicator):
        _indicator.queue_free()
    _indicator = null

func _recalculate_params() -> void:
    # PerkManager 是 Autoload，全局可用
    if true:
        _has_chain = PerkManager.get_perk_level("mark_chain") > 0
        _has_self_damage = PerkManager.get_perk_level("mark_self_damage") > 0

func _current_duration() -> float:
    var bonus: int = 0
    # PerkManager 是 Autoload，全局可用
    if true:
        bonus = PerkManager.get_perk_level("mark_duration")
    return data.mark_duration + 2.0 * bonus

func _on_perk_applied(_perk_id: String) -> void:
    _recalculate_params()

# ===== 查询接口 =====

func get_charge() -> float:
    return _charge

func get_charge_required() -> float:
    return data.charge_required

func get_marked_target() -> Node2D:
    return _marked_target

func has_self_damage_perk() -> bool:
    return _has_self_damage
```

- [ ] **Step 11.3：修改 `scripts/entities/enemy.gd` — 伤害放大钩子**

在敌人的 `_apply_damage(amount: float, attacker: Node)` 或等效方法中，最前面加入：

```gdscript
if has_meta("hunt_marked") and get_meta("hunt_marked"):
    amount *= 2.0  # 写死，spec 里 HuntMarkData.damage_multiplier 的值，后续可查组件
```

> 更严谨的做法是查 HuntMarkSkillComponent 拿 `data.damage_multiplier`，但为避免反向依赖，这里先 hard-code 2.0 并在组件 data 保证一致。

- [ ] **Step 11.4：创建 indicator 场景（占位）**

`scripts/entities/effects/hunt_mark_indicator.gd`：

```gdscript
class_name HuntMarkIndicator
extends Node2D

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
    if _sprite.texture == null:
        var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
        # 纯红三角
        for y in range(16):
            for x in range(16):
                if y > x - 8 and y > -x + 8 and y < 14:
                    img.set_pixel(x, y, Color.RED)
        _sprite.texture = ImageTexture.create_from_image(img)
    position = Vector2(0, -40)
    var tween := create_tween().set_loops()
    tween.tween_property(_sprite, "modulate:a", 0.3, 0.5)
    tween.tween_property(_sprite, "modulate:a", 1.0, 0.5)
```

`scenes/entities/effects/hunt_mark_indicator.tscn`：

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/entities/effects/hunt_mark_indicator.gd" id="1"]

[node name="HuntMarkIndicator" type="Node2D"]
script = ExtResource("1")

[node name="Sprite2D" type="Sprite2D" parent="."]
```

- [ ] **Step 11.5：组件场景**

`hunt_mark_skill_component.tscn`：

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/components/hero_abilities/hunt_mark_skill_component.gd" id="1"]
[node name="HuntMarkSkillComponent" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 11.6：运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_hunt_mark_component.gd -gexit 2>&1 | tail -15
```

预期：PASS。

- [ ] **Step 11.7：Commit**

```bash
git add -A scripts/components/hero_abilities/hunt_mark_skill_component.gd scripts/components/hero_abilities/hunt_mark_skill_component.tscn scripts/entities/effects/hunt_mark_indicator.gd scenes/entities/effects/hunt_mark_indicator.tscn tests/unit/test_hunt_mark_component.gd scripts/entities/enemy.gd
git commit -m "feat(#2): HuntMarkSkillComponent 猎杀标记组件 + 敌人伤害放大"
```

---

## Task 12：游侠资源组装（ranger.tres + 4 能力 tres + 18 perk tres + 占位精灵）

**Files:**
- Create: `resources/characters/ranger.tres`
- Create: `resources/hero_abilities/ranger/auto_attack.tres`
- Create: `resources/hero_abilities/ranger/gust_arrow.tres`
- Create: `resources/hero_abilities/ranger/arrow_rain.tres`
- Create: `resources/hero_abilities/ranger/hunt_mark.tres`
- Create: `resources/exp/ranger_exp.tres`
- Create: `resources/perks/ranger/*.tres` × 18
- Create: `assets/characters/ranger/` 占位素材（sprite_frames.res 或暂时复用现有 SpriteFrames）
- Modify: `scripts/core/game_config.gd` — 加载 ranger + hero_abilities 目录

- [ ] **Step 12.1：创建 ExpConfig tres**

`resources/exp/ranger_exp.tres`：

```
[gd_resource type="Resource" script_class="ExpConfig" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/exp_config.gd" id="1"]

[resource]
script = ExtResource("1")
base_exp = 5.0
exp_exponent = 2.0
```

- [ ] **Step 12.2：创建 4 个能力 tres**

`resources/hero_abilities/ranger/auto_attack.tres`（假设 arrow.tscn 在 `res://scenes/entities/projectiles/arrow.tscn`）：

```
[gd_resource type="Resource" script_class="AutoAttackData" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/resources/hero_abilities/auto_attack_data.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/entities/projectiles/arrow.tscn" id="2"]

[resource]
script = ExtResource("1")
attack_range = 240.0
cooldown = 0.4
damage = 10.0
projectile_scene = ExtResource("2")
```

`resources/hero_abilities/ranger/gust_arrow.tres`：

```
[gd_resource type="Resource" script_class="GustArrowData" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/resources/hero_abilities/gust_arrow_data.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/entities/projectiles/arrow.tscn" id="2"]

[resource]
script = ExtResource("1")
trigger_distance = 160.0
damage = 25.0
pierce_count = 3
slow_ratio = 0.4
slow_duration = 1.0
projectile_scene = ExtResource("2")
```

`resources/hero_abilities/ranger/arrow_rain.tres`：

```
[gd_resource type="Resource" script_class="ArrowRainData" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/resources/hero_abilities/arrow_rain_data.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/entities/effects/arrow_rain_effect.tscn" id="2"]

[resource]
script = ExtResource("1")
cooldown = 10.0
radius = 96.0
duration = 2.0
tick_interval = 0.3
damage_per_tick = 8.0
effect_scene = ExtResource("2")
```

`resources/hero_abilities/ranger/hunt_mark.tres`：

```
[gd_resource type="Resource" script_class="HuntMarkData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/hero_abilities/hunt_mark_data.gd" id="1"]

[resource]
script = ExtResource("1")
charge_per_kill = 1.0
charge_per_elite = 5.0
charge_required = 35.0
mark_duration = 8.0
damage_multiplier = 2.0
kill_refund_ratio = 0.5
```

- [ ] **Step 12.3：创建 18 个游侠 perk tres**

使用以下模板，按下表填充 18 个文件。所有 perk 的 `effect_type` 用 `ABILITY_CUSTOM`（组件自己识别），除 `util_movespeed`（MOVE_SPEED_PERCENT）、`util_pickup_radius`（PICKUP_RADIUS_PERCENT）、`util_coin_drop`（COIN_DROP_PERCENT）用具体 effect_type。

**模板**（`resources/perks/ranger/<id>.tres`）：

```
[gd_resource type="Resource" script_class="PerkData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/perk_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "<id>"
display_name = "<display_name>"
description = "<description>"
icon_path = ""
effect_type = <effect_type int>  # ABILITY_CUSTOM = 7, MOVE_SPEED = 1, PICKUP = 4, COIN_DROP = 5
effect_value = <float>
max_level = <int>
category = <int>  # RANGER_GUST=1 RANGER_RAIN=2 RANGER_MARK=3 RANGER_UTILITY=4
```

> `effect_type` 枚举值：`HP_PERCENT=0, MOVE_SPEED_PERCENT=1, DAMAGE_PERCENT=2, ATTACK_SPEED_PERCENT=3, PICKUP_RADIUS_PERCENT=4, COIN_DROP_PERCENT=5, EXP_GAIN_PERCENT=6, ABILITY_CUSTOM=7`
> `category` 枚举值：`GENERIC=0, RANGER_GUST=1, RANGER_RAIN=2, RANGER_MARK=3, RANGER_UTILITY=4`

**18 条配置表**：

| id | display_name | effect_type | effect_value | max_level | category |
|---|---|---|---|---|---|
| gust_interval_down | 疾风·急促 | 7 | 0.2 | 5 | 1 |
| gust_fanshot | 疾风·扇形 | 7 | 0 | 1 | 1 |
| gust_pierce_plus | 疾风·贯穿 | 7 | 1 | 3 | 1 |
| gust_bounce | 疾风·弹射 | 7 | 0 | 1 | 1 |
| rain_radius | 箭雨·广覆 | 7 | 0.2 | 5 | 2 |
| rain_dot_field | 箭雨·焦土 | 7 | 0 | 1 | 2 |
| rain_knockback | 箭雨·冲击 | 7 | 0 | 1 | 2 |
| rain_cooldown | 箭雨·速射 | 7 | 0.15 | 5 | 2 |
| mark_charge_speed | 标记·速充 | 7 | 0.25 | 5 | 3 |
| mark_duration | 标记·延续 | 7 | 2 | 3 | 3 |
| mark_chain | 标记·连锁 | 7 | 0 | 1 | 3 |
| mark_self_damage | 标记·亲临 | 7 | 0.5 | 1 | 3 |
| util_movespeed | 疾行 | 1 | 0.1 | 5 | 4 |
| util_move_shield | 飘逸 | 7 | 0 | 2 | 4 |
| util_tower_heal | 塔庇护 | 7 | 0 | 1 | 4 |
| util_pickup_radius | 寻觅 | 4 | 0.15 | 5 | 4 |
| util_dodge | 闪避 | 7 | 0.1 | 1 | 4 |
| util_coin_drop | 贪婪 | 5 | 0.1 | 3 | 4 |

写脚本批量生成或手工 18 个。每个文件结构同模板。

- [ ] **Step 12.4：准备游侠占位精灵**

快速方案：复用 #1 留存的任一角色 SpriteFrames 作为占位。若 `assets/characters/` 已空（Task 2 删完），则：

```bash
mkdir -p assets/characters/ranger
```

创建占位 SpriteFrames `.tres`（在 Godot 编辑器新建 `SpriteFrames` 资源，添加 idle/walk 动画用任一现有 32px 纯色或占位图）：

手写 `assets/characters/ranger/sprite_frames.tres`：

```
[gd_resource type="SpriteFrames" format=3]

[resource]
animations = [{
"frames": [],
"loop": true,
"name": &"idle_down",
"speed": 5.0
}, {
"frames": [],
"loop": true,
"name": &"walk_down",
"speed": 5.0
}]
```

> 空 frames 导致精灵不显示，但游戏能跑。后续可用 Aseprite Wizard 生成正式素材。

准备 portrait 占位（32×32 纯绿）：

```bash
# 用 python 或 Godot 一次性生成；这里交给实施者用任意工具创建 32×32 png
# 最简：复制任一现有 png
cp assets/ui/icons/*.png assets/characters/ranger/portrait.png 2>/dev/null || touch assets/characters/ranger/portrait.png
```

- [ ] **Step 12.5：创建 ranger.tres**

`resources/characters/ranger.tres`：

```
[gd_resource type="Resource" script_class="CharacterData" load_steps=10 format=3]

[ext_resource type="Script" path="res://scripts/resources/character_data.gd" id="1"]
[ext_resource type="PackedScene" path="res://scripts/components/hero_abilities/auto_attack_component.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scripts/components/hero_abilities/gust_arrow_skill_component.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scripts/components/hero_abilities/arrow_rain_skill_component.tscn" id="4"]
[ext_resource type="PackedScene" path="res://scripts/components/hero_abilities/hunt_mark_skill_component.tscn" id="5"]
[ext_resource type="Resource" path="res://resources/exp/ranger_exp.tres" id="6"]
[ext_resource type="Resource" path="res://resources/perks/ranger/gust_interval_down.tres" id="7"]
[ext_resource type="Resource" path="res://resources/perks/ranger/gust_fanshot.tres" id="8"]
[ext_resource type="Resource" path="res://resources/perks/ranger/gust_pierce_plus.tres" id="9"]
[ext_resource type="Resource" path="res://resources/perks/ranger/gust_bounce.tres" id="10"]
[ext_resource type="Resource" path="res://resources/perks/ranger/rain_radius.tres" id="11"]
[ext_resource type="Resource" path="res://resources/perks/ranger/rain_dot_field.tres" id="12"]
[ext_resource type="Resource" path="res://resources/perks/ranger/rain_knockback.tres" id="13"]
[ext_resource type="Resource" path="res://resources/perks/ranger/rain_cooldown.tres" id="14"]
[ext_resource type="Resource" path="res://resources/perks/ranger/mark_charge_speed.tres" id="15"]
[ext_resource type="Resource" path="res://resources/perks/ranger/mark_duration.tres" id="16"]
[ext_resource type="Resource" path="res://resources/perks/ranger/mark_chain.tres" id="17"]
[ext_resource type="Resource" path="res://resources/perks/ranger/mark_self_damage.tres" id="18"]
[ext_resource type="Resource" path="res://resources/perks/ranger/util_movespeed.tres" id="19"]
[ext_resource type="Resource" path="res://resources/perks/ranger/util_move_shield.tres" id="20"]
[ext_resource type="Resource" path="res://resources/perks/ranger/util_tower_heal.tres" id="21"]
[ext_resource type="Resource" path="res://resources/perks/ranger/util_pickup_radius.tres" id="22"]
[ext_resource type="Resource" path="res://resources/perks/ranger/util_dodge.tres" id="23"]
[ext_resource type="Resource" path="res://resources/perks/ranger/util_coin_drop.tres" id="24"]

[resource]
script = ExtResource("1")
id = "ranger"
display_name = "游侠"
description = "机动远程，走位即是怪的路线"
max_hp = 500.0
speed = 144.0
starting_gold = 100
sprite_frames_path = "res://assets/characters/ranger/sprite_frames.tres"
portrait_path = "res://assets/characters/ranger/portrait.png"
sprite_pixel_size = 16.0
exp_config = ExtResource("6")
ability_scenes = [ExtResource("2"), ExtResource("3"), ExtResource("4"), ExtResource("5")]
perk_pool = [ExtResource("7"), ExtResource("8"), ExtResource("9"), ExtResource("10"), ExtResource("11"), ExtResource("12"), ExtResource("13"), ExtResource("14"), ExtResource("15"), ExtResource("16"), ExtResource("17"), ExtResource("18"), ExtResource("19"), ExtResource("20"), ExtResource("21"), ExtResource("22"), ExtResource("23"), ExtResource("24")]
```

- [ ] **Step 12.6：修改 `scripts/core/game_config.gd` — 加载 ranger**

找到 `characters: Dictionary` 加载逻辑（通常读 `resources/characters/*.tres`），确保只加载 `ranger.tres`（Task 2 删了其它）。

若 GameConfig 用硬编码路径列表，改为：

```gdscript
const CHARACTER_FILES: Array[String] = [
    "res://resources/characters/ranger.tres",
]
```

若使用 DirAccess 目录扫描则无需改动。

- [ ] **Step 12.7：手动启动 Godot 编辑器刷新 class_name 缓存**

（或 headless 再跑一次确认资源加载无错）

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 | tail -10
```

预期：无 `Error parsing res://resources/...` 这类错。

- [ ] **Step 12.8：Commit**

```bash
git add resources/characters/ranger.tres resources/hero_abilities resources/exp resources/perks/ranger assets/characters/ranger
git commit -m "feat(#2): 游侠资源组装 (ranger.tres + 4 能力 + 18 perk + ExpConfig + 占位精灵)"
```

---

## Task 13：Player.gd 挂载能力系统

**Files:**
- Modify: `scripts/entities/player.gd`
- Modify: `scenes/entities/player.tscn` — 加 `Abilities: Node` 子节点

- [ ] **Step 13.1：修改 player.tscn — 加 Abilities 容器**

文本模式打开 `scenes/entities/player.tscn`，在根节点下添加：

```
[node name="Abilities" type="Node" parent="."]
```

（或在编辑器右键 → Add Child Node → Node → 命名 Abilities）

- [ ] **Step 13.2：修改 `scripts/entities/player.gd` — _ready 加挂载逻辑**

在 `_ready()` 的末尾（或合适位置）添加：

```gdscript
_mount_abilities()
```

新增方法：

```gdscript
func _mount_abilities() -> void:
    var char_data: CharacterData = GameConfig.characters.get(PlayerState.current_character)
    if char_data == null or char_data.ability_scenes.is_empty():
        push_warning("Player: 无 ability_scenes 配置")
        return
    var container: Node = $Abilities
    # 先清空（测试中 _ready 可能多次调用）
    for c in container.get_children():
        c.queue_free()
    for i in range(char_data.ability_scenes.size()):
        var ps: PackedScene = char_data.ability_scenes[i]
        if ps == null:
            continue
        var inst: Node = ps.instantiate()
        # 挂到 Abilities 子节点；data 已通过场景 @export 绑定
        # 但我们需要从 hero_abilities/ranger/*.tres 注入 data
        _inject_ability_data(inst, i)
        container.add_child(inst)

func _inject_ability_data(comp: Node, slot_index: int) -> void:
    # 简化：按 slot index 匹配 ranger tres 路径
    var paths := [
        "res://resources/hero_abilities/ranger/auto_attack.tres",
        "res://resources/hero_abilities/ranger/gust_arrow.tres",
        "res://resources/hero_abilities/ranger/arrow_rain.tres",
        "res://resources/hero_abilities/ranger/hunt_mark.tres",
    ]
    if slot_index >= paths.size():
        return
    var data: Resource = load(paths[slot_index])
    if data and "data" in comp:
        comp.data = data
```

> 更健壮方案：`CharacterData` 加 `ability_data_list: Array[Resource]` 字段，逐个注入。为简化 Task，用硬编码路径 —— 未来 #7 扩别的英雄时改为 `CharacterData` 字段。

- [ ] **Step 13.3：运行游戏 + 手工验证**

```bash
# 启动编辑器（手工）
```

在 Godot 编辑器里运行 main 场景，确认：
- Player 生成后自动攻击打到最近敌人
- 移动后触发疾风箭
- 约 10s 释放一次箭雨（场上有敌人时）
- 击杀足够敌人后触发猎杀标记

若某技能不工作，回查对应组件 + tres 数值。

- [ ] **Step 13.4：运行测试套件**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -30
```

确保 Task 8-11 单测继续 PASS。

- [ ] **Step 13.5：Commit**

```bash
git add scripts/entities/player.gd scenes/entities/player.tscn
git commit -m "feat(#2): Player 挂载能力组件系统 (ability_scenes 动态实例化)"
```

---

## Task 14：塔价格递增机制

**Files:**
- Modify: `scripts/resources/shop_config.gd`
- Modify: `resources/shop/shop_config.tres`
- Modify: `scripts/core/inventory_manager.gd`
- Create: `tests/unit/test_tower_cost_progression.gd`

- [ ] **Step 14.1：写失败测试**

```gdscript
extends GutTest

func before_each() -> void:
    PlayerState.init_character("ranger")
    InventoryManager.reset()
    InventoryManager.coins = 1000

func test_cost_increases_with_deployed_count():
    var cost_0: int = InventoryManager.calc_tower_buy_cost("pea_shooter")
    # 模拟已部署 1 座
    InventoryManager.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0,0), deploy_id = 1})
    var cost_1: int = InventoryManager.calc_tower_buy_cost("pea_shooter")
    assert_gt(cost_1, cost_0, "已部署后价格应上升")
    assert_eq(cost_1 - cost_0, GameConfig.shop_config.tower_cost_per_same_type, "应等于 per_same_type 增量")

func test_pending_towers_also_count():
    InventoryManager.pending_towers.append("pea_shooter")
    var cost_1: int = InventoryManager.calc_tower_buy_cost("pea_shooter")
    var cost_base: int = GameConfig.shop_config.tower_cost_base
    assert_eq(cost_1, cost_base + GameConfig.shop_config.tower_cost_per_same_type, "pending 塔也计入 N")

func test_different_types_independent():
    InventoryManager.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0,0), deploy_id = 1})
    var pea_cost: int = InventoryManager.calc_tower_buy_cost("pea_shooter")
    var ice_cost: int = InventoryManager.calc_tower_buy_cost("ice_flower")
    assert_gt(pea_cost, ice_cost, "不同类型价格独立")
```

- [ ] **Step 14.2：修改 `shop_config.gd`**

```gdscript
class_name ShopConfig
extends Resource

# Roll 塔配置
@export var roll_cost: int = 3
@export var pending_queue_size: int = 3
@export var dynamic_weight_multiplier: float = 1.5

# 塔价格（N = 已部署 + pending 同类塔数）
@export var tower_cost_base: int = 5
@export var tower_cost_per_same_type: int = 3

# 卖出配置
@export var sell_return_ratio: float = 0.7
```

- [ ] **Step 14.3：修改 `resources/shop/shop_config.tres`**

文本模式在 [resource] 下加（若不存在）：

```
tower_cost_base = 5
tower_cost_per_same_type = 3
```

- [ ] **Step 14.4：修改 `inventory_manager.gd` — 加 `calc_tower_buy_cost` 与 deploy 扣费**

在文件末尾添加：

```gdscript
func calc_tower_buy_cost(tower_id: String) -> int:
    var n: int = 0
    for entry in deployed_towers:
        if entry.id == tower_id:
            n += 1
    for tid in pending_towers:
        if tid == tower_id:
            n += 1
    # pending 中该塔自己也算 1（调用时正在部署，待 consume 后 n 已减 1；为避免一致性问题这里 n 不含即将部署的那个）
    var cfg: ShopConfig = GameConfig.shop_config
    return cfg.tower_cost_base + cfg.tower_cost_per_same_type * n
```

修改 `deploy_pending_tower(pending_index, grid_pos)` 方法，在 `pending_towers.remove_at(pending_index)` **之前**加：

```gdscript
var tower_id_preview: String = pending_towers[pending_index]
var buy_cost: int = calc_tower_buy_cost(tower_id_preview)
if coins < buy_cost:
    return {}
# 扣金币
coins -= buy_cost
EventBus.coins_changed.emit(-buy_cost, coins)
```

确保把 `tower_id_preview` 统一替换掉原来重复读取的 `tower_id`。

修改 `_apply_sell(item)` 方法 — 对塔类 item，按卖出前的 N 计算返还：

```gdscript
func _apply_sell(item: Dictionary) -> int:
    var refund: int = 0
    if item.type == "tower":
        # 卖塔：按卖出前 N 算价 × sell_return_ratio
        var n_before: int = 0
        for entry in deployed_towers:
            if entry.id == item.id:
                n_before += 1
        for tid in pending_towers:
            if tid == item.id:
                n_before += 1
        # deployed_towers 在 sell 调用前已 remove_at，这里 n_before 是卖出后 + 1 = 卖出前
        n_before += 1
        var cfg: ShopConfig = GameConfig.shop_config
        var cost_at_this_n: int = cfg.tower_cost_base + cfg.tower_cost_per_same_type * (n_before - 1)
        refund = int(round(cost_at_this_n * cfg.sell_return_ratio))
    else:
        # 兼容：其他类别按旧逻辑（目前无武器），不应走到
        refund = 0
    coins += refund
    EventBus.item_sold.emit(item, refund)
    EventBus.coins_changed.emit(refund, coins)
    return refund
```

- [ ] **Step 14.5：运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_tower_cost_progression.gd -gexit 2>&1 | tail -15
```

预期：PASS。

- [ ] **Step 14.6：Commit**

```bash
git add scripts/resources/shop_config.gd resources/shop/shop_config.tres scripts/core/inventory_manager.gd tests/unit/test_tower_cost_progression.gd tests/unit/test_tower_cost_progression.gd.uid
git commit -m "feat(#2): 塔价格递增机制 (tower_cost_base + per_same_type * N)"
```

---

## Task 15：character_selection 改造

**Files:**
- Modify: `scripts/ui/character_selection.gd`
- Modify: `scenes/ui/character_selection.tscn`

- [ ] **Step 15.1：修改 `character_selection.tscn` 场景布局**

文本模式打开 `scenes/ui/character_selection.tscn`：
- 删除 5 张老角色卡节点（Dora/Gorg/Kaze/Merlin/Nemo）
- 新增 1 张 ranger 卡（居中显示，portrait = `res://assets/characters/ranger/portrait.png`，display_name = "游侠"）
- 新增 5 张"敬请期待"占位卡（灰色背景 + 文字"敬请期待"），不可点击

或在 `character_selection.gd` 中动态生成（更灵活）。

- [ ] **Step 15.2：修改 `character_selection.gd`**

```gdscript
extends Control

@onready var _ranger_card: Button = $HBox/RangerCard  # 按实际节点路径
# 5 个占位卡片：$HBox/Placeholder1..5

func _ready() -> void:
    _ranger_card.pressed.connect(_on_ranger_selected)
    # 占位卡片不响应

func _on_ranger_selected() -> void:
    PlayerState.init_character(Enums.Character.RANGER)
    PlayerProgression.reset()
    InventoryManager.reset()
    StatsTracker.reset()
    PerkManager.reset()
    PerkManager.refresh_pool_for_current_character()
    SceneManager.go_to(Enums.Scene.MAP_SELECT)
```

> `PerkManager.refresh_pool_for_current_character()` 是 Task 6 实现的；新角色选中后必须刷新池。

- [ ] **Step 15.3：手工验证**

编辑器运行 character_selection 场景，确认：
- 只有 ranger 卡可点
- 点击后跳 map_select

- [ ] **Step 15.4：Commit**

```bash
git add scripts/ui/character_selection.gd scenes/ui/character_selection.tscn
git commit -m "feat(#2): character_selection 只显示游侠 + 5 个敬请期待占位"
```

---

## Task 16：BattleHUD 改造（加猎杀充能条 + 箭雨 CD 指示）

**Files:**
- Modify: `scripts/ui/battle_hud.gd` + `.tscn`

- [ ] **Step 16.1：修改 `battle_hud.tscn`**

在 HUD 左上区域（HP 旁）加：
- `HuntMarkBar: ProgressBar`（range 0-100，颜色黄/红切换）
- `HuntMarkDurationLabel: Label`（标记激活时显示倒计时）

在 HUD 右上加：
- `ArrowRainIndicator: TextureRect`（图标 + 冷却圆环覆盖）

确认 Task 3 已删除的人口显示不再存在。

- [ ] **Step 16.2：修改 `battle_hud.gd`**

加 `@onready` 节点引用 + `_process(delta)` 每帧更新：

```gdscript
@onready var _hunt_mark_bar: ProgressBar = $HuntMarkBar
@onready var _hunt_mark_duration_label: Label = $HuntMarkDurationLabel
@onready var _rain_indicator: TextureRect = $ArrowRainIndicator

func _process(_delta: float) -> void:
    _update_hunt_mark()
    _update_rain_indicator()

func _update_hunt_mark() -> void:
    var player: Node = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
    if player == null:
        return
    var abilities: Node = player.get_node_or_null("Abilities")
    if abilities == null:
        return
    var mark_comp: HuntMarkSkillComponent = null
    for c in abilities.get_children():
        if c is HuntMarkSkillComponent:
            mark_comp = c
            break
    if mark_comp == null:
        _hunt_mark_bar.visible = false
        return
    _hunt_mark_bar.visible = true
    _hunt_mark_bar.max_value = mark_comp.get_charge_required()
    _hunt_mark_bar.value = mark_comp.get_charge()
    if mark_comp.get_marked_target() != null:
        _hunt_mark_bar.modulate = Color.RED
        _hunt_mark_duration_label.visible = true
        _hunt_mark_duration_label.text = "%.1fs" % mark_comp._mark_timer
    else:
        _hunt_mark_bar.modulate = Color.YELLOW
        _hunt_mark_duration_label.visible = false

func _update_rain_indicator() -> void:
    var player: Node = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
    if player == null:
        return
    var abilities: Node = player.get_node_or_null("Abilities")
    if abilities == null:
        return
    var rain_comp: ArrowRainSkillComponent = null
    for c in abilities.get_children():
        if c is ArrowRainSkillComponent:
            rain_comp = c
            break
    if rain_comp == null:
        return
    # 冷却显示（简化：用 modulate alpha）
    if rain_comp._cooldown_timer > 0.0:
        _rain_indicator.modulate.a = 0.3
    else:
        _rain_indicator.modulate.a = 1.0
```

> 将 `_cooldown_timer`、`_mark_timer` 暴露为 public（去下划线或加 getter）以便 HUD 读。或在组件中加 `get_cooldown_remaining()` / `get_mark_remaining()` 方法。

- [ ] **Step 16.3：手工验证**

编辑器运行 main，确认：
- 充能条随击杀增加
- 激活标记时条变红 + 显示倒计时
- 箭雨图标 CD 时灰掉

- [ ] **Step 16.4：Commit**

```bash
git add scripts/ui/battle_hud.gd scenes/ui/battle_hud.tscn
git commit -m "feat(#2): BattleHUD 加猎杀充能条 + 箭雨 CD 指示"
```

---

## Task 17：PerkSelectionOverlay 改造（显示堆叠等级）

**Files:**
- Modify: `scripts/ui/perk_selection_overlay.gd`
- Modify: `scenes/ui/perk_selection_overlay.tscn`

- [ ] **Step 17.1：修改 UI — 卡片上加 `LevelLabel`**

`perk_selection_overlay.tscn` 每张卡片节点下添加：

```
[node name="LevelLabel" type="Label" parent="...Card..."]
text = "[1/5]"
```

- [ ] **Step 17.2：修改脚本填充 Label**

在 `perk_selection_overlay.gd` 的 `_setup_card(card_node, perk_data)` 或等效方法里添加：

```gdscript
var level_label: Label = card_node.get_node("LevelLabel")
var current_level: int = PerkManager.get_perk_level(perk_data.id)
var next_level: int = current_level + 1
if perk_data.max_level > 1:
    level_label.text = "[%d/%d]" % [next_level, perk_data.max_level]
    level_label.visible = true
else:
    level_label.visible = false
```

- [ ] **Step 17.3：监听 `no_perk_available` 信号自动关闭弹窗**

在 `perk_selection_overlay.gd._ready`：

```gdscript
EventBus.no_perk_available.connect(_on_no_perk_available)

func _on_no_perk_available() -> void:
    # 显示一条提示然后关闭
    # 这里简化：直接关闭
    hide()
```

- [ ] **Step 17.4：Commit**

```bash
git add scripts/ui/perk_selection_overlay.gd scenes/ui/perk_selection_overlay.tscn
git commit -m "feat(#2): PerkSelectionOverlay 显示 perk 堆叠等级 + 无 perk 可选时自动关闭"
```

---

## Task 18：扩充 waves 到 20 波

**Files:**
- Create: `resources/waves/forest/wave_13.tres` ～ `wave_20.tres`（8 个新波）

- [ ] **Step 18.1：查看现有 wave_12.tres 配置作为参考**

```bash
cat /Users/langtao/utoland/resources/waves/forest/wave_12.tres
```

复制其结构。

- [ ] **Step 18.2：批量创建 wave_13 ～ wave_20.tres**

按如下数值表配置（`time_limit` / `max_alive_enemies` / `enemy_weights` / `elite_chance`）：

| 波 | time_limit | max_alive_enemies | is_boss_wave | boss_id | elite_chance | 设计说明 |
|---|---|---|---|---|---|---|
| 13 | 60 | 35 | false | - | 0.10 | 多个重甲兵同时（spec §6.3） |
| 14 | 65 | 38 | false | - | 0.12 | 后期压力开始 |
| 15 | 70 | 40 | true | boss_guardian | 0.08 | 第三个 Boss + 多个拆塔者 |
| 16 | 70 | 40 | false | - | 0.13 | 冲刺者成群 |
| 17 | 75 | 42 | false | - | 0.14 | 投射者增多 |
| 18 | 80 | 45 | false | - | 0.15 | 重甲兵常态化 |
| 19 | 85 | 48 | false | - | 0.16 | 最后一轮压力铺垫 |
| 20 | 90 | 50 | true | boss_guardian_final | 0.12 | 最终 Boss + 全方向满强度 |

`boss_guardian_final` 若不存在，则 `boss_id = boss_guardian`，通过加一个缩放倍率在 EnemyData 加载后运行时拉高（或暂时直接用 `boss_guardian`，依赖难度缩放 Wave 11+ 指数增长自然放大）。**本 Task 先用 `boss_guardian`**，#5 子项目再做专属最终 Boss。

`enemy_weights` 按现有 wave_12 的风格延伸；若时间紧用同样的权重分布即可（#5 会重做）。

`spawn_phases` 每波 2-3 个阶段（参考 wave_12）。

**wave_13.tres 模板示例**（参考实际 wave_12 结构调整）：

```
[gd_resource type="Resource" script_class="WaveData" load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/resources/wave_data.gd" id="1"]
[ext_resource type="Resource" path="res://resources/spawn/wave_phase_slow.tres" id="2"]
[ext_resource type="Resource" path="res://resources/spawn/wave_phase_fast.tres" id="3"]

[resource]
script = ExtResource("1")
wave_number = 13
time_limit = 60.0
max_alive_enemies = 35
is_boss_wave = false
enemy_weights = {"normal": 50, "fast": 25, "tank": 25}
elite_chance = 0.10
spawn_phases = [ExtResource("2"), ExtResource("3")]
```

（具体字段名以 `wave_data.gd` 定义为准，实施时对照 wave_12.tres）

- [ ] **Step 18.3：手工验证波次文件加载**

编辑器运行 main 场景跑到第 13 波以上，确认不报错。

- [ ] **Step 18.4：Commit**

```bash
git add resources/waves/forest/wave_13.tres resources/waves/forest/wave_14.tres resources/waves/forest/wave_15.tres resources/waves/forest/wave_16.tres resources/waves/forest/wave_17.tres resources/waves/forest/wave_18.tres resources/waves/forest/wave_19.tres resources/waves/forest/wave_20.tres
git commit -m "feat(#2): 扩充波次到 20 波 (wave_13-20，第 15/20 波 Boss)"
```

---

## Task 19：集成测试 + 全套验证 + 手工 20 波跑通

**Files:**
- Create: `tests/integration/test_ranger_flow.gd`（改写现有 `test_perk_levelup_flow.gd`）
- Delete: `tests/integration/test_perk_levelup_flow.gd`（若仍在）

- [ ] **Step 19.1：写集成测试 `test_ranger_flow.gd`**

```gdscript
extends GutTest

func before_each() -> void:
    PlayerState.init_character("ranger")
    PlayerProgression.reset()
    InventoryManager.reset()
    PerkManager.refresh_pool_for_current_character()
    PerkManager.reset()

func test_levelup_offers_three_categories():
    watch_signals(EventBus)
    PlayerProgression.add_exp(10000)  # 跳多级
    await get_tree().process_frame
    var offer: Array = PerkManager.get_current_offer()
    assert_gt(offer.size(), 0, "应有 perk 被 offer")
    var cats := []
    for p in offer:
        cats.append(p.category)
    assert_eq(cats.size(), offer.size(), "每个 offer 应来自不同 category")

func test_select_perk_applies_level():
    PlayerProgression.add_exp(10000)
    await get_tree().process_frame
    var offer: Array = PerkManager.get_current_offer()
    if offer.is_empty():
        pending("无 perk 池（可能 ranger.tres 未配置 perk_pool）")
        return
    var picked: PerkData = offer[0]
    PerkManager.select_perk(picked.id)
    assert_eq(PerkManager.get_perk_level(picked.id), 1, "选中后堆叠 +1")

func test_full_exhaust_emits_no_perk_available():
    # 把所有 perk 全部设为满级
    for p in (GameConfig.characters["ranger"] as CharacterData).perk_pool:
        PerkManager.force_level_for_test(p.id, p.max_level)
    watch_signals(EventBus)
    PerkManager.trigger_offer_for_test()
    assert_signal_emitted(EventBus, "no_perk_available")
```

- [ ] **Step 19.2：运行全套测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -60
```

预期：绝大部分 PASS。预存的 `test_knockback_changes_position` 是 pre-existing 失败不管。

- [ ] **Step 19.3：手工验证清单**

在 Godot 编辑器运行 main 场景，逐条核对：

- [ ] character_selection 只显示 ranger 一张卡 + 5 个"敬请期待"占位
- [ ] 选 ranger 进 main → 基础自动攻击打到最近敌人
- [ ] 移动触发疾风箭（方向正确 + 穿透 + 减速）
- [ ] 站 10s 不动 → 箭雨自动释放到最近敌人
- [ ] 连续击杀 30-40 杂兵 → 猎杀标记激活 + 头顶红箭头 + 血最高 + 伤害 2x
- [ ] 升级弹窗显示 3 类 perk + 堆叠等级 [n/max]
- [ ] 质变 perk 选过一次后不再出现
- [ ] Roll 3 座同类塔价格递增（第 1 座 5g → 第 2 座 8g → 第 3 座 11g）
- [ ] 完整 20 波跑通（含 4 个 Boss）不崩
- [ ] 英雄死亡 → 1s 延迟 → result 场景

任何一项失败：回对应 Task 调试。

- [ ] **Step 19.4：Commit**

```bash
git add tests/integration/test_ranger_flow.gd tests/integration/test_ranger_flow.gd.uid
git rm tests/integration/test_perk_levelup_flow.gd 2>/dev/null || true
git commit -m "test(#2): 游侠流程集成测试 + 全套 20 波手工验证"
```

---

## 验收 Checklist

- [ ] 单元测试 + 集成测试全部 PASS（pre-existing `test_knockback_changes_position` 除外）
- [ ] 手工 20 波完整跑通
- [ ] `InventoryManager` / `PlayerState` / `PerkManager` 中无废弃字段（无 `deployed_weapons` / `new_passive_id` / `POPULATION_BONUS` 等）
- [ ] `character_selection` 只显示游侠 + 5 占位
- [ ] `develop` 分支增量 commit（不合并到 main，等 #3-#7 完成后统一合并）
