# Phase 4: Cleanup & Documentation - Implementation Plan

> **For Claude:** Execute tasks sequentially. Focus on cleanup and documentation quality.

**Goal:** Remove test scene clutter, update documentation, finalize standards

**Estimated Time:** ~2 hours

---

## Task 1: Identify and Delete Test Scenes

**Files:**
- Delete: All `test_*.tscn` files

### Step 1: Find all test scenes

```bash
find . -name "test_*.tscn" -type f
```

Expected output: List of test scene files

### Step 2: List test scenes for review

```bash
ls -la scenes/ | grep test
ls -la . | grep test
```

### Step 3: Delete test scenes

```bash
rm -f test_*.tscn
rm -f scenes/test_*.tscn
```

### Step 4: Verify deletion

```bash
find . -name "test_*.tscn" -type f
# Expected: No output
```

### Step 5: Commit

```bash
git add -A
git commit -m "cleanup: remove test scene files"
```

---

## Task 2: Create Development Playground Scene

**Files:**
- Create: `dev_playground.tscn`

### Step 1: Create playground scene with MCP

```
mcp__gdai-mcp__create_scene("res://dev_playground.tscn", "Node2D")
```

### Step 2: Add basic nodes for testing

```
mcp__gdai-mcp__open_scene("res://dev_playground.tscn")
mcp__gdai-mcp__add_node(".", "Label", "InfoLabel")
mcp__gdai-mcp__update_property("InfoLabel", "text", "Development Playground - For Manual Testing Only")
```

### Step 3: Add to .gitignore

```bash
echo "dev_playground.tscn" >> .gitignore
```

### Step 4: Verify .gitignore works

```bash
git status
# Expected: dev_playground.tscn should not appear
```

### Step 5: Commit .gitignore

```bash
git add .gitignore
git commit -m "chore: add dev_playground.tscn to .gitignore"
```

---

## Task 3: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

### Step 1: Add MCP-First Architecture section

Add after "## Key Architecture":

```markdown
### MCP-First Development Workflow

**Core Principle:** Treat .tscn files as build artifacts, not source code.

**Scene Modification Rules:**
- ✅ Use MCP tools: `mcp__gdai-mcp__add_node`, `mcp__gdai-mcp__update_property`, etc.
- ❌ Never manually edit .tscn files in text editor
- ❌ Never use Godot editor to modify scene structure (use for visual preview only)

**Scene Creation Pattern:**
1. Use `mcp__gdai-mcp__create_scene()` to create scene
2. Use `mcp__gdai-mcp__attach_script()` to attach script
3. Use `mcp__gdai-mcp__add_node()` to add child nodes
4. Use `mcp__gdai-mcp__update_property()` to set properties

**Why This Matters:**
- Consistent, reproducible scene modifications
- AI-friendly development workflow
- Clean git diffs (no .tscn noise)
- Prevents merge conflicts
```

### Step 2: Add SceneFactory section

Add after MCP-First section:

```markdown
### SceneFactory Pattern

**All scene instantiation goes through SceneFactory.**

**Location:** `scripts/core/scene_factory.gd`

**Usage Examples:**

```gdscript
# Create tower
var tower = SceneFactory.create_tower("shooter")
add_child(tower)

# Get tower cost
var cost = SceneFactory.get_tower_cost("shooter")

# Create enemy
var enemy = SceneFactory.create_enemy("normal")
add_child(enemy)

# Create bullet
var bullet = SceneFactory.create_bullet()
add_child(bullet)
```

**Anti-Pattern:**
```gdscript
# ❌ Don't do this
var tower_scene = preload("res://scenes/towers/tower_shooter.tscn")
var tower = tower_scene.instantiate()

# ✅ Do this instead
var tower = SceneFactory.create_tower("shooter")
```
```

### Step 3: Add Testing section

Add after SceneFactory section:

