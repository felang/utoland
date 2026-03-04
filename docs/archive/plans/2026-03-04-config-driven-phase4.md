# 阶段 4：难度平衡调整

**目标:** 使用调试工具测试和调整游戏难度，达到理想平衡

**预计时间:** 30-60 分钟

---

## Task 12: 初步难度测试

**Files:**
- 无需修改代码，纯测试阶段

**Step 1: 完整游戏流程测试**

运行游戏，完整体验从第 1 波到第 10 波：

测试要点：
- 记录每波的难度感受
- 记录死亡波次（如果有）
- 记录通关时的剩余血量和金币
- 记录哪些武器/塔最有用

**Step 2: 使用调试工具快速测试**

使用 F3 跳波功能，快速测试不同波次：

```
测试波次 1-3: 是否太简单？
测试波次 4-6: 难度递增是否合理？
测试波次 7-9: 是否有足够挑战？
测试波次 10: 最终波是否够刺激？
```

**Step 3: 记录测试数据**

创建测试记录文件 `docs/balance-test-log.md`：

```markdown
# 难度平衡测试记录

## 测试 1 - 初始配置
**日期:** 2026-03-04
**武器:** 步枪
**结果:** 第 X 波死亡 / 通关
**剩余血量:** XX/100
**剩余金币:** XXX
**感受:** 太简单/合适/太难

## 测试 2 - 调整后
...
```

**Step 4: 分析测试结果**

根据测试结果，确定需要调整的方向：
- 敌人是否需要更强？
- 金币获取是否太多？
- 商店价格是否太便宜？
- 武器平衡是否合理？

---

## Task 13: 调整敌人数值

**Files:**
- Modify: `game_config.gd`

**Step 1: 根据测试结果调整敌人配置**

如果游戏太简单，可以这样调整：

```gdscript
const ENEMIES = {
	"normal": {
		"name": "普通敌人",
		"hp": 60.0,  # 从 50.0 提升到 60.0
		"speed": 110.0,  # 从 100.0 提升到 110.0
		"damage": 12.0,  # 从 10.0 提升到 12.0
		"coin_drop_min": 1,
		"coin_drop_max": 3
	},
	"fast": {
		"name": "快速敌人",
		"hp": 40.0,  # 从 35.0 提升到 40.0
		"speed": 200.0,  # 从 180.0 提升到 200.0
		"damage": 10.0,  # 从 8.0 提升到 10.0
		"coin_drop_min": 2,
		"coin_drop_max": 4
	},
	"tank": {
		"name": "坦克敌人",
		"hp": 250.0,  # 从 200.0 提升到 250.0
		"speed": 50.0,
		"damage": 30.0,  # 从 25.0 提升到 30.0
		"coin_drop_min": 5,
		"coin_drop_max": 10
	}
}
```

**Step 2: 使用热重载测试**

1. 修改 `game_config.gd` 中的数值
2. 保存文件
3. 在游戏中按 F9 重载配置
4. 按 F5 生成测试敌人
5. 观察新数值效果

**Step 3: 迭代调整**

重复以下循环直到满意：
1. 调整配置数值
2. F9 热重载
3. F3 跳到目标波次测试
4. 记录测试结果
5. 继续调整

**Step 4: 提交最终配置**

```bash
git add game_config.gd
git commit -m "balance: 调整敌人数值提升难度"
```

---

## Task 14: 调整经济系统

**Files:**
- Modify: `game_config.gd`

**Step 1: 调整金币掉落**

如果金币获取太容易：

```gdscript
const ENEMIES = {
	"normal": {
		# ...
		"coin_drop_min": 1,  # 保持或降低
		"coin_drop_max": 2  # 从 3 降低到 2
	},
	# ... 其他敌人类似调整
}
```

**Step 2: 调整商店价格**

如果商店物品太便宜：

```gdscript
const SHOP = {
	"refresh_cost": 15,  # 从 10 提升到 15
	"item_count": 4,
	"passive_price_min": 25,  # 从 20 提升到 25
	"passive_price_max": 50,  # 从 40 提升到 50
	"heal_price": 15,  # 从 12 提升到 15
	"heal_amount": 50
}

const TOWERS = {
	"shooter": {
		# ...
		"shop_price_min": 40,  # 从 35 提升到 40
		"shop_price_max": 50  # 从 45 提升到 50
	},
	# ... 其他塔类似调整
}
```

**Step 3: 测试经济平衡**

1. F9 重载配置
2. 完整游玩几波
3. 观察金币获取和消耗是否平衡
4. 确保玩家需要做出选择（不能买所有东西）

**Step 4: 提交**

```bash
git add game_config.gd
git commit -m "balance: 调整经济系统收紧资源"
```

---

## Task 15: 调整波次难度曲线

**Files:**
- Modify: `game_config.gd`

**Step 1: 优化生成间隔**

如果敌人压力不够：

```gdscript
const WAVES = {
	"total_waves": 10,
	"wave_configs": [
		{"duration": 45, "spawn_interval": 1.2, "enemy_types": ["normal"]},  # 从 1.5 降低
		{"duration": 45, "spawn_interval": 1.2, "enemy_types": ["normal"]},
		{"duration": 50, "spawn_interval": 0.8, "enemy_types": ["normal", "fast"]},  # 从 1.0 降低
		{"duration": 50, "spawn_interval": 0.8, "enemy_types": ["normal", "fast"]},
		{"duration": 55, "spawn_interval": 0.8, "enemy_types": ["normal", "fast"]},
		{"duration": 55, "spawn_interval": 0.6, "enemy_types": ["normal", "fast", "tank"]},  # 从 0.8 降低
		{"duration": 60, "spawn_interval": 0.6, "enemy_types": ["normal", "fast", "tank"]},
		{"duration": 60, "spawn_interval": 0.6, "enemy_types": ["normal", "fast", "tank"]},
		{"duration": 60, "spawn_interval": 0.4, "enemy_types": ["normal", "fast", "tank"]},  # 从 0.5 降低
		{"duration": 60, "spawn_interval": 0.3, "enemy_types": ["normal", "fast", "tank"]}  # 从 0.5 降低
	]
}
```

