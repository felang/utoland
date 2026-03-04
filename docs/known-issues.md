# 已知问题清单

**最后更新**: 2026-03-04
**项目**: Utoland
**版本**: MVP v0.3.1

---

## 已修复问题

### 1. 初始布置多个塔只显示一个 ✅
**修复日期**: 2026-03-04
**优先级**: Critical

**问题描述**:
在初始布置场景放置多个塔后，进入战斗场景时只显示一个塔。

**根本原因**:
当同一个场景被多次实例化时，Godot 会自动重命名后续实例以避免名称冲突（如 `@StaticBody2D@3`）。`placement.gd` 的 `start_battle()` 函数使用节点名称（`tower.name.begins_with("TowerShooter")`）来识别塔类型，导致只有第一个塔被正确识别。

**修复方案**:
1. 在 `Tower` 基类中添加 `tower_type` 属性
2. 在各塔子类的 `_ready()` 中设置对应的类型值
3. 修改 `placement.gd` 的 `start_battle()` 使用 `tower.tower_type` 属性识别塔类型

**相关提交**: ed1e1bc

---

### 2. 波次间布置重置已有塔 ✅
**修复日期**: 2026-03-04
**优先级**: Critical

**问题描述**:
完成第一波战斗后，进入商店购买塔，再进入布置场景时，之前布置的所有塔都消失了。

**根本原因**:
1. `main.gd` 在恢复塔后立即清空 `GameData.tower_inventory`
2. `placement.gd` 的 `_ready()` 没有恢复已有的塔

**修复方案**:
1. 移除 `main.gd` 中的 `GameData.tower_inventory.clear()` 调用
2. 在 `placement.gd` 的 `_ready()` 中添加恢复已有塔的逻辑
3. 修改 `start_battle()` 收集场景中所有塔（包括旧的和新的）

**相关提交**: 4848268, 2b5e42b

---

## Important 级别

### 1. 霰弹枪伤害平衡问题
**优先级**: High
**发现时间**: 2026-03-03 (Task 7 代码审查)

**问题描述**:
霰弹枪的 DPS 过高，与其他武器不平衡。

**详细分析**:
- 霰弹枪: 单发伤害 8.0 × 5发 = 40.0，射速 0.5s，DPS = 80
- 步枪: 单发伤害 10.0，射速 0.1s，DPS = 100
- 狙击枪: 单发伤害 30.0，射速 1.0s，DPS = 30

虽然步枪 DPS 更高，但霰弹枪的爆发伤害和范围优势使其在实战中可能过强。

**位置**: `scripts/player.gd:34-35`

**建议修复**:
- 方案1: 降低霰弹枪单发伤害到 5.0-6.0
- 方案2: 增加霰弹枪射速到 0.6-0.7s
- 方案3: 减少子弹数量到 3-4发

**影响范围**: 游戏平衡性

---

### 2. 生命回复计时器未重置
**优先级**: Medium
**发现时间**: 2026-03-03 (Task 7 代码审查)

**问题描述**:
玩家死亡重生后，`hp_regen_timer` 不会重置，可能导致玩家重生后立即触发回复。

**位置**: `scripts/player.gd:14, 51-56`

**当前代码**:
```gdscript
var hp_regen_timer: float = 0.0  # 在类级别声明

func _process(delta):
    # 生命回复
    if GameData.player_stats["hp_regen"] > 0:
        hp_regen_timer += delta
        if hp_regen_timer >= 5.0:
            current_hp = min(current_hp + GameData.player_stats["hp_regen"], max_hp)
            hp_regen_timer = 0.0
```

**建议修复**:
在 `_ready()` 中初始化：
```gdscript
func _ready():
    hp_regen_timer = 0.0
    # ... 其他初始化代码
```

**影响范围**: 玩家体验（轻微）

---

## Minor 级别

