# 游戏数值平衡 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现游戏数值平衡设计，包括角色差异化、敌人/波次调整、成长曲线、武器/塔再平衡和升级弹窗等级门控。

**Architecture:** 数据驱动改动为主（修改 .tres 资源文件），配合 3 处代码逻辑变更（XP 公式、稀有度权重门控、波次缩放）。所有代码变更遵循 TDD。

**Tech Stack:** Godot 4.6 / GDScript / GUT 测试框架

**Spec:** `docs/superpowers/specs/2026-03-14-game-balance-design.md`

---

## Chunk 1: 资源数据更新（角色、武器、塔、敌人）

### Task 1: 更新角色资源文件

**Files:**
- Modify: `resources/characters/dora.tres`
- Modify: `resources/characters/gorg.tres`
- Modify: `resources/characters/kaze.tres`
- Modify: `resources/characters/merlin.tres`
- Modify: `resources/characters/nemo.tres`

- [ ] **Step 1: 更新 dora.tres**

```tres
max_hp = 100.0
speed = 100.0
damage_mult = 1.0
attack_speed_mult = 1.0
starting_gold = 30
default_weapon = "rifle"
default_tower = "pea_shooter"
passive_type = "coin_bonus"
passive_value = 0.2
passive_description = "金币掉落 +20%"
```

- [ ] **Step 2: 更新 gorg.tres**

```tres
max_hp = 140.0
speed = 80.0
damage_mult = 1.1
attack_speed_mult = 0.9
starting_gold = 20
default_weapon = "blade"
default_tower = "stump"
passive_type = "kill_heal"
passive_value = 3.0
passive_description = "击杀敌人回复 3 HP"
```

- [ ] **Step 3: 更新 kaze.tres**

```tres
max_hp = 75.0
speed = 130.0
damage_mult = 1.0
attack_speed_mult = 1.15
starting_gold = 25
default_weapon = "minigun"
default_tower = "ice_flower"
passive_type = "damage_on_low_hp"
passive_value = 0.4
passive_description = "HP 低于 30% 时伤害 +40%"
```

- [ ] **Step 4: 更新 merlin.tres**

```tres
max_hp = 85.0
speed = 95.0
damage_mult = 0.9
attack_speed_mult = 1.0
starting_gold = 40
default_weapon = "laser"
default_tower = "mushroom"
passive_type = "tower_attack_speed_bonus"
passive_value = 0.15
passive_description = "所有塔攻速 +15%"
```

- [ ] **Step 5: 更新 nemo.tres**

```tres
max_hp = 90.0
speed = 105.0
damage_mult = 0.95
attack_speed_mult = 1.0
starting_gold = 35
default_weapon = "ice_gun"
default_tower = "sunflower"
passive_type = "tower_hp_bonus"
passive_value = 0.25
passive_description = "所有塔 HP +25%"
```

- [ ] **Step 6: 编写角色数据验证测试**

在 `tests/unit/test_character_balance.gd` 中：

