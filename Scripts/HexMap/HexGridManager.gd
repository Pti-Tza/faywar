
# hex_grid_manager.gd
extends Node3D
class_name HexGridManager
## Central manager for hexagonal grid operations with Battletech movement rules
##
## Features:
## - Directional pathfinding costs
## - Elevation-aware movement
## - Unit-specific mobility constraints
## - Asymmetric terrain costs

#region Configuration
static var instance: HexGridManager

@export_category("Grid Configuration")

## Size of individual hexes (X: width, Y: height)
@export var outer_radius: float = 10.0:
	set(value):
		outer_radius = value
## Number of divisons of single hex        
@export var divisions: int = 10        
## Noise_multiplier
@export var noise_scale: float = 1 

var inner_radius: float = outer_radius * sqrt(3.0) / 2.0

@export var hex_height: float = 10
## Vertical height per elevation level
@export var elevation_step: float = 10.0
@export var height_multiplier: float = 10.0

@export var create_empty_grid: bool

@export_category("Pathfinding")

@export var hex_cell_scene: PackedScene

## Reference to custom A* implementation
var astar: DirectionalAStar
var astar_graphs = {}



func _init():
	instance = self
	astar = DirectionalAStar.new()

#endregion

#region Internal State
## Dictionary of hex cells (key: Vector2i(q,r))
@export var hex_grid: Dictionary = {}
@export var cells : Array[HexCell]
## Cache for unit positions (unit: Node3D → HexCell)
var _unit_positions: Dictionary = {}
#endregion

#region Signals
signal grid_initialized
signal cell_updated(q: int, r: int)
signal unit_moved(unit: Node3D, from: Vector3i, to: Vector3i)
#endregion

#region Constants
const HEX_DIRECTIONS = [
	Vector2i(1, 0),  # Northeast
	Vector2i(1, -1), # North
	Vector2i(0, -1), # Northwest
	Vector2i(-1, 0), # Southwest
	Vector2i(-1, 1), # South
	Vector2i(0, 1)   # Southeast
]
#endregion

#region Core Grid Management
func _ready() -> void:
	print("HexGridManagerReady")
	




## Applies terrain/elevation data from generator
func initialize_from_data(cell_data: Array[HexCell]):
	# Clear previous grid state
	hex_grid.clear()
	cells.clear()
	# Validate input data
	if cell_data.is_empty():
		push_error("Failed to initialize grid: Empty cell data array")
		return

	# Track duplicate coordinates
	var coordinate_set = {}
	var duplicate_count = 0

	for cell in cell_data:
		# Validate cell instance
		if not is_instance_valid(cell):
			push_error("Invalid cell in data array, skipping")
			continue

		var coords = cell.axial_coords  # Should be Vector2i
		var elevation = cell.elevation
		

		# Check for duplicate coordinates
		if hex_grid.has(coords):
			push_warning("Duplicate cell at (%d, %d), overwriting" % [coords.x, coords.y])
			duplicate_count += 1
			
		# Store cell reference
		hex_grid[coords] = cell
		
		# Ensure cell is in scene tree
		#if not is_instance_valid(cell.get_parent()):
		#	add_child(cell)
		#	cells.append(cell)
		# Set world position

		# Debug output
#		if OS.is_debug_build():
#			print("Initialized cell %s: %s (Elevation: %d) position %s" % [
#				coords,
#				cell.terrain_data.name if cell.terrain_data else "Missing Terrain",
#				cell.elevation, cell._global_position
#			])
	cells = cell_data
	# Post-initialization checks

	
	if duplicate_count > 0:
		push_warning("Found %d duplicate cells in input data" % duplicate_count)
		
	if hex_grid.is_empty():
		push_error("Grid initialization failed - no valid cells processed")
		return

	# Initialize subsystems
	initialize_astar()
	var grid_cells: Array[HexCell] = []
	for cell in hex_grid.values():
		if cell is HexCell:
			grid_cells.append(cell)



	grid_initialized.emit()
	
