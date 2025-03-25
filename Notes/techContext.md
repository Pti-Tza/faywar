## Core Stack
- Godot 4.2.1
- GDScript 2.0
- Blender 3.6 (3D assets)

## Key Dependencies
1. DirectionalAStar (custom pathfinding)
2. HexMath (axial coordinate system)
3. DiceRoller (statistical modeling)

### Action Validation Rules
1. Turn ownership requires:
   - Active unit UUID match
   - Valid unit reference
   - Within turn phase window

### Log Entry Structure
```json
{
  "timestamp": "HH:MM:SS",
  "type": "move|attack|ability",
  "message": "Formatted text",
  "color": "#HEXCODE",
  "data": {}
}


## New Weapon Data Properties
@export_category("Cluster Weapons")
@export var cluster_size: int = 1
@export var cluster_spread: float = 0.0
@export var cluster_table: String = "SRM"