```gdscript
extends GutTest

# 验证角色差异化数值正确
func test_dora_stats():
    var data = GameConfig.characters[Enums.Character.DORA]
    assert_eq(data.max_hp, 100.0)
    assert_eq(data.speed, 100.0)
    assert_eq(data.damage_mult, 1.0)
    assert_eq(data.attack_speed_mult, 1.0)
    assert_eq(data.starting_gold, 30)
    assert_eq(data.default_weapon, "rifle")
    assert_eq(data.default_tower, "pea_shooter")
    assert_eq(data.passive_type, "coin_bonus")
    assert_almost_eq(data.passive_value, 0.2, 0.001)

func test_gorg_stats():
    var data = GameConfig.characters[Enums.Character.GORG]
    assert_eq(data.max_hp, 140.0)
    assert_eq(data.speed, 80.0)
    assert_eq(data.damage_mult, 1.1)
    assert_eq(data.attack_speed_mult, 0.9)
    assert_eq(data.starting_gold, 20)
    assert_eq(data.default_weapon, "blade")
    assert_eq(data.default_tower, "stump")
    assert_eq(data.passive_type, "kill_heal")
    assert_almost_eq(data.passive_value, 3.0, 0.001)

func test_kaze_stats():
    var data = GameConfig.characters[Enums.Character.KAZE]
    assert_eq(data.max_hp, 75.0)
    assert_eq(data.speed, 130.0)
    assert_eq(data.damage_mult, 1.0)
    assert_eq(data.attack_speed_mult, 1.15)
    assert_eq(data.starting_gold, 25)
    assert_eq(data.default_weapon, "minigun")
    assert_eq(data.default_tower, "ice_flower")
    assert_eq(data.passive_type, "damage_on_low_hp")
    assert_almost_eq(data.passive_value, 0.4, 0.001)

func test_merlin_stats():
    var data = GameConfig.characters[Enums.Character.MERLIN]
    assert_eq(data.max_hp, 85.0)
    assert_eq(data.speed, 95.0)
    assert_eq(data.damage_mult, 0.9)
    assert_eq(data.attack_speed_mult, 1.0)
    assert_eq(data.starting_gold, 40)
    assert_eq(data.default_weapon, "laser")
    assert_eq(data.default_tower, "mushroom")
    assert_eq(data.passive_type, "tower_attack_speed_bonus")
    assert_almost_eq(data.passive_value, 0.15, 0.001)

func test_nemo_stats():
    var data = GameConfig.characters[Enums.Character.NEMO]
    assert_eq(data.max_hp, 90.0)
    assert_eq(data.speed, 105.0)
    assert_eq(data.damage_mult, 0.95)
    assert_eq(data.attack_speed_mult, 1.0)
    assert_eq(data.starting_gold, 35)
    assert_eq(data.default_weapon, "ice_gun")
    assert_eq(data.default_tower, "sunflower")
    assert_eq(data.passive_type, "tower_hp_bonus")
    assert_almost_eq(data.passive_value, 0.25, 0.001)

func test_all_characters_have_unique_passives():
    var passives := []
    for char_id in GameConfig.characters:
        var data = GameConfig.characters[char_id]
        assert_does_not_have(passives, data.passive_type, "被动技能不应重复: %s" % data.passive_type)
        passives.append(data.passive_type)
    assert_eq(passives.size(), 5)
```

- [ ] **Step 7: 运行测试验证**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_character_balance.gd -gexit`
Expected: 全部 PASS

- [ ] **Step 8: 提交**

```bash
git add resources/characters/ tests/unit/test_character_balance.gd
git commit -m "feat: 角色差异化数值 - 5 角色独立 HP/速度/被动/装备"
```

---

### Task 2: 更新武器资源文件

**Files:**
- Modify: `resources/weapons/rifle.tres`
- Modify: `resources/weapons/shotgun.tres`
- Modify: `resources/weapons/laser.tres`

- [ ] **Step 1: 更新 rifle.tres**

修改以下字段：
```
damage_per_level = PackedFloat32Array(8, 12, 18, 25, 34)
fire_rate_per_level = PackedFloat32Array(0.12, 0.11, 0.10, 0.09, 0.08)
```

- [ ] **Step 2: 更新 shotgun.tres**

修改以下字段：
```
damage_per_level = PackedFloat32Array(8, 12, 17, 23, 30)
```
fire_rate_per_level 保持不变：`PackedFloat32Array(0.6, 0.55, 0.5, 0.45, 0.4)`

- [ ] **Step 3: 更新 laser.tres**

修改以下字段：
```
damage_per_level = PackedFloat32Array(12, 17, 23, 30, 40)
```
fire_rate_per_level 保持不变：`PackedFloat32Array(0.15, 0.13, 0.11, 0.09, 0.07)`

- [ ] **Step 4: 编写武器数据验证测试**

在 `tests/unit/test_weapon_balance.gd` 中：

```gdscript
extends GutTest

func test_rifle_rebalanced():
    var data = GameConfig.weapons[Enums.WeaponId.RIFLE]
    # L1 伤害降低，DPS 从 100 降到 ~67
    assert_eq(data.damage_per_level[0], 8.0)
    assert_eq(data.damage_per_level[4], 34.0)
    assert_almost_eq(data.fire_rate_per_level[0], 0.12, 0.001)
    assert_almost_eq(data.fire_rate_per_level[4], 0.08, 0.001)

func test_shotgun_rebalanced():
    var data = GameConfig.weapons[Enums.WeaponId.SHOTGUN]
    # L1 伤害提升，DPS 从 40 提到 ~53
    assert_eq(data.damage_per_level[0], 8.0)
    assert_eq(data.damage_per_level[4], 30.0)
    # 开火间隔不变
    assert_almost_eq(data.fire_rate_per_level[0], 0.6, 0.001)