```markdown
### Testing with GUT

**Framework:** GUT (Godot Unit Test)

**Test Locations:**
- `tests/unit/` - Unit tests (individual components)
- `tests/integration/` - Integration tests (system interactions)

**Running Tests:**
- In Godot: Tools → Gut → Run All Tests
- Command line: (if configured) `godot --headless -s addons/gut/gut_cmdln.gd`

**Test Coverage:**
- ✅ SceneFactory (100% coverage)
- ✅ GameConfig validation
- ✅ GameData state transitions
- ✅ Tower placement logic
- ✅ Wave system

**Writing Tests:**

```gdscript
extends GutTest

func test_example():
    var result = SceneFactory.create_tower("shooter")
    assert_not_null(result)
    result.queue_free()
```
```

### Step 4: Update Project Structure section

Replace existing structure with:

```markdown
## Project Structure

```
utoland/
├── scripts/
│   ├── core/                    # Core systems
│   │   ├── game_data.gd        # Global state management
│   │   └── scene_factory.gd    # Centralized scene instantiation
│   ├── entities/                # Game entities
│   │   ├── player.gd
│   │   ├── enemy.gd
│   │   ├── bullet.gd
│   │   ├── coin.gd
│   │   └── towers/
│   │       ├── tower.gd
│   │       ├── tower_shooter.gd
│   │       └── tower_slow.gd
│   ├── systems/                 # Game systems
│   │   ├── wave_manager.gd
│   │   ├── enemy_spawner.gd
│   │   └── shop_manager.gd
│   └── ui/                      # UI controllers
│       ├── start_menu.gd
│       ├── character_selection.gd
│       ├── weapon_select.gd
│       ├── map_select.gd
│       ├── placement.gd
│       ├── main.gd
│       ├── hud.gd
│       └── result.gd
├── scenes/                      # Scene files (MCP-managed)
│   ├── entities/
│   ├── towers/
│   ├── enemies/
│   └── ui/
├── tests/                       # GUT tests
│   ├── unit/
│   └── integration/
├── .claude/
│   └── rules/                   # Development rules
│       ├── mcp-only.md
│       ├── no-hardcode.md
│       ├── scene-factory.md
│       └── testing.md
├── game_config.gd              # Configuration center
└── project.godot               # Godot project file
```
```

### Step 5: Add Development Rules reference

Add at the end:

```markdown
## Development Rules

Detailed development rules are documented in `.claude/rules/`:

- **mcp-only.md** - MCP tool usage for scene modifications
- **no-hardcode.md** - Zero hardcoded values policy
- **scene-factory.md** - Scene factory pattern usage
- **testing.md** - Testing requirements and guidelines

**Quick Reference:**
- ✅ All scene changes via MCP tools
- ✅ All values from GameConfig
- ✅ All instantiation through SceneFactory
- ✅ Core systems have automated tests
```

### Step 6: Commit

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with MCP-First architecture"
```

---

## Task 4: Create Code Review Checklist

**Files:**
- Create: `.claude/code-review-checklist.md`

### Step 1: Create checklist file

```markdown
# Code Review Checklist

Use this checklist when reviewing code changes or before committing.

## Scene Modifications

- [ ] All scene changes made via MCP tools (not manual edits)
- [ ] Git log shows MCP tool usage in commit messages
- [ ] No manual .tscn edits in git diff

**Verification:**
```bash
git log --oneline -5 | grep -i "mcp"
git diff --name-only | grep ".tscn"
```

---

## Hardcoded Values

- [ ] No magic numbers in code
- [ ] No duplicate configuration data
- [ ] No hardcoded scene paths
- [ ] All values come from GameConfig

**Verification:**
```bash
grep -rn "[0-9]\{2,\}" scripts/ | grep -v "# " | grep -v "//"
grep -r "preload" scripts/ | grep -v "scene_factory.gd"
grep -r "res://scenes" scripts/ | grep -v "scene_factory.gd"
```

---

## SceneFactory Usage

- [ ] All scene instantiation through SceneFactory
- [ ] No direct preload() calls outside SceneFactory
- [ ] No direct .instantiate() without config

**Verification:**
```bash
grep -r "\.instantiate()" scripts/ | grep -v "scene_factory.gd"
```

---

## Testing

