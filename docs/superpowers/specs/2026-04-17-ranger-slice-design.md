# 游侠垂直切片设计（#2）

**状态**: 设计完成，待实施计划
**子项目**: 幸存者+TD 大重构 #2 英雄系统（游侠切片）
**前置**: #1 流程骨架已完成（2026-04-16）
**后续**: #3 塔耐久 + 拆塔者

---

## 一、目标与范围

把现有"装备栏 + 武器合成"模式改造为"英雄自动技能"，以**游侠**为首个垂直切片验证"幸存者走位 + TD 塔阵"双核心卖点。

**核心产出**：
1. 移除武器装备栏/合成/人口/老角色/老被动系统（大量删除）
2. 建立新英雄结构：`CharacterData` 扩展 + 能力组件体系 + 专属 `ExpConfig` + 专属 `perk_pool`
3. 填充游侠内容：ranger 角色 + 基础自动攻击 + 3 个自动技能 + 18 个专属 perk + 20 波骨架

**#2 不做**：塔耐久（#3）、地图改造（#4）、新敌人种类（#5）、羁绊系统（#6）、其它英雄（#7）。

---

## 二、关键设计决策

| 决策点 | 结论 | 理由摘要 |
|--------|------|----------|
| 武器系统处理 | **C 只复用底层组件** | 删 `WeaponManager` + 武器资源；保留 `RangedAttackComponent`/`TargetFinderComponent`/投射物场景 |
| 老角色处理 | **A 全删** | 5 个老角色 + 老被动系统连根拔除，`character_selection` 只剩 ranger + 5 个"敬请期待"占位 |
| 技能触发 | **A 全自动** | 符合 spec 设计哲学"操作仅移动，深度来自 build 构筑" |
| Perk 池关系 | **A 专属** | 游侠从 18 个专属 perk 的 4 类里随机选 3 类各抽 1；通用池保留不动但游侠不抽取 |
| 经验 + 人口 | **C 专属 ExpConfig + 删人口** | `CharacterData.exp_config` 专属；人口系统彻底移除 |
| 塔容量上限 | **A 价格递增** | `buy_cost = base + per_same_type * N`，N = 已部署+pending 同类塔数；纯经济曲线限流 |
| 能力架构 | **A 独立组件 + Resource** | 4 个能力各自独立 Node 挂 Player 下，数值通过 `.tres` 配置 |
| Perk 叠加 | **B max_level 字段** | 加成型默认 5，质变型默认 1；UI 显示堆叠进度 |
| 波次规模 | **B 扩到 20** | 扩 5 波骨架，复用现有敌人；Boss 在 5/10/15/20；第 20 波占位复用 `boss_guardian` 放大 |

---

## 三、需要删除的代码

### 3.1 武器系统

- `scripts/entities/weapons/weapon_manager.gd` + `.uid`
- `resources/weapons/bow.tres` / `shuriken.tres` / `sword.tres`
- `scripts/resources/weapon_data.gd`（若无继承关系）
- 武器 `AttackConfigData` 的武器侧用法（塔侧保留）
- 投射物场景 `arrow.tscn` / `shuriken.tscn` / `sword_swing` 暂保留，`ranger_arrow.tscn` 可新建或复用 `arrow.tscn`

### 3.2 InventoryManager 相关

- `deployed_weapons` 字段 + 所有操作（`buy_and_equip_weapon` / `merge_weapon` / `_try_equip_weapon`）
- `pending_weapons` 相关（如存在）
- 武器侧合成代码
- `shop_slots` / `is_first_shop_visit` / `_recommended_*` 等 #1 标记的死代码

### 3.3 人口系统

- `PlayerProgression.get_population_cap()` 及相关字段
- `Enums.Stat.POPULATION_BONUS`
- `PerkData.EffectType.POPULATION_FLAT`
- `resources/perks/expansion.tres` + `PerkManager.PERK_FILES` 引用
- `InventoryManager.can_buy_item` 的人口检查分支
- `BattleHUD` 人口显示
- `ExpConfig.initial_population` / `population_per_level` 字段
- `PlayerState.player_stats` 里人口相关字段

