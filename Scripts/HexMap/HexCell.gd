# hex_cell.gd
class_name HexCell
extends Node3D
## Represents a single cell in a 3D hexagonal grid system for tactical games
##
## Handles terrain properties, elevation, unit occupancy, and cover states.
## Integrates with pathfinding systems to provide movement cost calculations.
## Coordinates are managed in axial (q,r) format with cube coordinate validation.

## Axial coordinates (q, r) - read only after creation
var axial_coords: Vector2i = Vector2i.ZERO

## Level coordinate (z-axis) - 0 = ground level, positive = upper floors, negative = underground
@export var level: int = 0


# Helper properties
var q: int : get = get_q
var r: int : get = get_r

func get_q() -> int:
	return axial_coords.x

func get_r() -> int:
	return axial_coords.y

## Coordinate property that includes level
var axial_coords_with_level: Vector3i:
	get:
		return Vector3i(axial_coords.x, axial_coords.y, level)

var _global_position: Vector3:
	get:
		var base_pos = HexGridManager.instance.axial_to_world(q, r)
		var level_height = HexGridManager.instance.level_height_step * level if HexGridManager.instance else 0.0
		return Vector3(
			base_pos.x,
			elevation + level_height,
			base_pos.z
		)

## Reference to parent grid manager
var grid_manager: HexGridManager

## Reference to terrain configuration resource
@export var terrain_data: TerrainData :
	set(value):
		terrain_data = value
 

## Vertical elevation level (0 = ground level)
@export var elevation: float :
	set(value):
		elevation = value
		position.y = elevation 
		# Notify systems of elevation change
		elevation_changed.emit(elevation)

# Add terrain type index
@export var terrain_type_index: int = 0
var blend_weights: Vector3 = Vector3(1, 0, 0)
var neighbor_indices: Vector3 = Vector3(0, 0, 0)

var color: Color:
	get:
		return terrain_data.strategic_map_color
var texture_index: int
var normal_index: int
var variation_index: int
	  
## World-space position calculated from axial coordinates
## [br]Set automatically during grid generation
var world_position: Vector3

## Reference to occupying unit (null if empty)
var unit: Node3D = null :
	set(value):
		unit = value
		occupancy_changed.emit(unit)

## Type of structure for multi-level features
@export var structure_type: StructureType = StructureType.GROUND

## Type of cover provided by this cell
var cover: CoverType = CoverType.NONE :
	set(value):
		cover = value
		cover_changed.emit(cover)

## Array of levels this cell connects to (for stairs, elevators, bridges)
@export var connects_to_levels: Array[int] = []


var neighbors:Array[HexCell] = []
var lab : Label3D

## Structure type classification system for multi-level features
enum StructureType {
	GROUND,      ## Standard ground level
	BRIDGE,      ## Elevated bridge connecting hexes
	FLOOR,       ## Building floor
	TUNNEL,      ## Underground tunnel
	STAIRS_UP,   ## Stairs going up
	STAIRS_DOWN, ## Stairs going down
	ELEVATOR,    ## Vertical transport between levels
	ROOFTOP      ## Rooftop access
}

## Cover type classification system
enum CoverType {
	NONE,   ## No cover benefits
	LIGHT,  ## 25% damage reduction
	HEAVY   ## 50% damage reduction
}

## Signal emitted when elevation changes
signal elevation_changed(new_elevation: int)
## Signal emitted when cell occupancy changes
signal occupancy_changed(new_unit: Node3D)
## Signal emitted when cover state changes
signal cover_changed(new_cover: CoverType)

# Initialize with axial coordinates
#func _init(axial_q: int, axial_r: int, e: float = 0) -> void:
	#
	#grid_manager = HexGridManager.instance
	#assert(axial_q + axial_r <= grid_manager.radius, "Invalid axial coordinates")
	#q = axial_q
	#r = axial_r
	#
	#name = "HexCell(%d,%d,%d)" % [q, r, e]
	#
	

	
	
func _init(q2: int, r2: int, e: float = 0, manager: HexGridManager = null, world_pos: Vector3 = Vector3.ZERO, cell_level: int = 0) -> void:
	if not manager:
		grid_manager = HexGridManager.instance
	else:
		grid_manager=manager
	
	position = world_pos
	axial_coords = Vector2i(q2, r2)
	elevation = e
	level = cell_level
	name = "HexCell(%d,%d,%d)" % [q2, r2, e]

	
	
## Calculates movement cost for a unit type
## [br][param mobility_type]: Unit's movement capability type
## [br][returns]: Total movement cost as float
func get_movement_cost(mobility_type: Unit.MobilityType) -> float:
	var base_cost = terrain_data.get_mobility_cost(mobility_type)
	var elevation_cost = elevation * terrain_data.elevation_multiplier
	return base_cost + elevation_cost