- [ ] New features have unit tests
- [ ] Modified systems have updated tests
- [ ] All tests pass

**Verification:**
```bash
# In Godot: Tools → Gut → Run All Tests
```

---

## Code Quality

- [ ] Scripts in correct directory (core/entities/systems/ui)
- [ ] Clear separation of concerns
- [ ] No duplicate code
- [ ] Functions have single responsibility

---

## Documentation

- [ ] CLAUDE.md updated if architecture changed
- [ ] Comments added for complex logic
- [ ] Development rules followed

---

## Manual Testing

- [ ] Full game playthrough completed
- [ ] No visual regressions
- [ ] No gameplay regressions
- [ ] Performance acceptable

**Test Path:**
Start → Character → Weapon → Map → Placement → Combat → Shop → Repeat

---

## Git Hygiene

- [ ] Commit messages are clear and descriptive
- [ ] Commits are atomic (one logical change per commit)
- [ ] No unnecessary files committed
- [ ] .gitignore updated if needed

---

## Final Check

- [ ] All checklist items above completed
- [ ] Code is ready for merge
- [ ] No known issues or TODOs left unaddressed
```

### Step 2: Commit

```bash
git add .claude/code-review-checklist.md
git commit -m "docs: add code review checklist"
```

---

## Task 5: Update ARCHITECTURE.md

**Files:**
- Modify: `docs/ARCHITECTURE.md`

### Step 1: Add SceneFactory section

Add after "### AutoLoad 单例":

```markdown
4. **SceneFactory** (`scripts/core/scene_factory.gd`)
   - Centralized scene instantiation
   - Applies GameConfig at creation time
   - Manages all preload() calls
```

### Step 2: Update Core Systems section

Add new subsection:

```markdown
### 8. SceneFactory System

**文件**: `scripts/core/scene_factory.gd`

**职责**: 集中管理所有场景实例化

**核心功能**:
- 预加载所有场景资源
- 创建时应用 GameConfig 配置
- 提供类型安全的创建方法
- 验证场景类型

**使用示例**:

```gdscript
# 创建塔
var tower = SceneFactory.create_tower("shooter")
add_child(tower)

# 获取塔价格
var cost = SceneFactory.get_tower_cost("shooter")

# 创建敌人
var enemy = SceneFactory.create_enemy("normal")
add_child(enemy)
```

**为什么需要 SceneFactory**:
- 单一位置管理所有场景创建
- 确保配置总是正确应用
- 避免重复的 preload() 调用
- 类型安全和验证
```

### Step 3: Add MCP-First Workflow section

Add new section at the end:

```markdown
## MCP-First 开发工作流

### 核心原则

**将 .tscn 文件视为编译产物，而非源代码。**

就像你不会手动编辑 Java 的 .class 文件或 Python 的 .pyc 文件一样，我们不手动编辑 .tscn 文件。

### 三层架构

#### 第一层：场景模板 (.tscn 文件)
- 仅包含最小结构
- 通过 MCP 工具独家创建/修改
- 检查器属性中无硬编码值
- 视为"空容器"

#### 第二层：场景工厂 (GDScript)
- `SceneFactory.gd` - 集中场景实例化
- 运行时应用 GameConfig 值
- 在一个地方处理所有 preload() 调用
- 返回完全配置的场景实例

#### 第三层：场景控制器 (现有脚本)
- 仅业务逻辑
- 无场景结构知识
- 使用 SceneFactory 创建实例
- 专注于游戏机制

### MCP 工具使用

**添加节点:**
```
mcp__gdai-mcp__add_node("ParentNode", "Sprite2D", "MySprite")
```

**修改属性:**
```
mcp__gdai-mcp__update_property("MySprite", "texture", "res://assets/sprite.png")
```

**删除节点:**
```
mcp__gdai-mcp__delete_node("MySprite")
```

### 为什么这很重要