### 3.4 老角色 + 被动系统

- `resources/characters/dora.tres` / `gorg.tres` / `kaze.tres` / `merlin.tres` / `nemo.tres`
- `assets/characters/dora/` / `gorg/` / `kaze/` / `merlin/` / `nemo/`（整目录）
- `PlayerState.new_passive_id` / `new_passive_value` / `new_passive_value_2` / `passive_id` / `passive_evolution` / `pending_heal` 全部字段
- `Player.gd` 的 `_init_passives` / `_apply_passive_tier` / `_on_enemy_killed_heal` / `_process_passives` / `_get_dynamic_damage_mult` / `get_combo_damage_mult` / `update_combo_target` / `get_blood_rage_mult` / `_on_weapon_attack_executed` / `_count_fortify_units` + 相关字段（`_combo_target` / `_combo_stacks` / `_fortify_regen_timer` / `_passive_evolution` / `_current_passive_tier` / `_kill_heal_amount`）
- `CharacterData.passive_id` / `passive_evolution` 字段
- `scripts/resources/passive_evolution_data.gd`（如存在）
- `Enums.Stat.MELEE_DAMAGE_MULT` / `MELEE_ATTACK_SPEED_MULT`（只有老被动用）
- `character_selection` 场景逻辑

### 3.5 相关测试

- `tests/unit/` 和 `tests/integration/` 里涉及上述模块的测试全部移除或改写

---

## 四、新 Resource 类 / Resource 字段扩展

### 4.1 扩展 CharacterData

```gdscript
# 新增
@export var ability_scenes: Array[PackedScene]  # 按顺序挂到 Player 下的能力组件场景
@export var exp_config: ExpConfig               # 该角色专属经验曲线
@export var perk_pool: Array[PerkData]          # 该角色升级抽取池

# 保留
@export var id, display_name, portrait_path, sprite_frames_path
@export var sprite_pixel_size, max_hp, move_speed, starting_coins, character_color

# 删除
# passive_id, passive_evolution
```

### 4.2 扩展 PerkData

```gdscript
# 新增
@export var max_level: int = 5       # 可叠加次数上限
@export var category: Category       # 分类枚举（用于 4 类抽取）

enum Category {
    GENERIC,         # 通用（#1 的 6 个，不含已删 expansion）
    RANGER_GUST,     # 疾风箭方向（4 个）
    RANGER_RAIN,     # 箭雨方向（4 个）
    RANGER_MARK,     # 猎杀标记方向（4 个）
    RANGER_UTILITY,  # 游侠移动/生存方向（6 个）
}
```

### 4.3 新 Resource 类（`scripts/resources/hero_abilities/`）

**`AutoAttackData`** — 基础自动攻击
- `attack_range: float`
- `cooldown: float`（秒/发，与 `AttackConfigData.fire_rate_per_level` 单位一致）
- `damage: float`
- `projectile_scene: PackedScene`（复用 `arrow.tscn` 或新建 `ranger_arrow.tscn`）

**`GustArrowData`** — 疾风箭
- `trigger_distance: float`（累积多少 px 触发）
- `damage: float`
- `pierce_count: int`
- `slow_ratio: float`
- `slow_duration: float`
- `projectile_scene: PackedScene`

**`ArrowRainData`** — 箭雨
- `cooldown: float`
- `radius: float`
- `duration: float`
- `tick_interval: float`
- `damage_per_tick: float`
- `effect_scene: PackedScene`（AoE 视觉 + Hitbox 时序）

**`HuntMarkData`** — 猎杀标记
- `charge_per_kill: float`（普通敌人充能量）
- `charge_per_elite: float`（精英倍率，通常 5x）
- `charge_required: float`（满值）
- `mark_duration: float`
- `damage_multiplier: float`（默认 2.0）
- `kill_refund_ratio: float`（默认 0.5）