## Initializes directional pathfinding graph    
func initialize_astar():
	# Clear existing graphs
	astar_graphs.clear()
	
	# Create A* graph for each mobility type
	for mobility in Unit.MobilityType.values():
		var graph = DirectionalAStar.new()
		astar_graphs[mobility] = graph
		
		# First pass: Add all points with positions
		for cell in hex_grid.values():
			# Use calculated position instead of global_transform
			var world_pos = axial_to_world(cell.q, cell.r)
			var point_id = _get_astar_id(cell.q, cell.r)
			
			# Validate point ID
			if point_id < 0:
				push_error("Invalid negative point ID for cell (%d, %d)" % [cell.q, cell.r])
				continue
				
			graph.add_point(point_id, world_pos)
		
		# Second pass: Create connections
		for cell in hex_grid.values():
			_connect_cell_neighbors(cell, mobility)
## Creates directional connections for a cell
func _connect_cell_neighbors(cell: HexCell, mobility: int):
	var from_id = _get_astar_id(cell.q, cell.r)
		
	for neighbor in get_neighbors(cell.q, cell.r):
		var to_id = _get_astar_id(neighbor.q, neighbor.r)
		var forward_cost = calculate_directional_cost(cell, neighbor, mobility)
		var reverse_cost = calculate_directional_cost(neighbor, cell, mobility)

		astar_graphs[mobility].add_directional_connection(from_id, to_id, forward_cost)
		astar_graphs[mobility].add_directional_connection(to_id, from_id, reverse_cost)


#endregion

#region Pathfinding
## Calculates BT-compliant movement cost between cells
## [br][param source] Starting cell (must have valid terrain_data)
## [br][param target] Destination cell (must have valid terrain_data)
## [br][param moving_unit] Mobility type of unit
func calculate_directional_cost(source: HexCell, target: HexCell, mobility: int) -> float:
	# 1. Terrain Impassability Check
	if target.terrain_data.is_impassable_for(mobility):
		return INF
	
	# 2. Elevation Change Validation
	var elevation_diff = target.elevation - source.elevation
	var max_elev = HexMath.get_max_elevation_change(mobility)
	if abs(elevation_diff) > max_elev:
		return INF
	
	# 3. Base Terrain Cost
	var base_cost = target.terrain_data.get_movement_cost(mobility)
	
	# 4. Elevation Cost Calculation
	var elevation_cost = HexMath.get_elevation_cost(mobility, elevation_diff)
	
	# 5. Special Case Handling
	var total_cost = base_cost + elevation_cost
	
	# 6. Water Level Adjustment
	if target.terrain_data.is_water:
		total_cost *= HexMath.get_water_movement_multiplier(mobility)
	
	# 7. Final Clamping
	return clamp(total_cost, 0.1, INF)



## Calculates BT-compliant movement cost between cells for specific unit
## [br][param source] Starting cell (must have valid terrain_data)
## [br][param target] Destination cell (must have valid terrain_data)
## [br][param moving_unit] Optional Unit attempting movement
func calculate_directional_cost_for_unit(source: HexCell, target: HexCell, moving_unit: Unit) -> float:
	# Validate critical inputs
	if not is_instance_valid(source) or not is_instance_valid(target):
		push_error("Invalid cells in movement cost calculation")
		return INF
	
	if not source.terrain_data or not target.terrain_data:
		push_warning("Missing terrain data for cells %s -> %s" % [source, target])
		return INF

	# Base terrain cost from target cell
	var base_cost = target.terrain_data.get_movement_cost(moving_unit.unit_data.mobility_type)
	
	# Battletech elevation rules (TW p.25)
	var elevation_diff = target.elevation - source.elevation
	if elevation_diff > 0:
		# Uphill - 1 MP per elevation level
		base_cost += elevation_diff * 1.0
	elif elevation_diff < 0:
		# Downhill - 0.5 MP per level (if not building)
		base_cost += abs(elevation_diff) * 0.5
	
	# Unit-specific modifiers (p.53 TW) (not implemented)
	#if is_instance_valid(moving_unit):
	#	var mobility_factor = moving_unit.get_effective_mobility(
	#		source.terrain_data.type,
	#		target.terrain_data.type,
	#		elevation_diff
	#	)
	#	base_cost *= mobility_factor

	# Impassable terrain check (p.55 TW)
	if target.terrain_data.is_impassable:
		return INF

	# Minimum cost clamp with Battletech MP rules
	return clamp(base_cost, 0.1, 999.9)

