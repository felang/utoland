# Technical Debt Resolution - Design Document

**Date**: 2026-03-05
**Status**: Approved
**Approach**: MCP-First Architecture (Approach A)

## Executive Summary

This document outlines a comprehensive refactoring strategy to eliminate technical debt in the utoland Godot project. The core philosophy is to treat .tscn files as build artifacts rather than source code, establishing an MCP-first development workflow with strict coding standards.

## Problem Statement

### Current Technical Debt

1. **Manual .tscn editing** - scenes modified by hand, fragile and error-prone
2. **Hardcoded values** - tower costs, scene paths scattered across codebase
3. **Missing abstractions** - repeated preload patterns, no centralized scene management
4. **Test scene clutter** - 5 test scenes (test_*.tscn) in root directory
5. **No automated testing** - relying entirely on manual playtesting
6. **Inconsistent patterns** - some code uses GameConfig, some doesn't

### Impact

- Difficult to add new features without breaking existing ones
- Hard to review changes (noisy .tscn diffs)
- Error-prone development workflow
- Poor AI collaboration experience
- Scaling issues as project grows

## Solution: MCP-First Architecture

### Core Philosophy

**Treat .tscn files as compiled artifacts, not source code.**

Just like you don't manually edit .class files in Java or .pyc files in Python, we won't manually edit .tscn files. All scene construction happens through:
1. **MCP tools** - for structure, nodes, properties
2. **GDScript** - for runtime instantiation and configuration

### The Three-Layer Pattern

#### Layer 1: Scene Templates (.tscn files)
- Minimal structure only
- Created/modified via MCP tools exclusively
- No hardcoded values in inspector properties
- Think of these as "empty containers"

#### Layer 2: Scene Factories (GDScript)
- `SceneFactory.gd` - centralized scene instantiation
- Applies GameConfig values at runtime
- Handles all preload() calls in one place
- Returns fully configured scene instances

#### Layer 3: Scene Controllers (existing scripts)
- Business logic only
- No scene structure knowledge
- Uses SceneFactory to create instances
- Focuses on game mechanics

### Example: Tower Creation

**Before (current code)**:
```gdscript
# placement.gd - scattered preloads and hardcoded costs
var tower_scenes = {
    "shooter": preload("res://scenes/towers/tower_shooter.tscn"),
    "wall": preload("res://scenes/towers/tower_wall.tscn"),
}
var tower_costs = {
    "shooter": 30,  # ❌ hardcoded!
    "wall": 40,
}
```

**After (MCP-first)**:
```gdscript
# placement.gd - clean business logic
func select_tower(type: String):
    var cost = SceneFactory.get_tower_cost(type)
    if GameData.coins < cost:
        return
    preview_tower = SceneFactory.create_tower(type)
    # ... rest of logic

# scene_factory.gd - centralized configuration
static func create_tower(type: String) -> Node2D:
    var tower = _tower_scenes[type].instantiate()
    var config = GameConfig.TOWERS[type]
    tower.max_hp = config["hp"]
    # ... apply all config
    return tower
```

## Directory Structure & Organization

### New Project Structure

```
utoland/
├── scripts/
│   ├── core/                    # 新增：核心系统
│   │   ├── scene_factory.gd    # 场景工厂
│   │   └── test_helpers.gd     # 测试辅助函数
│   ├── entities/                # 重组：游戏实体
│   │   ├── player.gd
│   │   ├── enemy.gd
│   │   ├── bullet.gd
│   │   ├── coin.gd
│   │   └── towers/
│   │       ├── tower.gd
│   │       ├── tower_shooter.gd
│   │       └── tower_slow.gd
│   ├── systems/                 # 重组：游戏系统
│   │   ├── wave_manager.gd
│   │   ├── enemy_spawner.gd
│   │   └── shop_manager.gd
│   └── ui/                      # 重组：UI 控制器
│       ├── start_menu.gd
│       ├── character_selection.gd
│       ├── weapon_select.gd
│       ├── map_select.gd
│       ├── placement.gd
│       ├── hud.gd
│       ├── result.gd
│       └── main.gd
├── scenes/                      # 场景文件（MCP 工具管理）
│   ├── entities/
│   ├── towers/
│   └── ui/
├── tests/                       # 新增：GUT 测试
│   ├── unit/
│   │   ├── test_scene_factory.gd
│   │   ├── test_game_config.gd
│   │   └── test_game_data.gd
│   └── integration/
│       ├── test_tower_placement.gd
│       └── test_wave_system.gd
├── .claude/
│   └── rules/                   # 新增：开发规范
│       ├── mcp-only.md         # MCP 工具使用规范
│       ├── no-hardcode.md      # 禁止硬编码规范
│       ├── scene-factory.md    # 场景工厂模式
│       └── testing.md          # 测试规范
├── game_config.gd              # 保持：配置中心
└── game_data.gd                # 移动到 scripts/core/
```

