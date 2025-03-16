# TerrainType.gd

extends Resource
class_name TerrainType
## Represents a single terrain type with gameplay properties and visual presentation
##
## Used to configure how different terrain affects units, pathfinding, and combat

@export_category("Core Identification")
## Unique identifier for this terrain type (e.g., "forest", "urban")
@export var id: String = "terrain"
## Display name for UI purposes
@export var display_name: String = "Terrain"

@export_category("Gameplay Properties")
## Base movement cost for standard bipedal units
@export_range(0.1, 5.0) var movement_cost: float = 1.0
## Percentage defense bonus (0-100) when units are in this terrain
@export_range(0, 100, 1) var defense_bonus: int = 0
## Blocks all movement if enabled
@export var impassable: bool = false
## Heat generation modifier (+/- percentage)
@export_range(-1.0, 1.0, 0.05) var heat_modifier: float = 0.0

@export_category("Visual Properties")
## Base material for this terrain type
@export var visual_material: Material
## Array of material variations for visual diversity
@export var material_variations: Array[Material]
## Particle effect for environmental interactions
#@export var footstep_effect: GPUParticles3D

@export_category("Audio Properties")
## Footstep sound for standard movement
@export var footstep_audio: AudioStream
## Special movement sound (e.g., water splashing)
@export var special_move_audio: AudioStream

func _validate_properties() -> void:
    # Ensure ID is lowercase and sanitized
    id = id.to_lower().strip_edges()
    movement_cost = clampf(movement_cost, 0.1, 5.0)
    defense_bonus = clampi(defense_bonus, 0, 100)
    heat_modifier = clampf(heat_modifier, -1.0, 1.0)