## Converts world position to A* point ID
func _get_astar_id_from_world(world_pos: Vector3) -> int:
	var axial_coords = world_to_axial(world_pos)
	return _get_astar_id(axial_coords.x, axial_coords.y)

## Finds path with unit-specific movement rules
func find_unit_path(unit: Node3D, start: Vector3, end: Vector3) -> Array[HexCell]:
	if not unit:
		return []
	var mobility = unit.mobility_type
	var graph = astar_graphs.get(mobility, null)
	if not graph:
		push_error("No A* graph for mobility type: %d" % mobility)
		return []

	var start_id = _get_astar_id_from_world(start)
	var end_id = _get_astar_id_from_world(end)

	if not graph.has_point(start_id) or not graph.has_point(end_id):
		push_error("Pathfinding: start or end point not in graph")
		return []

	var path_ids = graph.get_point_path(start_id, end_id)
		
	if path_ids.is_empty():
		push_error("Path ID is empty")
		return []

	var path: Array[HexCell] = []
	for id in path_ids:
		var coord = _get_coords_from_astar_id(id)
		var cell = get_cell_at_position(coord)
		#if cell:
		path.append(cell)
	return path
	
	
	
func _get_coords_from_astar_id(id: Vector3i) -> Vector3i:
	var offset = 1 << 20
	var r = (id.y % (1 << 10)) - offset
	var q = (id.x >> 10) - offset
	return Vector3i(q,0, r)
#endregion

#region Unit Management

## Gets current cell for specified unit
func get_unit_cell(unit: Node3D) -> HexCell:
	for cell in hex_grid.values():
		if cell.unit == unit:
			return cell
	return null

## Moves unit to new grid coordinates if valid
func move_unit(unit: Node3D, target_q: int, target_r: int) -> bool:
	var current_cell = get_unit_cell(unit)
	if !current_cell:
		return false
	
	var target_cell = get_cell(target_q, target_r)
	if target_cell && target_cell.unit == null:
		current_cell.unit = null
		target_cell.unit = unit
		unit.global_position = target_cell.position
		emit_signal("unit_moved", unit,
			Vector3i(current_cell.q, current_cell.r, current_cell.elevation),
			Vector3i(target_cell.q, target_cell.r, target_cell.elevation))
		return true
	return false

## Places unit and updates pathfinding graph
func place_unit(unit: Node3D, q: int, r: int) -> bool:
	var cell = get_cell(q, r)
	if cell and cell.unit == null:
		cell.unit = unit
		_unit_positions[unit] = cell
		unit.position = cell.position
		return true
	return false


#endregion

#region Helper Methods


func _create_hex_cell(q: int, r: int) -> void:
	var cell = HexCell.new(q, r)
	cell.grid_manager = self
	cell.position = axial_to_world(q, r)
	hex_grid[Vector2i(q, r)] = cell
	add_child(cell)

func _get_astar_id(q: int, r: int) -> int:
	 # Ensure positive coordinates using offset
	var offset = 1 << 20  # 1048576
	return (q + offset) * (1 << 10) + (r + offset)

func _apply_unit_mobility(_unit: Node3D) -> void:
	# Implementation for unit-specific mobility overrides
	pass