`.tres` 实例放 `resources/hero_abilities/ranger/`：`auto_attack.tres` / `gust_arrow.tres` / `arrow_rain.tres` / `hunt_mark.tres`

### 4.4 18 个游侠 perk（`resources/perks/ranger/`）

**疾风箭方向（4）**：
- `gust_interval_down.tres`（触发间距 -20%/级，max=5）
- `gust_fanshot.tres`（扇形三发，质变 max=1）
- `gust_pierce_plus.tres`（穿透 +1/级，max=3）
- `gust_bounce.tres`（命中弹射，质变 max=1）

**箭雨方向（4）**：
- `rain_radius.tres`（范围 +20%/级，max=5）
- `rain_dot_field.tres`（地面 DoT，质变 max=1）
- `rain_knockback.tres`（触发击退，质变 max=1）
- `rain_cooldown.tres`（冷却 -15%/级，max=5）

**猎杀标记方向（4）**：
- `mark_charge_speed.tres`（充能速度 +25%/级，max=5）
- `mark_duration.tres`（持续时间 +2s/级，max=3）
- `mark_chain.tres`（死亡跳转下一个，质变 max=1）
- `mark_self_damage.tres`（英雄对目标 +50%，质变 max=1）

**生存方向（6）**：
- `util_movespeed.tres`（移速 +10%/级，max=5）
- `util_move_shield.tres`（移动累积护盾，质变 max=2）
- `util_tower_heal.tres`（靠近塔回血，质变 max=1）
- `util_pickup_radius.tres`（拾取范围 +15%/级，max=5）
- `util_dodge.tres`（10% 闪避，质变 max=1）
- `util_coin_drop.tres`（击杀额外金币 +10%/级，max=3）

---

## 五、能力组件实现

4 个组件放 `scripts/components/hero_abilities/`，都继承 `Node`。Player `_ready` 从 `CharacterData.ability_scenes` 按顺序 instantiate，挂载到 `$Abilities` 容器（新增子节点做分组）。

### 5.1 通用约定

- 每个组件 `@export var data: <XxxData>` 挂对应 `.tres`
- 暴露 `_base_<参数>` 缓存原始值 + 运行时 `_current_<参数>`；perk 效果 = 重算 current
- 监听 `EventBus.perk_applied(perk_id)` → `_recalculate_params()`
- 内部持有 `_host: Node2D`（Player）在 `_ready` 通过 `get_parent().get_parent()` 拿到；非法时禁用自身
- 不直接引用 Player 字段，只读 `PlayerState.player_stats` 和 `_host.global_position`

### 5.2 AutoAttackComponent

- 组合 `TargetFinderComponent`（射程=`_current_range`，策略=NEAREST）+ 冷却计时器
- tick 到 `_current_cooldown` 后朝 target spawn `ranger_arrow`（直线 + 命中 Hitbox，不预判）
- 伤害 = `_current_damage * (1 + PlayerState.player_stats.get(Enums.Stat.DAMAGE_BONUS_PERCENT, 0.0))`
- 冷却受 `ATTACK_SPEED_BONUS_PERCENT` 缩短（`_current_cooldown = _base_cooldown / (1 + bonus)`）

### 5.3 GustArrowSkillComponent

- `_physics_process` 累积 `_host.global_position.distance_to(_last_pos)`
- ≥ `_current_trigger_distance` 时重置累计并触发（保留溢出跨帧）
- 触发：朝 `_host.velocity.normalized()` spawn 疾风箭；静止时跳过
- 疾风箭投射物场景：`LinearMovementComponent` + `PierceComponent`（穿透 N 个）+ `SlowOnHitComponent`
- perk 响应：
  - `gust_interval_down` → `trigger_distance *= (1 - 0.2 * level)`
  - `gust_pierce_plus` → `pierce_count += level`
  - `gust_fanshot` → 同帧补 ±15° 扇形（max=1 开关）
  - `gust_bounce` → 投射物运行时 add_child `BounceOnHitComponent`

### 5.4 ArrowRainSkillComponent