**Step 2: 测试波次曲线**

使用 F3 快速跳波测试：
- 前期（1-3波）：应该轻松，让玩家熟悉
- 中期（4-6波）：开始有压力，需要策略
- 后期（7-9波）：高压力，需要良好的布局
- 最终波（10波）：极限挑战

**Step 3: 提交**

```bash
git add game_config.gd
git commit -m "balance: 优化波次难度曲线"
```

---

## Task 16: 武器平衡调整

**Files:**
- Modify: `game_config.gd`

**Step 1: 测试三种武器**

分别使用三种武器完整游玩：
- 步枪：是否太弱/太强？
- 霰弹枪：是否仍然过强？
- 狙击枪：是否实用？

**Step 2: 微调武器数值**

根据测试结果调整：

```gdscript
const WEAPONS = {
	"rifle": {
		"name": "步枪",
		"fire_rate": 0.1,
		"damage": 12.0,  # 可能需要提升
		"bullet_count": 1,
		"bullet_speed": 600
	},
	"shotgun": {
		"name": "霰弹枪",
		"fire_rate": 0.7,  # 从 0.6 进一步降低射速
		"damage": 6.0,  # 保持较低伤害
		"bullet_count": 5,
		"spread_angles": [-7.5, -3.75, 0, 3.75, 7.5],
		"bullet_speed": 500
	},
	"sniper": {
		"name": "狙击枪",
		"fire_rate": 0.9,  # 从 1.0 略微提升射速
		"damage": 35.0,  # 从 30.0 提升伤害
		"bullet_count": 1,
		"bullet_speed": 800
	}
}
```

**Step 3: 验证平衡性**

确保三种武器各有特色：
- 步枪：稳定输出，适合新手
- 霰弹枪：近战爆发，需要走位
- 狙击枪：高伤害，适合精准打击

**Step 4: 提交**

```bash
git add game_config.gd
git commit -m "balance: 调整武器平衡性"
```

---

## Task 17: 最终测试和文档

**Files:**
- Create: `docs/balance-final-report.md`

**Step 1: 完整通关测试**

使用三种武器分别完整通关：
- 记录每次的体验
- 记录通关难度
- 记录是否有明显的不平衡

**Step 2: 编写平衡报告**

创建 `docs/balance-final-report.md`：

```markdown
# 难度平衡最终报告

**日期:** 2026-03-04
**版本:** v0.4

## 测试总结

### 步枪测试
- 通关难度: 中等
- 剩余血量: XX/100
- 剩余金币: XXX
- 评价: ...

### 霰弹枪测试
- 通关难度: ...
- 评价: ...

### 狙击枪测试
- 通关难度: ...
- 评价: ...

## 最终配置

### 敌人数值
- 普通敌人: HP 60, 速度 110, 伤害 12
- 快速敌人: HP 40, 速度 200, 伤害 10
- 坦克敌人: HP 250, 速度 50, 伤害 30

### 经济系统
- 金币掉落: 减少 30-50%
- 商店价格: 提升 50-100%

### 波次难度
- 生成间隔: 从 1.5s 降低到 0.3s（第10波）
- 难度曲线: 平滑递增

## 结论

游戏难度已从"偏简单"调整到"中等偏难"，三种武器基本平衡，经济系统需要玩家做出选择。
```

**Step 3: 更新项目状态文档**

修改 `docs/project-status.md`，更新版本号和完成内容：

```markdown
**当前版本**: MVP v0.4
**最后更新**: 2026-03-04

## 最新更新

### v0.4 - 配置驱动优化 (2026-03-04)
- ✅ 创建 GameConfig 配置中心
- ✅ 重构所有系统使用配置
- ✅ 实现调试工具和快捷键
- ✅ 配置热重载功能
- ✅ 难度平衡调整
```

**Step 4: 提交最终文档**

```bash
git add docs/balance-final-report.md docs/project-status.md
git commit -m "docs: 添加难度平衡最终报告"
```

---

## 阶段 4 验收

- [ ] 完成至少 3 次完整通关测试
- [ ] 三种武器平衡性合理
- [ ] 游戏难度达到"中等"水平
- [ ] 经济系统需要玩家做出选择
- [ ] 波次难度曲线平滑递增
- [ ] 编写平衡测试报告
- [ ] 更新项目文档

---

## 全部阶段完成

恭喜！配置驱动优化已全部完成。

### 成果总结

1. **配置系统**: GameConfig 单例管理所有游戏数值
2. **代码重构**: 消除硬编码，提升可维护性
3. **调试工具**: F1-F12 快捷键，调试面板，热重载
4. **难度平衡**: 从"偏简单"调整到"中等偏难"

### 下一步建议

1. **短期**: 继续微调数值，收集更多测试反馈
2. **中期**: 添加更多内容（新武器、新敌人、新塔）
3. **长期**: 准备美术资源集成

### 技术债务

- 调试面板 UI 较简陋（功能优先）
- 配置热重载可能不完全（部分需要重启场景）
- 缺少自动化测试

这些可以在后续迭代中逐步改进。
