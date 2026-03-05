# 贡献指南

本文档面向团队成员，定义 utoland 项目的开发流程和代码规范。

详细设计见 [开发流程设计文档](docs/design/dev-workflow.md)。

## 快速参考

### Git 工作流

```bash
# 新功能
git checkout develop
git checkout -b feature/new-enemy-type
# ... 开发 ...
# 提交后发起 PR 到 develop

# Bug 修复
git checkout develop
git checkout -b fix/tower-placement-crash
# ... 修复 ...

# 紧急修复
git checkout main
git checkout -b hotfix/critical-crash
# ... 修复后合并回 main 和 develop
```

### 提交格式

```
feat: 新增毒塔类型
fix: 修复塔放置时碰撞检测失效
refactor: 重构敌人生成逻辑
test: 补充 WaveManager 单元测试
docs: 更新架构文档
chore: 更新 .gitignore
```

### 新增游戏实体检查清单

- [ ] `GameConfig` 中添加配置
- [ ] `scripts/entities/` 中创建脚本
- [ ] `scenes/` 对应目录创建场景
- [ ] `SceneFactory` 中注册 preload 和工厂方法
- [ ] `tests/unit/` 中编写测试

### 代码风格速查

| 类型 | 风格 | 示例 |
|------|------|------|
| 类名 | PascalCase | `Tower`, `WaveManager` |
| 函数/变量 | snake_case | `create_tower()`, `current_hp` |
| 常量 | UPPER_SNAKE_CASE | `WEAPONS`, `DEBUG_MODE` |
| 信号 | snake_case 过去式 | `wave_started`, `game_won` |
| 私有 | _ 前缀 | `_tower_scenes`, `_setup()` |
| 脚本文件 | snake_case.gd | `wave_manager.gd` |
| 场景文件 | snake_case.tscn | `enemy_normal.tscn` |