- `_cooldown_timer` 每帧 -delta，到 0 触发
- 触发流程：
  1. 找场上最近敌人位置（`enemies` 分组 + `Player.global_position` 距离筛选）
  2. 场上零敌人 → CD 保持满值（不重置），下帧有敌人立即释放
  3. 在敌人位置 spawn `arrow_rain_effect` 场景：`Area2D` + `CircleShape2D`（半径=`_current_radius`）+ 视觉 + Timer 每 `tick_interval` 广发伤害 + 总时长 `duration`
- perk 响应：
  - `rain_radius` → `radius *= (1 + 0.2 * level)`
  - `rain_cooldown` → `cooldown *= (1 - 0.15 * level)`
  - `rain_knockback` → 首次 tick 击退一次（标志位）
  - `rain_dot_field` → 箭雨结束后在原地留 dot_field 场景

### 5.5 HuntMarkSkillComponent

- 状态机：`IDLE` → `MARKED` → `IDLE`
- 充能：监听 `EventBus.enemy_killed`，`_charge += data.charge_per_kill`（精英 ×`charge_per_elite`）
- 满 `charge_required` → 扫 `enemies` 找 `current_hp` 最高的敌人
- 标记：`mark_indicator` 子节点挂到目标敌人（红箭头 Sprite + 闪烁 tween）
- 伤害放大：EventBus 广播 `hunt_mark_applied(enemy)` / `hunt_mark_cleared(enemy)`；通过 `enemy.set_meta("hunt_marked", true)`，受击时 `Hurtbox._on_area_entered` 或 `Enemy._apply_damage` 检查 meta 给伤害 ×`damage_multiplier`
- 结束：持续时间到 / 目标死亡 / 目标 despawn；击杀时返还 `kill_refund_ratio * charge_required`
- perk 响应：
  - `mark_charge_speed` → `charge_per_kill *= (1 + 0.25 * level)`
  - `mark_duration` → `mark_duration += 2 * level`
  - `mark_chain` → 目标死亡立即选下一个（质变）
  - `mark_self_damage` → 英雄对该目标伤害 +50%（发射时查询）

---

## 六、数据流

### 6.1 角色加载流程

```
character_selection（只显示 ranger + 5 占位）
  → PlayerState.current_character = "ranger"
  → main 场景加载地图
  → Player._ready():
      1. GameConfig.characters["ranger"] → CharacterData
      2. 读 max_hp / move_speed / starting_coins → 初始化基础属性
      3. 读 sprite_frames_path → SpriteAnimator 设置精灵
      4. 读 exp_config → 注入 PlayerProgression
      5. 读 perk_pool → 注入 PerkManager
      6. 读 ability_scenes → 逐个 instantiate 挂 $Abilities 下
      7. 连接 HealthComponent.died / Hurtbox / EventBus.perk_applied
```

### 6.2 PerkManager 改造

- `_all_perks` 从 `PlayerState.current_character` 的 `CharacterData.perk_pool` 加载（不再硬编码 `PERK_FILES`）
- `_perk_levels: Dictionary<perk_id, int>` 跟踪当前堆叠（`reset()` 清空）
- `_draw_three()` 改写：
  1. 从 4 类随机选 3 类
  2. 每类过滤出未满级 perk（`max_level` 限流）
  3. 每类随机抽 1 个
  4. 某类全满级则从剩余类补（兜底）
  5. 全部满级则 emit `no_perk_available`（走空流程）
- `_apply_effect()` 后 `_perk_levels[perk.id] += 1`
- `get_perk_level(perk_id) -> int` 供 UI 显示"[2/5]"

### 6.3 Perk 效果分两路

**数值型**（通用 stat bonus）：走现有 `PerkManager._apply_effect` 改写 `PlayerState.player_stats` → `EventBus.perk_applied` → Player 和组件各自重读

**能力专属**（gust_pierce_plus 等）：组件 `_on_perk_applied(perk_id)` 按约定 id 识别，调 `PerkManager.get_perk_level(perk_id)` 读当前堆叠，应用到私有状态。质变 perk 用 bool flag。