func test_laser_rebalanced():
    var data = GameConfig.weapons[Enums.WeaponId.LASER]
    # L1 伤害提升，DPS 从 53 提到 80
    assert_eq(data.damage_per_level[0], 12.0)
    assert_eq(data.damage_per_level[4], 40.0)
    # 开火间隔不变
    assert_almost_eq(data.fire_rate_per_level[0], 0.15, 0.001)
```

- [ ] **Step 5: 运行测试验证**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_weapon_balance.gd -gexit`
Expected: 全部 PASS

- [ ] **Step 6: 提交**

```bash
git add resources/weapons/rifle.tres resources/weapons/shotgun.tres resources/weapons/laser.tres tests/unit/test_weapon_balance.gd
git commit -m "feat: 武器 DPS 再平衡 - Rifle 降低, Shotgun/Laser 提升"
```

---

### Task 3: 更新塔资源文件

**Files:**
- Modify: `resources/towers/thorn.tres` — 新增 place_cost
- Modify: `resources/towers/sunflower.tres` — 新增 place_cost + HP 提升
- Modify: `resources/towers/mint.tres` — 新增 place_cost
- Modify: `resources/towers/heal_flower.tres` — 新增 place_cost
- Modify: `resources/towers/oak.tres` — 新增 place_cost
- Modify: `resources/towers/bamboo.tres` — 新增 place_cost + charge_time 调整
- Modify: `resources/towers/dandelion.tres` — knockback_interval 调整

- [ ] **Step 1: 更新 thorn.tres**

```
place_cost_per_level = PackedInt32Array(12, 16, 22, 30, 40)
```

- [ ] **Step 2: 更新 sunflower.tres**

```
place_cost_per_level = PackedInt32Array(18, 24, 32, 42, 55)
hp_per_level = PackedFloat32Array(70, 90, 115, 140, 170)
```

- [ ] **Step 3: 更新 mint.tres**

```
place_cost_per_level = PackedInt32Array(20, 26, 34, 44, 56)
```

- [ ] **Step 4: 更新 heal_flower.tres**

```
place_cost_per_level = PackedInt32Array(16, 22, 30, 40, 52)
```

- [ ] **Step 5: 更新 oak.tres**

```
place_cost_per_level = PackedInt32Array(22, 28, 36, 46, 58)
```

- [ ] **Step 6: 更新 bamboo.tres**

```
place_cost_per_level = PackedInt32Array(20, 26, 34, 44, 56)
charge_time = 12.0
```

- [ ] **Step 7: 更新 dandelion.tres**

```
knockback_interval = 4.0
```

- [ ] **Step 8: 编写塔数据验证测试**

在 `tests/unit/test_tower_balance.gd` 中：

```gdscript
extends GutTest

# 验证所有塔都有非零放置成本
func test_all_towers_have_place_cost():
    for tower_id in GameConfig.towers:
        var data: TowerData = GameConfig.towers[tower_id]
        var cost_l1: int = data.place_cost_per_level[0]
        assert_gt(cost_l1, 0, "塔 %s 的 L1 放置成本应 > 0" % data.id)

# 验证新增放置成本的塔
func test_thorn_place_cost():
    var data = GameConfig.towers[Enums.TowerId.THORN]
    assert_eq(data.place_cost_per_level[0], 12)
    assert_eq(data.place_cost_per_level[4], 40)

func test_sunflower_updated():
    var data = GameConfig.towers[Enums.TowerId.SUNFLOWER]
    assert_eq(data.place_cost_per_level[0], 18)
    assert_eq(data.place_cost_per_level[4], 55)
    # HP 提升
    assert_eq(data.hp_per_level[0], 70.0)
    assert_eq(data.hp_per_level[4], 170.0)

func test_mint_place_cost():
    var data = GameConfig.towers[Enums.TowerId.MINT]
    assert_eq(data.place_cost_per_level[0], 20)

func test_heal_flower_place_cost():
    var data = GameConfig.towers[Enums.TowerId.HEAL_FLOWER]
    assert_eq(data.place_cost_per_level[0], 16)

func test_oak_place_cost():
    var data = GameConfig.towers[Enums.TowerId.OAK]
    assert_eq(data.place_cost_per_level[0], 22)

func test_bamboo_updated():
    var data = GameConfig.towers[Enums.TowerId.BAMBOO]
    assert_eq(data.place_cost_per_level[0], 20)
    assert_almost_eq(data.charge_time, 12.0, 0.001)

func test_dandelion_knockback_interval():
    var data = GameConfig.towers[Enums.TowerId.DANDELION]
    assert_almost_eq(data.knockback_interval, 4.0, 0.001)
```

