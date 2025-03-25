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

func initialize(q2: int, r2: int) -> void:
	axial_coords = Vector2i(q2, r2)
	name = "HexCell(%d,%d)" % [q2, r2]

# Helper properties
var q: int : get = get_q
var r: int : get = get_r

func get_q() -> int:
	return axial_coords.x

func get_r() -> int:
	return axial_coords.y



## Reference to parent grid manager
var grid_manager: HexGridManager

## Reference to terrain configuration resource
@export var terrain_data: TerrainData :
	set(value):
		terrain_data = value
		update_visuals()

## Vertical elevation level (0 = ground level)
@export var elevation: float = 0 :
	set(value):
		
		# Update vertical position using height step
		position.y = elevation 
		# Notify systems of elevation change
		elevation_changed.emit(elevation)

## Axial coordinate system (q, r) with implicit s = -q-r
## Maintains cube coordinate constraint: q + r + s = 0
@export var axial_coord: Vector3i

## World-space position calculated from axial coordinates
## [br]Set automatically during grid generation
var world_position: Vector3

## Reference to occupying unit (null if empty)
var unit: Node3D = null :
	set(value):
		unit = value
		occupancy_changed.emit(unit)

## Type of cover provided by this cell
var cover: CoverType = CoverType.NONE :
	set(value):
		cover = value
		cover_changed.emit(cover)

var mesh_instance: MeshInstance3D

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
func _init(axial_q: int, axial_r: int) -> void:
	grid_manager = HexGridManager.instance
	assert(axial_q + axial_r <= grid_manager.grid_radius, "Invalid axial coordinates")
	q = axial_q
	r = axial_r
	name = "HexCell(%d,%d)" % [q, r]

func _ready():
	mesh_instance = $MeshInstance3D
	update_visuals()
## Calculates movement cost for a unit type
## [br][param mobility_type]: Unit's movement capability type
## [br][returns]: Total movement cost as float
func get_movement_cost(mobility_type: UnitData.MobilityType) -> float:
	var base_cost = terrain_data.get_mobility_cost(mobility_type)
	var elevation_cost = elevation * terrain_data.elevation_multiplier
	return base_cost + elevation_cost

## Updates visual representation of the cell
func update_visuals():
	if !mesh_instance || !terrain_data:
		return
	
	mesh_instance.mesh = terrain_data.mesh
	mesh_instance.material_override = terrain_data.material
	
	# Elevation positioning
	var base_position = mesh_instance.position
	base_position.y = elevation
	mesh_instance.position = base_position

func _apply_material_variation():
	if terrain_data.material_variations.size() > 0:
		var variation = terrain_data.material_variations[randi() % terrain_data.material_variations.size()]
		mesh_instance.material_override = variation
	else:
		mesh_instance.material_override = terrain_data.base_material

## Validates cube coordinate constraints
func is_valid_axial() -> bool:
	return axial_coord.x + axial_coord.y + axial_coord.z == 0

## Example usage:
## [codeblock]
## var cell = HexCell.new()
## cell.axial_coord = Vector3i(2, -1, -1)
## cell.terrain_data = preload("res://terrains/grass.tres")
## print(cell.get_movement_cost(Unit.MobilityType.INFANTRY))
## [/codeblock]
