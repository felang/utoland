# Rule: MCP-Only Scene Modifications

## Principle
Never manually edit .tscn files. All scene changes go through MCP tools.

## Workflow

### Adding a Node
Use: `mcp__gdai-mcp__add_node`

Example:
```
mcp__gdai-mcp__add_node("ParentNode", "Sprite2D", "MySprite")
```

### Changing a Property
Use: `mcp__gdai-mcp__update_property`

Example:
```
mcp__gdai-mcp__update_property("MySprite", "texture", "res://assets/sprite.png")
```

### Deleting a Node
Use: `mcp__gdai-mcp__delete_node`

Example:
```
mcp__gdai-mcp__delete_node("MySprite")
```

## Why This Matters
- Consistent, reproducible modifications
- AI-friendly (Claude can use MCP tools)
- Easier code review (GDScript diffs vs .tscn noise)
- Prevents merge conflicts

## Enforcement
- Pre-commit hook checks for manual .tscn edits
- Code review checklist includes MCP verification