- [ ] **Step 9: 运行测试验证**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_tower_balance.gd -gexit`
Expected: 全部 PASS

- [ ] **Step 10: 提交**

```bash
git add resources/towers/ tests/unit/test_tower_balance.gd
git commit -m "feat: 塔数值调整 - 统一放置成本 + Sunflower/Bamboo/Dandelion 微调"
```

---

### Task 4: 更新敌人资源文件

**Files:**
- Modify: `resources/enemies/boss_guardian.tres`

- [ ] **Step 1: 更新 boss_guardian.tres**

```
hp = 1500.0
```
（从 1200 → 1500）

- [ ] **Step 2: 编写验证测试**

在 `tests/unit/test_enemy_balance.gd` 中：

```gdscript
extends GutTest

func test_guardian_hp_increased():
    var data = GameConfig.enemies[Enums.Enemy.BOSS_GUARDIAN]
    assert_eq(data.hp, 1500.0)
    assert_true(data.is_boss)
```

- [ ] **Step 3: 运行测试验证**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_enemy_balance.gd -gexit`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add resources/enemies/boss_guardian.tres tests/unit/test_enemy_balance.gd
git commit -m "feat: Guardian Boss HP 1200 → 1500"
```

---

## Chunk 2: 波次数据重建（20 波）

### Task 5: 重建波次资源文件

**Files:**
- Delete: `resources/waves/forest/wave_01.tres` ~ `wave_18.tres`（现有 18 波）
- Create: `resources/waves/forest/wave_01.tres` ~ `wave_20.tres`（新 20 波）

每个 .tres 文件遵循 Godot Resource 格式，以现有 `wave_01.tres` 为模板：

```tres
[gd_resource type="Resource" script_class="WaveData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/wave_data.gd" id="1"]