### 6.4 Roll 塔经济

```
点 Roll → TowerRollManager.roll()（扣 roll_cost）
  → UI 弹 3 张卡片 → 玩家选一 → InventoryManager.pending_towers.append
  → 玩家从 pending 拖到地图 → deploy_pending_tower(slot, grid_pos)
      buy_cost = tower_cost_base + tower_cost_per_same_type * N
          N = deployed_towers.count(id) + pending_towers.count(id) - 1
      金币不足 → 提示，塔退回 pending
      金币够 → 扣金币 + 实际放置
```

卖塔返还 `sell_return_ratio * buy_cost_at_this_n`（卖出前的 N）；卖出后同类塔 N 自动递减。

### 6.5 疾风箭运行时示例

```gdscript
_physics_process(delta):
    _accum += _host.global_position.distance_to(_last_pos)
    _last_pos = _host.global_position
    if _accum >= _current_trigger_distance:
        _accum -= _current_trigger_distance  # 保留溢出
        var dir = _host.velocity.normalized()
        if dir == Vector2.ZERO: return
        spawn_gust_arrow(dir)
        if _has_fanshot:
            spawn_gust_arrow(dir.rotated(deg_to_rad(15)))
            spawn_gust_arrow(dir.rotated(deg_to_rad(-15)))
```

---

## 七、UI 改动

### 7.1 BattleHUD

- **删**：装备栏、人口显示
- **改**：Roll 按钮旁显示 `roll_cost`；pending 队列显示保持
- **新增**：
  - 猎杀标记充能条（左上角 HP 旁，能量条样式）；激活时条变红 + 显示 `mark_duration` 倒计时
  - 箭雨 CD 指示器（图标 + 冷却圆环，CD 期间灰掉，准备好时高亮）
- 疾风箭无指示（距离触发，玩家自然感知）

### 7.2 PerkSelectionOverlay

- 每张 perk 卡片右上角小字 `[n/max]`（`max_level > 1` 时显示）
- 质变 perk 满级后由 `_draw_three` 过滤，不再出现
- 卡片仍是 icon + display_name + description

### 7.3 character_selection

- 5 张老卡片删除
- 1 张 ranger 居中展示 + 5 个"敬请期待"灰卡占位
- 点 ranger → `PlayerState.init_character("ranger")` → `map_select`

### 7.4 敌人头顶标记视觉

- 猎杀标记目标头顶加红色向下箭头 Sprite（`assets/ui/hunt_mark.png` 占位 = 纯红三角 Image 生成）
- `modulate.a` 闪烁 tween
- 目标消失 / 标记结束时销毁

---

## 八、错误处理 / 边界情况

### 8.1 能力组件容错

- `ability_scenes` 空 / entry null → `Player._ready` 跳过，`push_warning`
- 组件 `data` export 为 null → `_ready` `push_error`，`_enabled = false` 自禁用
- 非 Player 父级（测试场景）→ `get_parent().get_parent()` 兜底 `get_tree().current_scene`，仍无效则禁用

### 8.2 技能边界

**疾风箭**：静止（velocity = 0）跳过，累计距离不清零（跑起来立即放）

**箭雨**：
- 场上零敌人 → CD 保持满，下一帧有敌人立即释放
- 同帧多次 `_physics_process` 调用防御

**猎杀标记**：
- 目标标记期内死亡 + 无 `mark_chain` → 清标记 + 返还 50% 充能
- 目标 despawn（boss_escaped）→ 同上
- `mark_chain` 时场上无下一个目标 → 进 IDLE
- 标记激活时场上零敌人 → 延后到首个敌人出现

### 8.3 PerkManager 边界

- 全池满级 → emit `no_perk_available`，Overlay 显示"已到 build 上限"并自动关闭
- 4 类选 3 类时某类无可用 → 从剩余类补；再不够降级 2 选或 1 选
- `_perk_levels` 在 `reset()` 清空

### 8.4 塔经济边界

