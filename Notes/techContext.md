## Core Stack
- Godot 4.2.1
- GDScript 2.0
- Blender 3.6 (3D assets)

## Key Dependencies
1. DirectionalAStar (custom pathfinding)
2. HexMath (axial coordinate system)
3. DiceRoller (statistical modeling)

## Constraints


## New Weapon Data Properties
@export_category("Cluster Weapons")
@export var cluster_size: int = 1
@export var cluster_spread: float = 0.0
@export var cluster_table: String = "SRM"