[resource]
script = ExtResource("1")
wave_number = 1
total_enemies = 20
time_limit = 60.0
spawn_interval = 1.5
```

Boss 波次额外添加 `is_boss_wave`, `boss_id`, `boss_escort_count` 字段。
有精英怪的波次添加 `elite_chance` 字段（elite_hp_mult 等使用默认值 1.5/1.3/2.0/1.2）。
有多种敌人的波次添加 `enemy_weights` 字段。
`time_limit` 值为本计划根据波次节奏估算的合理值，不在 spec 中。

- [ ] **Step 1: 删除旧波次文件**

```bash
rm resources/waves/forest/wave_*.tres
```

- [ ] **Step 2: 创建波次 1-5**

wave_01.tres:
```
wave_number = 1, total_enemies = 20, spawn_interval = 1.5, time_limit = 60.0
enemy_weights = {"normal": 100}
elite_chance = 0.0
```

wave_02.tres:
```
wave_number = 2, total_enemies = 25, spawn_interval = 1.3, time_limit = 60.0
enemy_weights = {"normal": 100}
elite_chance = 0.0
```

wave_03.tres:
```
wave_number = 3, total_enemies = 30, spawn_interval = 1.2, time_limit = 65.0
enemy_weights = {"normal": 80, "fast": 20}
elite_chance = 0.0
```

wave_04.tres:
```
wave_number = 4, total_enemies = 35, spawn_interval = 1.1, time_limit = 65.0
enemy_weights = {"normal": 70, "fast": 30}
elite_chance = 0.0
```

wave_05.tres:
```
wave_number = 5, total_enemies = 40, spawn_interval = 1.0, time_limit = 70.0
enemy_weights = {"normal": 60, "fast": 30, "tank": 10}
elite_chance = 0.05
```

- [ ] **Step 3: 创建波次 6-9**

wave_06.tres:
```
wave_number = 6, total_enemies = 45, spawn_interval = 0.9, time_limit = 70.0
enemy_weights = {"normal": 50, "fast": 30, "tank": 20}
elite_chance = 0.05
```

wave_07.tres:
```
wave_number = 7, total_enemies = 50, spawn_interval = 0.8, time_limit = 70.0
enemy_weights = {"normal": 45, "fast": 35, "tank": 20}
elite_chance = 0.08
```

wave_08.tres:
```
wave_number = 8, total_enemies = 55, spawn_interval = 0.7, time_limit = 70.0
enemy_weights = {"normal": 40, "fast": 35, "tank": 25}
elite_chance = 0.08
```

wave_09.tres:
```
wave_number = 9, total_enemies = 45, spawn_interval = 0.7, time_limit = 60.0
enemy_weights = {"normal": 35, "fast": 40, "tank": 25}
elite_chance = 0.1
```

- [ ] **Step 4: 创建波次 10（Boss Brute）**

wave_10.tres:
```
wave_number = 10, total_enemies = 35, spawn_interval = 0.6, time_limit = 90.0
enemy_weights = {"normal": 30, "fast": 40, "tank": 30}
elite_chance = 0.1
is_boss_wave = true
boss_id = "boss_brute"
boss_escort_count = 35
```

- [ ] **Step 5: 创建波次 11-15**

wave_11.tres:
```
wave_number = 11, total_enemies = 55, spawn_interval = 0.7, time_limit = 70.0
enemy_weights = {"normal": 35, "fast": 35, "tank": 30}
elite_chance = 0.1
```

wave_12.tres:
```
wave_number = 12, total_enemies = 60, spawn_interval = 0.6, time_limit = 70.0
enemy_weights = {"normal": 30, "fast": 40, "tank": 30}
elite_chance = 0.1
```

wave_13.tres:
```
wave_number = 13, total_enemies = 65, spawn_interval = 0.6, time_limit = 70.0
enemy_weights = {"normal": 30, "fast": 35, "tank": 35}
elite_chance = 0.12
```

wave_14.tres:
```
wave_number = 14, total_enemies = 70, spawn_interval = 0.5, time_limit = 70.0
enemy_weights = {"normal": 25, "fast": 35, "tank": 40}
elite_chance = 0.12
```

wave_15.tres:
```
wave_number = 15, total_enemies = 75, spawn_interval = 0.5, time_limit = 70.0
enemy_weights = {"normal": 25, "fast": 40, "tank": 35}
elite_chance = 0.15
```

- [ ] **Step 6: 创建波次 16-19**

wave_16.tres:
```
wave_number = 16, total_enemies = 80, spawn_interval = 0.4, time_limit = 65.0
enemy_weights = {"normal": 20, "fast": 40, "tank": 40}
elite_chance = 0.15
```

wave_17.tres:
```
wave_number = 17, total_enemies = 85, spawn_interval = 0.4, time_limit = 65.0
enemy_weights = {"normal": 20, "fast": 35, "tank": 45}
elite_chance = 0.15
```

wave_18.tres:
```
wave_number = 18, total_enemies = 75, spawn_interval = 0.35, time_limit = 60.0
enemy_weights = {"normal": 15, "fast": 40, "tank": 45}
elite_chance = 0.18
```

wave_19.tres:
```
wave_number = 19, total_enemies = 65, spawn_interval = 0.35, time_limit = 60.0
enemy_weights = {"normal": 20, "fast": 30, "tank": 50}
elite_chance = 0.18
```

- [ ] **Step 7: 创建波次 20（Boss Guardian）**

wave_20.tres:
```
wave_number = 20, total_enemies = 50, spawn_interval = 0.3, time_limit = 150.0
enemy_weights = {"normal": 20, "fast": 30, "tank": 50}
elite_chance = 0.15
is_boss_wave = true
boss_id = "boss_guardian"
boss_escort_count = 50
```

- [ ] **Step 8: 编写波次验证测试**

在 `tests/unit/test_wave_balance.gd` 中：

```gdscript
extends GutTest

func test_forest_has_20_waves():
    var waves = GameConfig.get_waves_for_map("forest")
    assert_eq(waves.size(), 20, "Forest 应有 20 波")

func test_wave_numbers_sequential():
    var waves = GameConfig.get_waves_for_map("forest")
    for i in range(waves.size()):
        assert_eq(waves[i].wave_number, i + 1)

func test_wave_10_is_brute_boss():
    var waves = GameConfig.get_waves_for_map("forest")
    var w10 = waves[9]
    assert_true(w10.is_boss_wave)
    assert_eq(w10.boss_id, "boss_brute")

func test_wave_20_is_guardian_boss():
    var waves = GameConfig.get_waves_for_map("forest")
    var w20 = waves[19]
    assert_true(w20.is_boss_wave)
    assert_eq(w20.boss_id, "boss_guardian")