- 一致、可重现的场景修改
- AI 友好（Claude 可以有效使用 MCP 工具）
- 更容易的代码审查（GDScript diff vs .tscn 噪音）
- 防止 .tscn 文件的合并冲突
```

### Step 4: Commit

```bash
git add docs/ARCHITECTURE.md
git commit -m "docs: update ARCHITECTURE.md with SceneFactory and MCP-First workflow"
```

---

## Task 6: Update DEVELOPMENT.md

**Files:**
- Modify: `docs/DEVELOPMENT.md`

### Step 1: Add Testing section

Add new section:

```markdown
## 测试

### 运行测试

**在 Godot 编辑器中:**
1. 打开 Godot
2. 点击 Tools → Gut → Run All Tests
3. 查看测试结果

**运行特定测试:**
1. Tools → Gut → Select Test
2. 选择要运行的测试文件
3. 点击 Run

### 编写测试

**单元测试示例:**

```gdscript
# tests/unit/test_example.gd
extends GutTest

func test_scene_factory_creates_tower():
    var tower = SceneFactory.create_tower("shooter")
    assert_not_null(tower, "Tower should be created")
    assert_eq(tower.tower_type, "shooter", "Type should match")
    tower.queue_free()
```

**集成测试示例:**

```gdscript
# tests/integration/test_example.gd
extends GutTest

func test_tower_placement_flow():
    # Test complete placement workflow
    pass
```

### 测试覆盖率

**必须测试:**
- SceneFactory 所有方法
- GameConfig 验证
- GameData 状态转换
- 关键游戏系统

**暂不测试:**
- UI 控制器
- 视觉/动画逻辑
- 一次性工具函数
```

### Step 2: Add MCP Tools section

Add new section:

```markdown
## 使用 MCP 工具修改场景

### 基本工作流

**1. 创建新场景:**
```
mcp__gdai-mcp__create_scene("res://scenes/my_scene.tscn", "Node2D")
```

**2. 打开场景:**
```
mcp__gdai-mcp__open_scene("res://scenes/my_scene.tscn")
```

**3. 添加节点:**
```
mcp__gdai-mcp__add_node(".", "Sprite2D", "MySprite")
```

**4. 设置属性:**
```
mcp__gdai-mcp__update_property("MySprite", "texture", "res://assets/sprite.png")
```

**5. 附加脚本:**
```
mcp__gdai-mcp__attach_script(".", "res://scripts/my_script.gd")
```

### 常见任务

**添加碰撞形状:**
```
mcp__gdai-mcp__add_node(".", "CollisionShape2D", "CollisionShape2D")
```

**设置碰撞层:**
```
mcp__gdai-mcp__update_property(".", "collision_layer", 2)
mcp__gdai-mcp__update_property(".", "collision_mask", 1)
```

**添加计时器:**
```
mcp__gdai-mcp__add_node(".", "Timer", "MyTimer")
mcp__gdai-mcp__update_property("MyTimer", "wait_time", 1.0)
```

### 重要提醒

- ❌ 永远不要手动编辑 .tscn 文件
- ✅ 始终使用 MCP 工具
- ✅ 在 git 提交信息中记录 MCP 工具使用
```

### Step 3: Commit

```bash
git add docs/DEVELOPMENT.md
git commit -m "docs: update DEVELOPMENT.md with testing and MCP tools guide"
```

---

## Task 7: Run Full Test Suite

**Files:**
- All test files

### Step 1: Run all unit tests

In Godot: Tools → Gut → Run All Tests (Unit)
Expected: All pass

### Step 2: Run all integration tests

In Godot: Tools → Gut → Run All Tests (Integration)
Expected: All pass

### Step 3: Check test coverage

Review test files:
```bash
ls -la tests/unit/
ls -la tests/integration/
```

### Step 4: Document test results

Create summary:
```
Test Results:
- Unit tests: X/X passing
- Integration tests: Y/Y passing
- Total: (X+Y)/(X+Y) passing
- Coverage: SceneFactory (100%), GameConfig (100%), GameData (100%)
```

### Step 5: Fix any failing tests

If tests fail, debug and fix

### Step 6: Commit if fixes made

```bash
git add tests/
git commit -m "test: fix failing tests"
```

---

## Task 8: Clean Up Project Root

**Files:**
- Project root directory

### Step 1: List files in root

```bash
ls -la
```

### Step 2: Identify unnecessary files

Look for:
- Old test files
- Temporary files
- Backup files
- Unused assets

### Step 3: Remove unnecessary files

```bash
rm -f *.tmp
rm -f *.bak
rm -f *~
```

### Step 4: Verify .gitignore is complete

Check .gitignore includes:
```
.godot/
.import/
*.tmp
*.bak
*~
dev_playground.tscn
```

### Step 5: Commit if changes made

```bash
git add .gitignore
git commit -m "chore: clean up project root and update .gitignore"
```

---

## Task 9: Update README (if exists)

**Files:**
- Modify: `README.md` (if exists)

### Step 1: Check if README exists

```bash
ls -la README.md
```

### Step 2: Add development section

If README exists, add:

```markdown
## Development