### Key Changes

1. **scripts/ 重组** - 按职责分类（core/entities/systems/ui）而非扁平结构
2. **删除测试场景** - test_*.tscn 全部删除，用 GUT 测试替代
3. **新增 .claude/rules/** - 详细的开发规范文档
4. **game_data.gd 移动** - 从根目录移到 scripts/core/ 保持一致性

## Testing Strategy with GUT

### Why GUT?

For this project, we chose **GUT (Godot Unit Test)** because:

1. **MCP-friendly** - GUT tests are pure GDScript, easy to generate and modify
2. **Mature ecosystem** - most widely used, best documentation
3. **Simple setup** - minimal configuration, works out of the box
4. **Good enough** - project doesn't need gdUnit4's advanced features

### Testing Architecture

**Three Test Levels**:

1. **Unit Tests** - test individual components in isolation
   - `test_scene_factory.gd` - verify factory creates correct instances
   - `test_game_config.gd` - validate configuration data
   - `test_game_data.gd` - test state management logic

2. **Integration Tests** - test system interactions
   - `test_tower_placement.gd` - placement logic + collision detection
   - `test_wave_system.gd` - wave manager + enemy spawner coordination
   - `test_shop_system.gd` - shop purchases + GameData updates

3. **Manual Playtest Scenes** - for visual/gameplay testing
   - Keep ONE playtest scene: `dev_playground.tscn`
   - Used for quick visual checks, not committed to version control
   - Added to .gitignore

### Test Coverage Goals

**Phase 1 (Initial)** - Core systems only:
- SceneFactory (100% coverage)
- GameConfig validation
- GameData state transitions

**Phase 2 (After refactor)** - Game mechanics:
- Tower placement rules
- Wave progression
- Shop transactions

**Phase 3 (Ongoing)** - Regression prevention:
- Add tests when bugs are found
- Test new features before merging

### Example Test Structure

```gdscript
# tests/unit/test_scene_factory.gd
extends GutTest

func test_create_tower_applies_config():
    var tower = SceneFactory.create_tower("shooter")
    assert_not_null(tower)
    assert_eq(tower.max_hp, GameConfig.TOWERS["shooter"]["hp"])
    assert_eq(tower.damage, GameConfig.TOWERS["shooter"]["damage"])
```

## Development Rules & Standards

### Rule 1: MCP-Only Scene Modifications

**Principle**: Never manually edit .tscn files. All scene changes go through MCP tools.

**Enforcement**:
- Pre-commit hook checks for manual .tscn edits
- .claude/rules/mcp-only.md with detailed examples
- Code review checklist includes MCP verification

**Workflow**:
```
Need to add a node? → Use mcp__gdai-mcp__add_node
Need to change property? → Use mcp__gdai-mcp__update_property
Need to delete node? → Use mcp__gdai-mcp__delete_node
```

**Why this matters**:
- Consistent, reproducible scene modifications
- AI-friendly (Claude can use MCP tools effectively)
- Easier code review (GDScript diffs vs .tscn noise)
- Prevents merge conflicts in .tscn files

---

### Rule 2: Zero Hardcoded Values

**Principle**: All game values must come from GameConfig.

**What counts as hardcoded**:
- ❌ Magic numbers: `if coins < 30`
- ❌ Duplicate data: `var tower_costs = {"shooter": 30}`
- ❌ String literals: `"res://scenes/towers/tower_shooter.tscn"`

**Correct patterns**:
- ✅ Config reference: `GameConfig.TOWERS["shooter"]["shop_price_min"]`
- ✅ Factory method: `SceneFactory.create_tower("shooter")`
- ✅ Centralized paths: `SceneFactory.TOWER_SCENES["shooter"]`

**Why this matters**:
- Single source of truth for all game values
- Easy to balance and tune gameplay
- Configuration changes don't require code changes
- Prevents inconsistencies and bugs

---

### Rule 3: Scene Factory Pattern

**Principle**: All scene instantiation goes through SceneFactory.

**SceneFactory responsibilities**:
- Centralized preload() calls
- Apply GameConfig at instantiation
- Validate scene types
- Provide type-safe creation methods

**Anti-patterns to eliminate**:
- ❌ Scattered preload() in multiple files
- ❌ Direct .instantiate() without config
- ❌ Duplicate scene path strings

**Why this matters**:
- Single place to manage all scene creation
- Ensures config is always applied
- Easier to refactor scene paths
- Type safety and validation

---

### Rule 4: Separation of Concerns

**Principle**: Scripts should have single, clear responsibilities.

**Layer boundaries**:
- **UI Controllers** - handle input, update displays, call systems
- **Game Systems** - implement game logic, manage state
- **Entities** - represent game objects, respond to events
- **Core** - provide shared utilities, factories, helpers

**Example violations in current code**:
- `placement.gd` has both UI logic AND tower cost data (should use SceneFactory)
- `main.gd` restores towers (should be in a TowerSystem)

**Why this matters**:
- Easier to understand and modify code
- Better testability
- Clearer dependencies
- Reduces coupling

---

### Rule 5: Testing Requirements

**Principle**: Core systems must have automated tests.

**What needs tests**:
- ✅ SceneFactory - all creation methods
- ✅ GameConfig - validation logic
- ✅ GameData - state transitions
- ✅ Game systems - critical paths (placement, waves, shop)

**What doesn't need tests** (yet):
- UI controllers (hard to test, low value)
- Visual/animation logic
- One-off utility functions

**Why this matters**:
- Catch regressions early
- Confidence when refactoring
- Documentation of expected behavior
- Faster development in long run

---

### Rule 6: Configuration-Driven Design

**Principle**: Behavior changes should only require config edits, not code changes.

**Examples**:
- Adding a new tower type → add to GameConfig.TOWERS, no code changes
- Adjusting wave difficulty → edit GameConfig.WAVES array
- Changing shop prices → modify GameConfig.SHOP values

**This means**:
- No switch/case on entity types
- Use data-driven loops: `for tower_type in GameConfig.TOWERS.keys()`
- Factory pattern handles type instantiation

**Why this matters**:
- Faster iteration on game design
- Non-programmers can balance the game
- Less code to maintain
- Fewer bugs from code changes

## Implementation Phases

### Phase 1: Foundation (Day 1, ~4 hours)

**Goal**: Establish core infrastructure and rules

**Tasks**:
1. Install and configure GUT testing framework
2. Create SceneFactory.gd with all entity creation methods
3. Write .claude/rules/ documentation (4 files)
4. Set up directory structure (move files to new locations)
5. Update project.godot autoloads if needed
6. Write initial unit tests for SceneFactory

**Deliverables**:
- Working GUT test suite (even if just 3-4 tests)
- SceneFactory with tower/enemy/bullet creation
- Complete rules documentation
- Reorganized scripts/ directory

**Success Criteria**:
- `gut` command runs and shows passing tests
- SceneFactory can create all entity types
- All rules documented with examples

---

### Phase 2: Refactor Existing Code (Day 1-2, ~6 hours)

**Goal**: Eliminate technical debt in current codebase

**Tasks**:
1. Refactor placement.gd to use SceneFactory
2. Refactor main.gd tower restoration logic
3. Remove all hardcoded values (tower costs, scene paths)
4. Fix enemy.gd and tower.gd to be fully config-driven
5. Update all scripts to use new directory structure
6. Write integration tests for placement and wave systems

**Deliverables**:
- Zero hardcoded values in codebase
- All scene instantiation through SceneFactory
- Passing test suite
- Clean git diff showing improvements

**Success Criteria**:
- No magic numbers in code (verified by grep)
- All preload() calls in SceneFactory only
- Game plays identically to before refactor

---

### Phase 3: Scene Reconstruction (Day 2, ~3 hours)

**Goal**: Rebuild scenes using MCP tools only

**Tasks**:
1. Document current scene structure (node trees, properties)
2. Delete and recreate key scenes via MCP:
   - Tower scenes (shooter, wall, slow)
   - Enemy scenes (normal, fast, tank)
   - UI scenes (if needed)
3. Verify scenes work identically to before
4. Add tests to prevent regression

**Deliverables**:
- All scenes created via MCP tools
- Git history shows MCP tool usage
- No manual .tscn edits in history

**Success Criteria**:
- All scenes have identical functionality
- Git log shows mcp__gdai-mcp__* tool usage
- No manual .tscn edits detected

---

### Phase 4: Cleanup & Documentation (Day 2-3, ~2 hours)

**Goal**: Remove cruft and finalize standards

**Tasks**:
1. Delete all test_*.tscn files
2. Create single dev_playground.tscn for manual testing
3. Add dev_playground.tscn to .gitignore
4. Update CLAUDE.md with new architecture
5. Create code review checklist
6. Run full test suite and fix any issues

**Deliverables**:
- Clean project root (no test scenes)
- Updated documentation
- 100% passing tests
- Ready for new feature development

**Success Criteria**:
- No test_*.tscn files in project root
- CLAUDE.md reflects new architecture
- All tests passing

---

### Phase 5: Validation (Day 3, ~1 hour)

**Goal**: Verify everything works end-to-end

**Tasks**:
1. Full playthrough: Start → Character → Weapon → Map → Placement → Combat → Shop → Win/Lose
2. Verify all systems work as before
3. Check that new code is easier to understand
4. Confirm MCP tools can modify scenes successfully
5. Run complete test suite

**Deliverables**:
- Working game with zero regressions
- Confidence in new architecture
- Ready to commit and move forward

**Success Criteria**:
- Complete game loop works perfectly
- No bugs introduced by refactor
- Code is cleaner and easier to understand

## Success Criteria

After this refactor, the project will have:

✅ **Zero manual .tscn edits** - all changes via MCP tools
✅ **Zero hardcoded values** - everything from GameConfig
✅ **Automated test coverage** - core systems tested
✅ **Clean architecture** - clear separation of concerns
✅ **Comprehensive documentation** - rules with examples and anti-patterns
✅ **Maintainable codebase** - easy to add features without breaking things

## Risk Mitigation

### Risk 1: Breaking existing functionality

**Mitigation**:
- Incremental refactoring (one system at a time)
- Comprehensive testing after each phase
- Keep git history clean for easy rollback

### Risk 2: MCP tools learning curve

**Mitigation**:
- Detailed documentation with examples
- Start with simple scenes (towers, enemies)
- Claude Code can help with MCP tool usage

### Risk 3: Test suite maintenance overhead

**Mitigation**:
- Focus on high-value tests (core systems)
- Don't test UI or visual logic initially
- Tests should be simple and fast

### Risk 4: Time overrun

**Mitigation**:
- Phases are independent (can pause between)
- Each phase delivers value on its own
- Can skip Phase 3 if time-constrained

## Next Steps

After design approval:
1. Invoke `writing-plans` skill to create detailed implementation plan
2. Begin Phase 1: Foundation
3. Iterate through phases with regular validation

---

**Document Status**: ✅ Approved
**Next Action**: Create implementation plan