func test_enemy_count_progression():
    var waves = GameConfig.get_waves_for_map("forest")
    # 第 1 波 20 个，第 17 波最多 85 个
    assert_eq(waves[0].total_enemies, 20)
    assert_eq(waves[16].total_enemies, 85)

func test_elite_chance_progression():
    var waves = GameConfig.get_waves_for_map("forest")
    # 前 4 波无精英
    assert_eq(waves[0].elite_chance, 0.0)
    assert_eq(waves[3].elite_chance, 0.0)
    # 第 5 波开始有精英
    assert_gt(waves[4].elite_chance, 0.0)

func test_spawn_interval_decreasing():
    var waves = GameConfig.get_waves_for_map("forest")
    # 第 1 波间隔最大，最后一波间隔最小
    assert_gt(waves[0].spawn_interval, waves[19].spawn_interval)

func test_wave_9_and_19_are_breather_waves():
    var waves = GameConfig.get_waves_for_map("forest")
    # Boss 前的喘息波数量低于前一波
    assert_lt(waves[8].total_enemies, waves[7].total_enemies)   # wave 9 < wave 8
    assert_lt(waves[18].total_enemies, waves[17].total_enemies)  # wave 19 < wave 18
```

- [ ] **Step 9: 运行测试验证**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_wave_balance.gd -gexit`
Expected: 全部 PASS

- [ ] **Step 10: 提交**

```bash
git add resources/waves/forest/ tests/unit/test_wave_balance.gd
git commit -m "feat: 重建 20 波次配置 - 割草级数量 + 双 Boss 节奏"
```

---

## Chunk 3: 代码逻辑变更（XP 公式、稀有度门控、波次缩放）

### Task 6: 修改 XP 升级公式

**Files:**
- Modify: `scripts/core/game_data.gd` — `get_xp_to_next_level()` 方法
- Test: `tests/unit/test_game_data_xp.gd`（已有，需更新）

- [ ] **Step 1: 编写失败测试**

修改 `tests/unit/test_game_data_xp.gd`：

**需要更新的已有测试**（旧公式断言值改为新公式值）：

1. `test_get_xp_to_next_level_formula()` (line 11-17)：
   - `assert_eq(..., 20)` → `assert_eq(..., 15)` (level 1)
   - `assert_eq(..., 35)` → `assert_eq(..., 21)` (level 2)
   - `assert_eq(..., 80)` → `assert_eq(..., 58)` (level 5)

2. `test_add_xp_triggers_level_up()` (line 25-29)：
   - `GameData.add_xp(20)` → `GameData.add_xp(15)` (新公式 L1 只需 15 XP)

3. `test_add_xp_multiple_levels()` (line 31-35)：
   - `GameData.add_xp(60)` → `GameData.add_xp(40)` (15+21=36 升两级，剩余 4 XP)
   - `assert_eq(GameData.current_xp, 5)` → `assert_eq(GameData.current_xp, 4)`

4. `test_add_xp_emits_signals()` (line 37-48)：
   - `GameData.add_xp(25)` → `GameData.add_xp(20)` (确保触发 1 次升级)

**新增测试**：

```gdscript
# 新公式: ceil(15 * 1.4 ^ (level - 1))
func test_xp_formula_exponential_growth():
    GameData.current_level = 1
    assert_eq(GameData.get_xp_to_next_level(), 15)
    GameData.current_level = 3
    assert_eq(GameData.get_xp_to_next_level(), 30)
    GameData.current_level = 10
    assert_eq(GameData.get_xp_to_next_level(), 311)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_game_data_xp.gd -gexit`
Expected: FAIL（旧公式返回不同值）

- [ ] **Step 3: 实现新公式**

修改 `scripts/core/game_data.gd` 中的 `get_xp_to_next_level()` 方法：

```gdscript
func get_xp_to_next_level() -> int:
    return ceili(15.0 * pow(1.4, current_level - 1))
```

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_game_data_xp.gd -gexit`
Expected: 全部 PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/core/game_data.gd tests/unit/test_game_data_xp.gd
git commit -m "feat: XP 公式改为指数型 ceil(15 * 1.4^(level-1))"
```

---

### Task 7: 升级弹窗等级门控稀有度

**Files:**
- Modify: `scripts/systems/upgrade_generator.gd` — 替换静态权重为等级门控
- Test: `tests/unit/test_upgrade_generator.gd`（已有，需扩展）

- [ ] **Step 1: 编写失败测试**