func _reset_mobility() -> void:
	# Reset any temporary mobility changes
	pass
#endregion

#region Coordinate Conversions
## Converts axial coordinates (q, r) to world space position
func axial_to_world(q: int, r: int) -> Vector3:
	var x = (q + r * 0.5) * inner_radius * 2.0
	var z = r * outer_radius * 1.5
	return Vector3(x, 0, z)

## Converts world space position to axial coordinates (q, r)
func world_to_axial(world_pos: Vector3) -> Vector2i:
	var q = (sqrt(3) / 3 * world_pos.x - 1.0 / 3 * world_pos.z) / inner_radius
	var r = (2.0 / 3 * world_pos.z) / outer_radius
	return cube_to_axial(round_axial(q, r))

func update_cell_elevation(q: int, r: int, new_elevation: int):
	var cell = get_cell(q, r)
	if cell:
		cell.elevation = new_elevation
		cell.position.y = new_elevation * hex_height


## Converts cube coordinates to axial by dropping s component
func cube_to_axial(cube: Vector3) -> Vector2i:
	return Vector2i(cube.x, cube.z)

## Rounds fractional axial coordinates to nearest valid cube coordinates
func round_axial(q: float, r: float) -> Vector3:
	var cube = Vector3(q, -q - r, r)
	var rx = roundi(cube.x)
	var ry = roundi(cube.y)
	var rz = roundi(cube.z)
	
	# Maintain cube coordinate invariant (x + y + z = 0)
	var dx = abs(rx - cube.x)
	var dy = abs(ry - cube.y)
	var dz = abs(rz - cube.z)
	
	if dx > dy and dx > dz:
		rx = - ry - rz
	elif dy > dz:
		ry = - rx - rz
	else:
		rz = - rx - ry
		
	return Vector3(rx, ry, rz)

func get_hex_distance(start_hex: Vector2i, end_hex: Vector2i) -> float:
	var q1 = start_hex.x
	var r1 = start_hex.y
	var q2 = end_hex.x
	var r2 = end_hex.y
	return float((abs(q1 - q2) + abs(r1 - r2) + abs(q1 + r1 - q2 - r2)) / 2)

#endregion
#region Grid Query
## Retrieves cell at specified axial coordinates
func get_cell(q: int, r: int) -> HexCell:
	return hex_grid.get(Vector2i(q, r), null)

func get_cell_at_position(pos: Vector3) -> HexCell:
	var axial : Vector2i  = world_to_axial(pos)
	
	return get_cell(axial.x, axial.y)

## Gets all valid neighboring cells for given coordinates
func get_neighbors(q: int, r: int) -> Array[HexCell]:
	var neighbors : Array[HexCell]
	for dir in HEX_DIRECTIONS:
		var neighbor_coord = Vector2i(q + dir.x, r + dir.y)
		if hex_grid.has(neighbor_coord):
			neighbors.append(hex_grid[neighbor_coord])
	return neighbors

func get_neighbor(q: int, r: int, direction: int) -> HexCell:
	var dir = HEX_DIRECTIONS[direction % 6]
	var neighbor_q = q + dir.x
	var neighbor_r = r + dir.y
	return get_cell(neighbor_q, neighbor_r)

## Gets all cells within specified hexagonal distance
func get_cells_in_range(center: Vector2i, rang: int) -> Array[HexCell]:
	var results : Array[HexCell]
	for q in range(-rang, rang + 1):
		var r_start = max(-rang, -q - rang)
		var r_end = min(rang, -q + rang)
		
		for r in range(r_start, r_end + 1):
			var s = -q - r
			var distance = (abs(q) + abs(r) + abs(s)) / 2
			if distance <= rang:
				var coord = Vector2i(center.x + q, center.y + r)
				if hex_grid.has(coord):
					results.append(hex_grid[coord])
	return results
#endregion
