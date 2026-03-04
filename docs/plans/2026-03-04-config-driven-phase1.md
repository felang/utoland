# 阶段 1：配置系统基础

**目标:** 创建 GameConfig 全局单例，定义所有游戏配置常量

**预计时间:** 30-45 分钟

---

## Task 1: 创建 GameConfig 单例文件

**Files:**
- Create: `game_config.gd`

**Step 1: 创建配置文件骨架**

在项目根目录创建 `game_config.gd`：

```gdscript
extends Node

# 配置驱动优化 - 游戏配置中心
# 所有游戏数值统一在此管理

# 开发模式开关
const DEBUG_MODE = true

# 武器配置
const WEAPONS = {}

# 敌人配置
const ENEMIES = {}

# 塔配置
const TOWERS = {}

# 波次配置
const WAVES = {}

# 玩家配置
const PLAYER = {}

# 商店配置
const SHOP = {}
```

**Step 2: 添加武器配置**

```gdscript
const WEAPONS = {
	"rifle": {
		"name": "步枪",
		"fire_rate": 0.1,
		"damage": 10.0,
		"bullet_count": 1,
		"bullet_speed": 600
	},
	"shotgun": {
		"name": "霰弹枪",
		"fire_rate": 0.6,  # 从 0.5 调整为 0.6（平衡性）
		"damage": 6.0,  # 从 8.0 调整为 6.0（平衡性）
		"bullet_count": 5,
		"spread_angles": [-7.5, -3.75, 0, 3.75, 7.5],
		"bullet_speed": 500
	},
	"sniper": {
		"name": "狙击枪",
		"fire_rate": 1.0,
		"damage": 30.0,
		"bullet_count": 1,
		"bullet_speed": 800
	}
}
```

**Step 3: 添加敌人配置**

```gdscript
const ENEMIES = {
	"normal": {
		"name": "普通敌人",
		"hp": 50.0,  # 从 30.0 提升
		"speed": 100.0,  # 从 80.0 提升
		"damage": 10.0,
		"coin_drop_min": 1,  # 从 2 降低
		"coin_drop_max": 3  # 从 5 降低
	},
	"fast": {
		"name": "快速敌人",
		"hp": 35.0,  # 从 20.0 提升
		"speed": 180.0,  # 从 150.0 提升
		"damage": 8.0,
		"coin_drop_min": 2,  # 从 3 降低
		"coin_drop_max": 4  # 从 6 降低
	},
	"tank": {
		"name": "坦克敌人",
		"hp": 200.0,  # 从 100.0 翻倍
		"speed": 50.0,
		"damage": 25.0,  # 从 20.0 提升
		"coin_drop_min": 5,
		"coin_drop_max": 10
	}
}
```

**Step 4: 添加塔配置**

```gdscript
const TOWERS = {
	"shooter": {
		"name": "射手塔",
		"hp": 80.0,
		"damage": 15.0,
		"fire_rate": 1.0,
		"range": 300.0,
		"shop_price_min": 35,  # 从 25 提升
		"shop_price_max": 45  # 从 30 提升
	},
	"wall": {
		"name": "墙塔",
		"hp": 300.0,
		"shop_price_min": 35,  # 从 25 提升
		"shop_price_max": 45  # 从 30 提升
	},
	"slow": {
		"name": "减速塔",
		"hp": 70.0,
		"range": 200.0,
		"slow_percent": 0.3,
		"shop_price_min": 35,  # 从 25 提升
		"shop_price_max": 45  # 从 30 提升
	}
}
```

**Step 5: 添加波次配置**

```gdscript
const WAVES = {
	"total_waves": 10,
	"wave_configs": [
		{"duration": 45, "spawn_interval": 1.5, "enemy_types": ["normal"]},
		{"duration": 45, "spawn_interval": 1.5, "enemy_types": ["normal"]},
		{"duration": 50, "spawn_interval": 1.0, "enemy_types": ["normal", "fast"]},
		{"duration": 50, "spawn_interval": 1.0, "enemy_types": ["normal", "fast"]},
		{"duration": 55, "spawn_interval": 1.0, "enemy_types": ["normal", "fast"]},
		{"duration": 55, "spawn_interval": 0.8, "enemy_types": ["normal", "fast", "tank"]},
		{"duration": 60, "spawn_interval": 0.8, "enemy_types": ["normal", "fast", "tank"]},
		{"duration": 60, "spawn_interval": 0.8, "enemy_types": ["normal", "fast", "tank"]},
		{"duration": 60, "spawn_interval": 0.5, "enemy_types": ["normal", "fast", "tank"]},
		{"duration": 60, "spawn_interval": 0.5, "enemy_types": ["normal", "fast", "tank"]}
	]
}
```

**Step 6: 添加玩家和商店配置**

```gdscript
const PLAYER = {
	"initial_hp": 100.0,
	"initial_speed": 200.0,
	"initial_coins": 100,
	"hp_regen_interval": 5.0
}

const SHOP = {
	"refresh_cost": 10,
	"item_count": 4,
	"passive_price_min": 20,  # 从 15 提升
	"passive_price_max": 40,  # 从 30 提升
	"heal_price": 12,
	"heal_amount": 50
}
```

**Step 7: 测试配置文件语法**

运行 Godot 编辑器，检查是否有语法错误：
- 打开 Godot 编辑器
- 打开 `game_config.gd` 文件
- 查看输出面板是否有错误

预期：无语法错误

**Step 8: 提交**

```bash
git add game_config.gd
git commit -m "feat: 创建 GameConfig 配置中心"
```

---

## Task 2: 注册 GameConfig 为自动加载单例

**Files:**
- Modify: `project.godot`

**Step 1: 在 Godot 编辑器中添加自动加载**

1. 打开 Godot 编辑器
2. 点击菜单：项目 -> 项目设置
3. 选择"自动加载"标签
4. 点击"添加"按钮
5. 路径：`res://game_config.gd`
6. 节点名称：`GameConfig`
7. 勾选"启用"
8. 点击"添加"

**Step 2: 验证自动加载**

在 `project.godot` 文件中应该看到：

```ini
[autoload]

GameData="*res://scripts/game_data.gd"
GDAIMCPRuntime="*uid://dcne7ryelpxmn"
GameConfig="*res://game_config.gd"
```

**Step 3: 测试配置访问**

创建临时测试脚本验证配置可访问：

在任意现有脚本（如 `scripts/main.gd`）的 `_ready()` 函数中临时添加：

```gdscript
func _ready():
	print("=== 测试 GameConfig ===")
	print("步枪伤害: ", GameConfig.WEAPONS["rifle"]["damage"])
	print("普通敌人血量: ", GameConfig.ENEMIES["normal"]["hp"])
	print("射手塔射程: ", GameConfig.TOWERS["shooter"]["range"])
	# ... 原有代码
```

运行游戏，查看输出：

预期输出：
```
=== 测试 GameConfig ===
步枪伤害: 10
普通敌人血量: 50
射手塔射程: 300
```

**Step 4: 移除测试代码**

删除刚才添加的测试代码，恢复原样。

**Step 5: 提交**

```bash
git add project.godot scripts/main.gd
git commit -m "feat: 注册 GameConfig 为自动加载单例"
```

---

## 阶段 1 验收

- [ ] `game_config.gd` 文件创建成功
- [ ] 所有配置常量定义完整
- [ ] GameConfig 注册为自动加载单例
- [ ] 可以通过 `GameConfig.WEAPONS` 等访问配置
- [ ] 无语法错误
- [ ] 提交 2 次

**下一步:** 执行阶段 2 - 核心系统重构