在 `tests/unit/test_upgrade_generator.gd` 中新增（不修改已有测试）：

```gdscript
# 等级门控稀有度权重
func test_rarity_weights_level_1():
    var weights = UpgradeGenerator.get_rarity_weights(1)
    assert_almost_eq(weights[0], 1.0, 0.001)  # Common
    assert_almost_eq(weights[1], 0.3, 0.001)  # Rare
    assert_almost_eq(weights[2], 0.0, 0.001)  # Epic

func test_rarity_weights_level_3():
    var weights = UpgradeGenerator.get_rarity_weights(3)
    assert_almost_eq(weights[0], 1.0, 0.001)
    assert_almost_eq(weights[1], 0.6, 0.001)
    assert_almost_eq(weights[2], 0.15, 0.001)

func test_rarity_weights_level_6():
    var weights = UpgradeGenerator.get_rarity_weights(6)
    assert_almost_eq(weights[0], 1.0, 0.001)
    assert_almost_eq(weights[1], 0.8, 0.001)
    assert_almost_eq(weights[2], 0.3, 0.001)

func test_rarity_weights_level_10():
    var weights = UpgradeGenerator.get_rarity_weights(10)
    assert_almost_eq(weights[0], 1.0, 0.001)
    assert_almost_eq(weights[1], 1.0, 0.001)
    assert_almost_eq(weights[2], 0.5, 0.001)

func test_epic_blocked_at_low_level():
    # 等级 1-2 时 Epic 权重为 0，不应出现 Epic 装备
    var weights = UpgradeGenerator.get_rarity_weights(2)
    assert_eq(weights[2], 0.0, "等级 2 时 Epic 权重应为 0")
```

- [ ] **Step 2: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_upgrade_generator.gd -gexit`
Expected: FAIL（`get_rarity_weights` 方法不存在）

- [ ] **Step 3: 实现等级门控**

修改 `scripts/systems/upgrade_generator.gd`：

1. 新增静态方法 `get_rarity_weights(player_level: int) -> Dictionary`：

```gdscript
## 按玩家等级返回稀有度权重，替换静态 RARITY_WEIGHTS
static func get_rarity_weights(player_level: int) -> Dictionary:
    if player_level <= 2:
        return {0: 1.0, 1: 0.3, 2: 0.0}
    elif player_level <= 4:
        return {0: 1.0, 1: 0.6, 2: 0.15}
    elif player_level <= 6:
        return {0: 1.0, 1: 0.8, 2: 0.3}
    else:
        return {0: 1.0, 1: 1.0, 2: 0.5}
```

2. 修改 `generate_options()` 中使用权重的地方，将 `RARITY_WEIGHTS[rarity]` 和 `TOWER_RARITY_WEIGHTS[rarity]` 替换为 `get_rarity_weights(GameData.current_level)[rarity]`。具体位置在 `_build_weapon_pool` 和 `_build_tower_pool` 中查找 `RARITY_WEIGHTS` 和 `TOWER_RARITY_WEIGHTS` 的引用处。

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_upgrade_generator.gd -gexit`
Expected: 全部 PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/systems/upgrade_generator.gd tests/unit/test_upgrade_generator.gd
git commit -m "feat: 升级弹窗等级门控稀有度权重"
```

---

### Task 8: 波次敌人缩放系统

**Files:**
- Modify: `scripts/systems/enemy_spawner.gd` — 添加 `class_name`、缩放常量、缩放方法、在 `spawn_enemy()` 中应用
- Modify: `.godot/global_script_class_cache.cfg` — 注册 `EnemySpawner` class_name（headless 测试需要）
- Create: `tests/unit/test_wave_scaling.gd`

- [ ] **Step 1: 添加 class_name**

在 `scripts/systems/enemy_spawner.gd` 第 1 行 `extends Node` 后添加：

```gdscript
class_name EnemySpawner
```

同时在 `.godot/global_script_class_cache.cfg` 中补充对应条目（headless 测试需要）。

- [ ] **Step 2: 编写失败测试**

创建 `tests/unit/test_wave_scaling.gd`：

```gdscript
extends GutTest

# 测试缩放计算函数（纯静态方法，不需要实例化）
func test_no_scaling_wave_1():
    var result = EnemySpawner.get_wave_scaling(1)
    assert_almost_eq(result.hp_mult, 1.0, 0.001)
    assert_almost_eq(result.damage_mult, 1.0, 0.001)