This project follows MCP-First architecture principles.

### Key Principles

- All scene modifications via MCP tools
- All values from GameConfig
- All instantiation through SceneFactory
- Core systems have automated tests

### Getting Started

1. Open project in Godot 4.6
2. Read `CLAUDE.md` for project guidelines
3. Read `.claude/rules/` for development rules
4. Run tests: Tools → Gut → Run All Tests

### Testing

Run tests in Godot: Tools → Gut → Run All Tests

### Documentation

- `CLAUDE.md` - Project overview and guidelines
- `docs/ARCHITECTURE.md` - System architecture
- `docs/DEVELOPMENT.md` - Development guide
- `.claude/rules/` - Development rules
```

### Step 3: Commit if modified

```bash
git add README.md
git commit -m "docs: update README with development guidelines"
```

---

## Task 10: Final Verification

**Comprehensive Check:**

### Step 1: Verify directory structure

```bash
tree -L 3 scripts/
tree -L 2 tests/
tree -L 2 .claude/
```

Expected: Clean, organized structure

### Step 2: Verify no test scenes

```bash
find . -name "test_*.tscn"
# Expected: No output
```

### Step 3: Verify documentation complete

```bash
ls -la docs/
ls -la .claude/rules/
```

Expected: All documentation files present

### Step 4: Verify tests pass

In Godot: Tools → Gut → Run All Tests
Expected: 100% passing

### Step 5: Verify game runs

In Godot: F5
Expected: Game loads and runs correctly

### Step 6: Create completion report

Document:
```
Phase 4 Completion Report:
- ✅ Test scenes deleted
- ✅ dev_playground.tscn created and gitignored
- ✅ CLAUDE.md updated
- ✅ Code review checklist created
- ✅ ARCHITECTURE.md updated
- ✅ DEVELOPMENT.md updated
- ✅ All tests passing
- ✅ Project root cleaned
- ✅ Documentation complete
```

---

## Phase 4 Validation

### Checklist

- [ ] All test_*.tscn files deleted
- [ ] dev_playground.tscn created and gitignored
- [ ] CLAUDE.md updated with MCP-First architecture
- [ ] Code review checklist created
- [ ] ARCHITECTURE.md updated
- [ ] DEVELOPMENT.md updated
- [ ] All tests passing (100%)
- [ ] Project root cleaned
- [ ] README updated (if exists)
- [ ] Final verification complete

### Verification Commands

```bash
# No test scenes
find . -name "test_*.tscn"
# Expected: No output

# Documentation exists
ls .claude/rules/
ls docs/

# Tests pass
# In Godot: Tools → Gut → Run All Tests
# Expected: All pass
```

---

## Commit Phase 4 Completion

```bash
git add -A
git commit -m "feat: complete Phase 4 - Cleanup & Documentation

- Deleted all test scene files
- Created dev_playground.tscn (gitignored)
- Updated CLAUDE.md with MCP-First architecture
- Created code review checklist
- Updated ARCHITECTURE.md and DEVELOPMENT.md
- Verified all tests passing
- Cleaned project root
- Finalized documentation"
```

---

**Phase 4 Complete!**

Next: Read `2026-03-05-mcp-first-refactor-phase5.md` for Phase 5 tasks.
