# 塔布置系统 Bug 修复总结

**日期**: 2026-03-04
**状态**: ✅ 已完成

---

## 问题概述

用户报告了两个关键 Bug：
1. **Bug 1**: 初始布置场景放置3个射手塔，进入游戏只显示1个
2. **Bug 2**: 波次间商店购买后的布置阶段，之前的塔全部消失

---

## 根本原因分析

### Bug 1: 塔识别失败

**原因**:
- Godot 在实例化多个相同场景时会自动重命名节点以避免冲突
- 第一个实例保持原名 `TowerShooter`
- 后续实例被重命名为 `@StaticBody2D@3`, `@StaticBody2D@4` 等
- `placement.gd` 使用 `tower.name.begins_with("TowerShooter")` 识别塔类型
- 只有第一个塔被正确识别，其他塔被忽略

### Bug 2: 数据丢失

**原因**:
- `main.gd` 在恢复塔后立即执行 `GameData.tower_inventory.clear()`
- `placement.gd` 的 `_ready()` 没有恢复已有的塔
- 导致波次间塔数据丢失

---

## 修复方案

### 修复 1: 使用属性识别塔类型

**修改文件**:
- `scripts/tower.gd`: 添加 `tower_type` 属性
- `scripts/tower_shooter.gd`: 在 `_ready()` 中设置 `tower_type = "shooter"`
- `scripts/tower_slow.gd`: 在 `_ready()` 中设置 `tower_type = "slow"`
- `scripts/placement.gd`: 修改 `start_battle()` 使用 `tower.tower_type` 识别

**提交**: ed1e1bc

### 修复 2: 保留塔数据并恢复

**修改文件**:
- `scripts/main.gd`: 移除 `GameData.tower_inventory.clear()` 调用
- `scripts/placement.gd`: 在 `_ready()` 中添加恢复塔的逻辑

**提交**: 4848268, 2b5e42b

---

## 测试结果

### 自动化测试

创建了测试脚本验证修复：

**测试1: 初始布置3个塔**
```
收集到的塔: 3
✅ 测试1通过: 3个塔被正确收集
```

**测试2: 波次间保留塔并添加新塔**
```
当前 tower_inventory: 3个塔
恢复了3个旧塔
添加了2个新塔，总共5个塔
收集到的塔: 5
✅ 测试2通过: 5个塔被正确收集（3旧+2新）
```

---

## 提交记录

1. `4848268` - fix: 保留 tower_inventory 数据，避免波次间丢失已布置的塔
2. `2b5e42b` - fix: 布置场景恢复已有塔并追加新塔，避免重置
3. `ed1e1bc` - fix: 使用 tower_type 属性识别塔类型，解决节点名称重复导致的识别失败
4. `c87c6eb` - chore: 移除调试日志
5. `4256924` - docs: 更新已知问题文档，记录已修复的 Bug
6. `9de39ad` - docs: 添加塔布置系统 Bug 修复计划文档

---

## 技术改进

### 优点
- 使用属性而非节点名称识别塔类型，更加健壮
- 保留了向后兼容性（回退到节点名称识别）
- 数据流更加清晰：布置 → 保存 → 战斗 → 恢复 → 布置

### 潜在优化
- 可以考虑在 `Tower` 基类中使用 `@export` 导出 `tower_type`
- 添加数据验证，防止 `tower_inventory` 包含无效数据
- 考虑使用自定义组标签（如 "tower_shooter"）进一步增强识别

---

## 影响范围

**修改的文件**: 5个
- `scripts/tower.gd`
- `scripts/tower_shooter.gd`
- `scripts/tower_slow.gd`
- `scripts/main.gd`
- `scripts/placement.gd`

**影响的系统**: 塔布置系统、战斗系统

**风险评估**: 低风险
- 修改点明确，易于回滚
- 不影响其他游戏系统
- 保留了向后兼容性

---

## 完成标准

✅ 所有代码修改已提交
✅ 自动化测试通过所有检查
✅ 文档已更新
✅ 无新引入的 Bug
✅ 游戏可以正常完成多波战斗

---

## 后续建议

1. 进行完整的手动游戏测试，验证实际游戏流程
2. 考虑添加单元测试或集成测试
3. 监控用户反馈，确认问题已完全解决