### 3. 魔法数字硬编码
**优先级**: Low
**发现时间**: 2026-03-03 (Task 7 代码审查)

**问题描述**:
武器参数和霰弹枪扩散角度硬编码在代码中，不便于调整和维护。

**位置**:
- `scripts/player.gd:22-31` (武器基础数据)
- `scripts/player.gd:121` (霰弹枪扩散角度)

**建议修复**:
提取为常量或配置字典：
```gdscript
const WEAPON_CONFIGS = {
    "rifle": {"fire_rate": 0.1, "damage": 10.0, "bullet_count": 1},
    "shotgun": {"fire_rate": 0.5, "damage": 8.0, "bullet_count": 5},
    "sniper": {"fire_rate": 1.0, "damage": 30.0, "bullet_count": 1}
}
const SHOTGUN_SPREAD_ANGLES = [-7.5, -3.75, 0, 3.75, 7.5]
```

**影响范围**: 代码可维护性

---

### 4. 塔类型识别脆弱
**优先级**: Low
**发现时间**: 2026-03-03 (Task 6 代码审查)

**问题描述**:
通过节点名称前缀判断塔类型，如果场景实例化时名称变化会失败。

**位置**: `scripts/placement.gd:109-114`

**当前代码**:
```gdscript
if tower.name.begins_with("TowerShooter"):
    tower_type = "shooter"
elif tower.name.begins_with("TowerWall"):
    tower_type = "wall"
```

**建议修复**:
在塔脚本中添加 `tower_type` 属性：
```gdscript
# tower_shooter.gd
var tower_type: String = "shooter"

# placement.gd
var tower_type = tower.tower_type
```

**影响范围**: 代码健壮性

---

### 5. 缺少边界检查
**优先级**: Low
**发现时间**: 2026-03-03 (Task 6 代码审查)

**问题描述**:
恢复塔时没有验证 `tower_data` 结构完整性，如果数据损坏会导致崩溃。

**位置**: `scripts/main.gd:6-20`

**建议修复**:
添加数据验证：
```gdscript
for tower_data in GameData.tower_inventory:
    if not tower_data.has("type") or not tower_data.has("position"):
        continue  # 跳过无效数据

    var tower_type = tower_data["type"]
    var tower_pos = tower_data["position"]
    # ... 继续处理
```

**影响范围**: 代码健壮性

---

### 6. 代码注释不足
**优先级**: Low
**发现时间**: 2026-03-03 (Task 7 代码审查)

**问题描述**:
关键逻辑变更缺少注释说明，不利于后续维护。

**位置**:
- `scripts/result.gd:4` (胜利条件从 >= 10 改为 > 10)
- `scripts/enemy.gd:70` (金币掉落数量调整)
- `scripts/shop_manager.gd:6-21` (商店价格调整)

**建议修复**:
添加说明性注释：
```gdscript
# 需要完成第10波才算胜利（current_wave在第10波结束后变为11）
if GameData.current_wave > 10:
```

**影响范围**: 代码可维护性

---

## 待确认问题

### 7. 塔类型识别已优化 ✅
**优先级**: 已解决
**发现时间**: 2026-03-03
**解决时间**: 2026-03-04

**问题描述**:
之前通过节点名称前缀判断塔类型，如果场景实例化时名称变化会失败。

**解决方案**:
已在修复 Bug 1 时一并解决，现在使用 `tower_type` 属性识别塔类型。

---

## 问题统计

- **已修复**: 2
- **Important 级别**: 2
- **Minor 级别**: 4
- **总计**: 8

---

## 修复优先级建议
   - 霰弹枪伤害平衡
   - 生命回复计时器重置

3. **中期优化** (有时间时):
   - 魔法数字提取
   - 塔类型识别改进
   - 边界检查添加
   - 代码注释补充

---

## 相关文档

- `docs/project-status.md` - 项目当前状态
- `docs/phase3-implementation-summary.md` - 阶段3实施总结