func test_no_scaling_wave_10():
    var result = EnemySpawner.get_wave_scaling(10)
    assert_almost_eq(result.hp_mult, 1.0, 0.001)
    assert_almost_eq(result.damage_mult, 1.0, 0.001)

func test_scaling_wave_11():
    var result = EnemySpawner.get_wave_scaling(11)
    assert_almost_eq(result.hp_mult, 1.06, 0.01)
    assert_almost_eq(result.damage_mult, 1.04, 0.01)

func test_scaling_wave_15():
    var result = EnemySpawner.get_wave_scaling(15)
    # 1.06^5 ≈ 1.338
    assert_almost_eq(result.hp_mult, 1.338, 0.01)
    # 1.04^5 ≈ 1.217
    assert_almost_eq(result.damage_mult, 1.217, 0.01)

func test_scaling_wave_20():
    var result = EnemySpawner.get_wave_scaling(20)
    # 1.06^10 ≈ 1.791
    assert_almost_eq(result.hp_mult, 1.791, 0.01)
    # 1.04^10 ≈ 1.480
    assert_almost_eq(result.damage_mult, 1.480, 0.01)
```

- [ ] **Step 3: 运行测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_wave_scaling.gd -gexit`
Expected: FAIL（`get_wave_scaling` 方法不存在）

- [ ] **Step 4: 实现波次缩放**

修改 `scripts/systems/enemy_spawner.gd`：

1. 在文件顶部常量区域新增：

```gdscript
const SCALING_START_WAVE := 11
const HP_SCALING_PER_WAVE := 1.06
const DAMAGE_SCALING_PER_WAVE := 1.04
```

2. 新增静态方法：

```gdscript
## 返回指定波次的缩放倍率，第 11 波开始缩放
static func get_wave_scaling(wave_number: int) -> Dictionary:
    if wave_number < SCALING_START_WAVE:
        return {"hp_mult": 1.0, "damage_mult": 1.0}
    var waves_past: int = wave_number - SCALING_START_WAVE + 1
    return {
        "hp_mult": pow(HP_SCALING_PER_WAVE, waves_past),
        "damage_mult": pow(DAMAGE_SCALING_PER_WAVE, waves_past)
    }
```

3. 在 `spawn_enemy()` 方法中，**在精英化逻辑之后**（即 line 82 之后，`add_child()` 和精英化都已完成），对非 Boss 敌人应用缩放。**注意：不能直接修改 `enemy.data.damage`，因为 `data` 是共享的 EnemyData Resource。** 应修改敌人实例上的属性：

```gdscript
    # 波次缩放（仅非 Boss 敌人，在精英化之后叠加）
    if not enemy.data.is_boss:
        var scaling = get_wave_scaling(_current_wave_data.wave_number)
        if scaling.hp_mult > 1.0:
            # 修改实例属性，不修改共享 Resource
            enemy.health.max_hp *= scaling.hp_mult
            enemy.health.current_hp = enemy.health.max_hp
            enemy._hitbox.damage *= scaling.damage_mult
            enemy.tower_attack_damage *= scaling.damage_mult
```

关键：缩放修改的是 `enemy.health.max_hp/current_hp`（HealthComponent 实例属性）、`enemy._hitbox.damage`（Hitbox 实例属性）和 `enemy.tower_attack_damage`（enemy 实例变量），而非共享的 `enemy.data`。这些属性在 `_ready()` 中已从 Resource 拷贝到实例上。

- [ ] **Step 4: 运行测试确认通过**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gtest=test_wave_scaling.gd -gexit`
Expected: 全部 PASS

- [ ] **Step 5: 运行全量测试确保无回归**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全部 PASS

- [ ] **Step 6: 提交**

```bash
git add scripts/systems/enemy_spawner.gd tests/unit/test_wave_scaling.gd
git commit -m "feat: 波次缩放系统 - 第 11 波起 HP +6%/伤害 +4% 每波"
```

---

## 任务依赖关系

```
Task 1 (角色)  ──┐
Task 2 (武器)  ──┤
Task 3 (塔)    ──┼── 独立，可并行
Task 4 (敌人)  ──┤
Task 5 (波次)  ──┘
Task 6 (XP 公式)    ── 独立
Task 7 (稀有度门控) ── 独立
Task 8 (波次缩放)   ── 依赖 Task 5（波次数据）
```

Task 1-7 均可独立并行执行，Task 8 需在 Task 5 完成后执行。
