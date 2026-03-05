# Rule: Testing Requirements

## Principle
Core systems must have automated tests.

## What Needs Tests

### ✅ Must Test
- SceneFactory - all creation methods
- GameConfig - validation logic
- GameData - state transitions
- Game systems - critical paths (placement, waves, shop)

### ⏸️ Don't Test (Yet)
- UI controllers (hard to test, low value)
- Visual/animation logic
- One-off utility functions

## Test Structure

### Unit Tests
Test individual components in isolation.

Location: `tests/unit/`

Example:
```gdscript
extends GutTest

func test_create_tower():
    var tower = SceneFactory.create_tower("shooter")
    assert_not_null(tower)
    assert_eq(tower.max_hp, GameConfig.TOWERS["shooter"]["hp"])
    tower.queue_free()
```

### Integration Tests
Test system interactions.

Location: `tests/integration/`

Example:
```gdscript
extends GutTest

func test_tower_placement():
    # Test placement logic + collision detection
    pass
```

## Running Tests

### All Tests
```bash
# In Godot: Tools → Gut → Run All Tests
```

### Specific Test
```bash
# In Godot: Tools → Gut → Select Test → Run
```

## Why This Matters
- Catch regressions early
- Confidence when refactoring
- Documentation of expected behavior
- Faster development long-term