- `buy_cost` 超金币 → 部署时提示 + 塔退回 pending；Roll 本身不阻塞
- 卖塔返还按卖出前 N 算；卖出后所有同类塔 `buy_cost` 自动重算（纯函数）

### 8.5 其它

- **老角色存档兼容**：不做。旧 `current_character="dora"` 启动 main → `push_error` 强制跳回 character_selection
- **Resource null 兜底**：
  - `CharacterData.exp_config = null` → 后备 `GameConfig.exp_config`
  - `CharacterData.perk_pool = []` → `_all_perks` 空 → emit `no_perk_available`，不阻塞升级

---

## 九、测试策略

### 9.1 单元测试（`tests/unit/`）

1. `test_perk_manager_category.gd`（改写 `test_perk_manager.gd`）
   - 4 类分组抽 3 类各 1 个
   - `max_level` 限流
   - 全池满级 emit `no_perk_available`
   - `reset()` 清 `_perk_levels`

2. `test_perk_data_max_level.gd`
   - `max_level` 默认 5
   - `category` 枚举字段存在

3. `test_tower_cost_progression.gd`
   - `buy_cost = base + per_same_type * N`，N=0/1/2 正确
   - 卖塔后递减
   - pending 队列同类塔也计入 N

4. `test_auto_attack_component.gd`
   - tick 到 `fire_rate` 后 spawn
   - `ATTACK_SPEED_BONUS_PERCENT` 正确缩短间隔
   - target 空时不 spawn

5. `test_gust_arrow_component.gd`
   - 累积距离 ≥ `trigger_distance` 触发
   - 静止时不触发
   - 溢出距离保留
   - `fanshot` 开启时同帧 spawn 3 发

6. `test_arrow_rain_component.gd`
   - CD + 有敌人 → 在最近位置 spawn
   - 零敌人 CD 不重置
   - `rain_radius` perk 放大 Area2D

7. `test_hunt_mark_component.gd`
   - 充能：普通 +1，精英 ×5
   - 满充能锁定最高 HP
   - 击杀返还 50%
   - `mark_chain` 跳转逻辑

8. `test_character_data_abilities.gd`
   - `ability_scenes` / `exp_config` / `perk_pool` 字段存在
   - `ranger.tres` 挂 4 个能力

9. `test_inventory_no_weapons.gd`
   - `InventoryManager` 不再有 `deployed_weapons`（防回滚）

### 9.2 集成测试（`tests/integration/`）

1. `test_ranger_flow.gd`（改写 `test_perk_levelup_flow.gd`）
   - 升级 3 次 → 抽 3 类各 1 → 选一 → 效果应用
   - 升级至全池满级 → emit `no_perk_available`

2. `test_tower_roll_cost_progression.gd`
   - Roll + 部署 3 座同类 → 第 3 座价格递增
   - 卖第 2 座 → 第 3 座价格下降

### 9.3 手工验证清单

- [ ] character_selection 只显示 ranger 一张卡 + 5 个占位
- [ ] 选 ranger 进 main → 基础自动攻击打到最近敌人
- [ ] 移动触发疾风箭（方向正确 + 穿透 + 减速）
- [ ] 站 10s 不动 → 箭雨自动释放到最近敌人
- [ ] 连续击杀 30-40 杂兵 → 猎杀标记激活 + 血最高 + 伤害 2x
- [ ] 升级弹窗显示 3 类 perk + 堆叠等级
- [ ] 质变 perk 选过一次后不再出现
- [ ] Roll 3 座同类塔价格递增
- [ ] 完整 20 波跑通（含 4 个 Boss）不崩
- [ ] 英雄死亡 → 1s 延迟 → result 场景

---

## 十、验收标准

- 全套单元测试 + 集成测试通过（除已知 pre-existing failures）
- 手工 20 波完整跑通
- `InventoryManager` / `PlayerState` / `PerkManager` 中无废弃字段
- `character_selection` 只显示游侠 + 5 占位
- `develop` 分支增量 commit（继续不合并到 main，等 #3-#7 完成后统一合并）
