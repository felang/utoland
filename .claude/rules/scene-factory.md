# Rule: Scene Factory Pattern

## Principle
All scene instantiation goes through SceneFactory.

## SceneFactory Responsibilities
- Centralized preload() calls
- Apply GameConfig at instantiation
- Validate scene types
- Provide type-safe creation methods

## Usage Examples

### Creating a Tower
```gdscript
var tower = SceneFactory.create_tower("shooter")
add_child(tower)
```

### Getting Tower Cost
```gdscript
var cost = SceneFactory.get_tower_cost("shooter")
if GameData.coins >= cost:
    # Purchase logic
```

### Creating an Enemy
```gdscript
var enemy = SceneFactory.create_enemy("normal")
add_child(enemy)
```

## Anti-Patterns to Avoid

### ❌ Don't Do This
```gdscript
var tower_scene = preload("res://scenes/towers/tower_shooter.tscn")
var tower = tower_scene.instantiate()
```

### ✅ Do This Instead
```gdscript
var tower = SceneFactory.create_tower("shooter")
```

## Why This Matters
- Single place to manage scene creation
- Config always applied correctly
- Easier to refactor paths
- Type safety and validation
