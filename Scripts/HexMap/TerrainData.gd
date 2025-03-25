# TerrainData.gd
class_name TerrainData
extends Resource
## Central repository for all terrain configuration and global movement rules
##
## Manages terrain type lookup, movement cost calculations, and global modifiers

@export_category("Terrain Database")
## Collection of all available terrain types
@export var terrain_types: Array[TerrainType] = []
## Default terrain when requested type isn't found
@export var default_terrain: String = "plains"

@export_category("Global Modifiers")
## Multiplier for elevation-based movement costs
@export_range(0.0, 2.0) var elevation_cost_multiplier: float = 0.5
## Cost multiplier for downhill movement
@export_range(0.0, 1.0) var downhill_cost_multiplier: float = 0.8

@export_category("Mobility Costs")
## Movement cost multipliers by unit type
@export var mobility_costs: Dictionary = {
    UnitData.MobilityType.BIPEDAL: 1.0,
    UnitData.MobilityType.WHEELED: 1.5,
    UnitData.MobilityType.HOVER: 0.8,
    UnitData.MobilityType.TRACKED: 2.0,
    UnitData.MobilityType.AERIAL: 0.5
}

@export_category("Visuals")
@export var mesh: Mesh
@export var base_material: Material
@export var material_variations: Array[Material]

# Cache for quick terrain lookups (ID: TerrainType)
var _terrain_cache: Dictionary = {}

func _init() -> void:
    _build_terrain_cache()

## Build lookup cache and validate terrain data
func _build_terrain_cache() -> void:
    _terrain_cache.clear()
    var ids = []
    
    for terrain in terrain_types:
        # Ensure unique IDs
        assert(!ids.has(terrain.id), "Duplicate terrain ID: %s" % terrain.id)
        ids.append(terrain.id)
        
        # Store in cache
        _terrain_cache[terrain.id] = terrain
        
        # Validate terrain properties
        terrain._validate_properties()

## Retrieve terrain type by ID with fallback
## [param terrain_id]: ID to look up
## [returns]: TerrainType resource or default
func get_terrain(terrain_id: String) -> TerrainType:
    var id = terrain_id.to_lower().strip_edges()
    return _terrain_cache.get(id, _terrain_cache[default_terrain])

## Calculate total movement cost for a unit type
## [param mobility_type]: Unit's movement capability
## [param terrain_id]: Current terrain ID
## [param elevation_diff]: Height difference from previous position
## [returns]: Total movement cost as float
func calculate_movement_cost(
    mobility_type: UnitData.MobilityType,
    terrain_id: String,
    elevation_diff: float = 0.0
) -> float:
    var terrain = get_terrain(terrain_id)
    var base_cost = terrain.movement_cost * mobility_costs.get(mobility_type, 999.9)
    
    # Calculate elevation impact
    if elevation_diff > 0:
        base_cost += elevation_diff * elevation_cost_multiplier
    else:
        base_cost += abs(elevation_diff) * elevation_cost_multiplier * downhill_cost_multiplier
    
    return max(base_cost, 0.1)

## Get defense bonus for terrain type
## [param terrain_id]: ID to check
## [returns]: Defense bonus percentage (0-100)
func get_defense_bonus(terrain_id: String) -> int:
    return get_terrain(terrain_id).defense_bonus

## Check if terrain blocks movement
## [param terrain_id]: ID to check
## [returns]: True if terrain is impassable
func is_impassable(terrain_id: String) -> bool:
    return get_terrain(terrain_id).impassable

## Get random material variation for terrain
## [param terrain_id]: ID to check
## [returns]: Material resource or null
func get_random_material(terrain_id: String) -> Material:
    var terrain = get_terrain(terrain_id)
    if terrain.material_variations.is_empty():
        return terrain.visual_material
    return terrain.material_variations.pick_random()