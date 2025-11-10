
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
## Dictionary of hex cells (key: Vector3i(q,r,level))
@export var hex_grid: Dictionary = {}
@export var cells : Array[HexCell]
## Cache for unit positions (unit: Node3D → HexCell)
var _unit_positions: Dictionary = {}

## Height difference between levels
@export var level_height_step: float = 3.0
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

		var coords_3d = cell.axial_coords_with_level  # Now Vector3i (q, r, level)
		

		# Check for duplicate coordinates
		if hex_grid.has(coords_3d):
			push_warning("Duplicate cell at (%d, %d, %d), overwriting" % [coords_3d.x, coords_3d.y, coords_3d.z])
			duplicate_count += 1
			
		# Store cell reference
		hex_grid[coords_3d] = cell
		
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
		for key in hex_grid.keys():
			var coords_3d = key as Vector3i
			var cell = hex_grid[key] as HexCell
			# Use calculated position instead of global_transform
			var world_pos = axial_to_world_3d(coords_3d.x, coords_3d.y, coords_3d.z)
			var point_id = _get_astar_id_3d(coords_3d.x, coords_3d.y, coords_3d.z)
			
			# Validate point ID
			if point_id < 0:
				push_error("Invalid negative point ID for cell (%d, %d, %d)" % [coords_3d.x, coords_3d.y, coords_3d.z])
				continue
				
			graph.add_point(point_id, world_pos)
		
		# Second pass: Create connections
		for cell in hex_grid.values():
			# Only process level 0 cells for the legacy system
			#if cell.level == 0:
			#	_connect_cell_neighbors_legacy(cell, mobility)
			# Process all cells for the 3D system
			_connect_cell_neighbors_3d(cell, mobility)

## Creates 3D directional connections for a cell
func _connect_cell_neighbors_3d(cell: HexCell, mobility: int):
	var from_id = _get_astar_id_3d(cell.q, cell.r, cell.level)
	
	# Connect to horizontal neighbors at the same level
	for neighbor in get_neighbors(cell.q, cell.r, cell.level):
		var to_id = _get_astar_id_3d(neighbor.q, neighbor.r, neighbor.level)
		var forward_cost = calculate_directional_cost_3d(cell, neighbor, mobility)
		var reverse_cost = calculate_directional_cost_3d(neighbor, cell, mobility)

		astar_graphs[mobility].add_directional_connection(from_id, to_id, forward_cost)
		astar_graphs[mobility].add_directional_connection(to_id, from_id, reverse_cost)
	
	# Connect to vertical neighbors (level transitions)
	for connected_level in cell.connects_to_levels:
		var level_neighbor = get_cell_3d(cell.q, cell.r, connected_level)
		if level_neighbor:
			var to_id = _get_astar_id_3d(level_neighbor.q, level_neighbor.r, level_neighbor.level)
			var forward_cost = calculate_directional_cost_3d(cell, level_neighbor, mobility)
			var reverse_cost = calculate_directional_cost_3d(level_neighbor, cell, mobility)

			astar_graphs[mobility].add_directional_connection(from_id, to_id, forward_cost)
			astar_graphs[mobility].add_directional_connection(to_id, from_id, reverse_cost)

## Calculates movement cost between cells in 3D space
func calculate_directional_cost_3d(source: HexCell, target: HexCell, mobility: int) -> float:
	# 1. Terrain Impassability Check
	if target.terrain_data.is_impassable_for(mobility):
		return INF
	
	# 2. Elevation Change Validation (between levels)
	var elevation_diff = target.elevation - source.elevation
	var max_elev = HexMath.get_max_elevation_change(mobility)
	if abs(elevation_diff) > max_elev:
		return INF
	
	# 3. Level transition validation
	if source.level != target.level:
		# Check if this level transition is allowed
		if not target.connects_to_levels.has(source.level):
			return INF
	
	# 4. Base Terrain Cost
	var base_cost = target.terrain_data.get_movement_cost(mobility)
	
	# 5. Elevation Cost Calculation
	var elevation_cost = HexMath.get_elevation_cost(mobility, elevation_diff)
	
	# 6. Level transition cost
	var level_transition_cost = 0.0
	if source.level != target.level:
		match source.structure_type:
			HexCell.StructureType.STAIRS_UP, HexCell.StructureType.STAIRS_DOWN:
				level_transition_cost = 2.0  # Extra cost for stairs
			HexCell.StructureType.ELEVATOR:
				level_transition_cost = 0.5  # Lower cost for elevators
			_:
				level_transition_cost = 1.5  # Standard level transition cost
	
	# 7. Special Case Handling
	var total_cost = base_cost + elevation_cost + level_transition_cost
	
	# 8. Water Level Adjustment
	if target.terrain_data.is_water:
		total_cost *= HexMath.get_water_movement_multiplier(mobility)
	
	# 9. Final Clamping
	return clamp(total_cost, 0.1, INF)

## Creates directional connections for a cell at level 0 (legacy function for backward compatibility)
func _connect_cell_neighbors_legacy(cell: HexCell, mobility: int):
	# Only connect cells at level 0 for backward compatibility
	if cell.level != 0:
		return
		
	var from_id = _get_astar_id(cell.q, cell.r)
		
	for neighbor in get_neighbors(cell.q, cell.r, 0):  # Only get neighbors at level 0
		var to_id = _get_astar_id(neighbor.q, neighbor.r)
		var forward_cost = calculate_directional_cost(cell, neighbor, mobility)
		var reverse_cost = calculate_directional_cost(neighbor, cell, mobility)

		astar_graphs[mobility].add_directional_connection(from_id, to_id, forward_cost)
		astar_graphs[mobility].add_directional_connection(to_id, from_id, reverse_cost)
## Creates directional connections for a cell at level 0 (for backward compatibility)
func _connect_cell_neighbors(cell: HexCell, mobility: int):
	# Only connect cells at level 0 for backward compatibility
	if cell.level != 0:
		return
		
	var from_id = _get_astar_id(cell.q, cell.r)
		
	for neighbor in get_neighbors(cell.q, cell.r, 0):  # Only get neighbors at level 0
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
	var base_cost = target.terrain_data.get_movement_cost(moving_unit.mobility_type)
	
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
	var axial_coordss = world_to_axial(world_pos)
	return _get_astar_id(axial_coordss.x, axial_coordss.y)

## Finds path with unit-specific movement rules (2D - for backward compatibility)
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
		#var coord = _get_coords_from_astar_id(id)
		var cell = get_cell_at_position(id)
		#if cell:
		path.append(cell)
	return path

## Finds 3D path with unit-specific movement rules
func find_unit_path_3d(unit: Node3D, start_3d: Vector3i, end_3d: Vector3i) -> Array[HexCell]:
	if not unit:
		return []
	var mobility = unit.mobility_type
	var graph = astar_graphs.get(mobility, null)
	if not graph:
		push_error("No A* graph for mobility type: %d" % mobility)
		return []

	var start_id = _get_astar_id_3d(start_3d.x, start_3d.y, start_3d.z)
	var end_id = _get_astar_id_3d(end_3d.x, end_3d.y, end_3d.z)

	if not graph.has_point(start_id) or not graph.has_point(end_id):
		push_error("Pathfinding: start or end point not in 3D graph")
		return []

	var path_ids = graph.get_point_path(start_id, end_id)
		
	if path_ids.is_empty():
		push_error("3D Path ID is empty")
		return []

	var path: Array[HexCell] = []
	for id in path_ids:
		var coords_3d = _get_coords_from_astar_id_3d(id)
		var cell = get_cell_3d(coords_3d.x, coords_3d.y, coords_3d.z)
		if cell:
			path.append(cell)
	return path
	
	
	
func _get_coords_from_astar_id(id: Vector3i) -> Vector3i:
	var offset = 1 << 20
	var r = (id.y % (1 << 10)) - offset
	var q = (id.x >> 10) - offset
	return Vector3i(q,0, r)

## Converts 3D A* ID back to coordinates
func _get_coords_from_astar_id_3d(id: int) -> Vector3i:
	var level = id % (1 << 8)
	level -= 128  # Remove offset
	var temp = id >> 8  # Use bit shift instead of division
	var r = (temp % (1 << 10)) - (1 << 20)
	var q = (temp >> 10) - (1 << 20)  # Use bit shift instead of division
	return Vector3i(q, r, level)
#endregion

#region Unit Management

## Gets current cell for specified unit
func get_unit_cell(unit: Node3D) -> HexCell:
	# First try to get the cell using the unit's 3D hex position if it has that property
	if unit.has_method("get_current_hex_cell"):
		return unit.get_current_hex_cell()
	elif unit.has_property("current_hex_3d"):
		var hex_pos = unit.current_hex_3d
		return get_cell_3d(hex_pos.x, hex_pos.y, hex_pos.z)
	
	# Fallback: search through all cells
	for cell in hex_grid.values():
		if cell.unit == unit:
			return cell
	return null

## Moves unit to new grid coordinates if valid
func move_unit(unit: Node3D, target_q: int, target_r: int, target_level: int = 0) -> bool:
	var current_cell = get_unit_cell(unit)
	if !current_cell:
		return false
	
	var target_cell = get_cell_3d(target_q, target_r, target_level)
	if target_cell && target_cell.unit == null:
		current_cell.unit = null
		target_cell.unit = unit
		unit.global_position = target_cell.position
		emit_signal("unit_moved", unit,
			Vector3i(current_cell.q, current_cell.r, current_cell.level),
			Vector3i(target_cell.q, target_cell.r, target_cell.level))
		return true
	return false

## Places unit and updates pathfinding graph
func place_unit(unit: Unit, q: int, r: int, level: int = 0) -> bool:
	var cell = get_cell_3d(q, r, level)
	if cell and cell.unit == null:
		cell.unit = unit
		_unit_positions[unit] = cell
		unit.position = cell.position
		# Update unit's 3D position
		unit.set_hex_position_3d(q, r, level)
		return true
	else:
		# If the specified cell is invalid or occupied, find the nearest valid cell
		var nearest_valid_cell = _find_nearest_valid_cell(q, r, level, unit)
		if nearest_valid_cell:
			nearest_valid_cell.unit = unit
			_unit_positions[unit] = nearest_valid_cell
			unit.position = nearest_valid_cell.position
			# Update unit's 3D position
			unit.set_hex_position_3d(nearest_valid_cell.q, nearest_valid_cell.r, nearest_valid_cell.level)
			return true
	return false

## Finds the nearest valid cell to the specified coordinates
func _find_nearest_valid_cell(target_q: int, target_r: int, target_level: int, unit: Unit = null) -> HexCell:
	var search_radius = 1
	var max_search_radius = 10  # Limit search to prevent infinite loops
	
	while search_radius <= max_search_radius:
		# Get all cells within the current search radius in 3D space
		var cells_in_range = get_cells_in_range_3d(Vector3i(target_q, target_r, target_level), search_radius)
		
		# Find the closest valid cell
		var closest_valid_cell: HexCell = null
		var min_distance = INF
		
		for cell in cells_in_range:
			# Check if cell is valid (exists and unoccupied)
			if cell and cell.unit == null:
				# Calculate 3D distance considering level difference
				var distance = get_hex_distance3d(Vector3i(target_q, target_r, target_level), Vector3i(cell.q, cell.r, cell.level))
				if distance < min_distance:
					min_distance = distance
					closest_valid_cell = cell
		
		if closest_valid_cell:
			return closest_valid_cell
		
		search_radius += 1
	
	return null


#endregion

#region Helper Methods


func _create_hex_cell(q: int, r: int, level: int = 0) -> void:
	var cell = HexCell.new(q, r, 0, self, Vector3.ZERO, level)
	cell.grid_manager = self
	cell.position = axial_to_world_3d(q, r, level)
	hex_grid[Vector3i(q, r, level)] = cell
	add_child(cell)

## Converts 2D hex coordinates to A* point ID
func _get_astar_id(q: int, r: int) -> int:
	 # Ensure positive coordinates using offset
	var offset = 1 << 20 # 1048576
	return (q + offset) * (1 << 10) + (r + offset)

## Converts 3D hex coordinates to A* point ID
func _get_astar_id_3d(q: int, r: int, level: int) -> int:
	var offset = 1 << 20
	return ((q + offset) * (1 << 10) + (r + offset)) * (1 << 8) + (level + 128)

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

## Converts 3D axial coordinates (q, r, level) to world space position
func axial_to_world_3d(q: int, r: int, level: int) -> Vector3:
	var base_pos = axial_to_world(q, r)
	var level_height = level * level_height_step
	return Vector3(base_pos.x, level_height, base_pos.z)

## Converts world space position to axial coordinates (q, r)
func world_to_axial(world_pos: Vector3) -> Vector2i:
	var q = (sqrt(3) / 3 * world_pos.x - 1.0 / 3 * world_pos.z) / inner_radius
	var r = (2.0 / 3 * world_pos.z) / outer_radius
	return cube_to_axial(round_axial(q, r))

## Converts world space position to 3D axial coordinates (q, r, level)
func world_to_axial_3d(world_pos: Vector3) -> Vector3i:
	var q = (sqrt(3) / 3 * world_pos.x - 1.0 / 3 * world_pos.z) / inner_radius
	var r = (2.0 / 3 * world_pos.z) / outer_radius
	var level = int(world_pos.y / level_height_step)
	var axial_2d = cube_to_axial(round_axial(q, r))
	return Vector3i(axial_2d.x, axial_2d.y, level)



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

## Gets 3D hex distance considering level differences
func get_hex_distance3d(start_hex: Vector3i, end_hex: Vector3i) -> float:
	var horizontal_distance = get_hex_distance(Vector2i(start_hex.x, start_hex.y), Vector2i(end_hex.x, end_hex.y))
	var vertical_distance = abs(start_hex.z - end_hex.z)  # z component represents level
	return horizontal_distance + vertical_distance

## Gets a path of hexes between two coordinates ignoring terrain and mobility constraints
## @param start_hex: Starting hex coordinates (Vector2i)
## @param end_hex: Ending hex coordinates (Vector2i)
## @return: Array[HexCell] - Path of hex cells between start and end
func get_hex_path(start_hex: Vector2i, end_hex: Vector2i) -> Array[HexCell]:
	var path: Array[HexCell] = []
	
	# Convert axial coordinates to cube coordinates for line drawing
	var start_cube = Vector3(start_hex.x, -start_hex.x - start_hex.y, start_hex.y)
	var end_cube = Vector3(end_hex.x, -end_hex.x - end_hex.y, end_hex.y)
	
	var distance = int(get_hex_distance(start_hex, end_hex))
	if distance == 0:
		var start_cell = get_cell(start_hex.x, start_hex.y)
		if start_cell:
			path.append(start_cell)
		return path
	
	# Calculate the line through hexes
	for i in range(distance + 1):
		var cube_coord = _cube_lerp(start_cube, end_cube, float(i) / float(distance))
		var hex_coord = cube_to_axial(cube_coord)
		var cell = get_cell(hex_coord.x, hex_coord.y)
		if cell:
			path.append(cell)
	
	return path

## Linear interpolation between two cube coordinates
func _cube_lerp(a: Vector3, b: Vector3, t: float) -> Vector3:
	var ax = a.x
	var ay = a.y
	var az = a.z
	var bx = b.x
	var by = b.y
	var bz = b.z
	
	var x = ax + (bx - ax) * t
	var y = ay + (by - ay) * t
	var z = az + (bz - az) * t
	
	return round_axial(x, z)


#endregion
#region Grid Query
## Retrieves cell at specified axial coordinates (2D - level 0 by default)
func get_cell(q: int, r: int) -> HexCell:
	return hex_grid.get(Vector3i(q, r, 0), null)

## Retrieves cell at specified 3D coordinates (q, r, level)
func get_cell_3d(q: int, r: int, level: int) -> HexCell:
	return hex_grid.get(Vector3i(q, r, level), null)

func get_cell_at_position(pos: Vector3) -> HexCell:
	var axial : Vector2i  = world_to_axial(pos)
	var level = int(pos.y / level_height_step)
	
	return get_cell_3d(axial.x, axial.y, level)

## Gets cell at 3D world position
func get_cell_at_position_3d(pos: Vector3) -> HexCell:
	var axial : Vector2i  = world_to_axial(pos)
	var level = int(pos.y / level_height_step)
	
	return get_cell_3d(axial.x, axial.y, level)

## Gets all valid neighboring cells for given coordinates at same level
func get_neighbors(q: int, r: int, level: int = 0) -> Array[HexCell]:
	var neighbors : Array[HexCell]
	for dir in HEX_DIRECTIONS:
		var neighbor_coord = Vector3i(q + dir.x, r + dir.y, level)
		var neighbor_cell = hex_grid.get(neighbor_coord, null)
		if neighbor_cell:
			neighbors.append(neighbor_cell)
	return neighbors

## Gets all valid neighboring cells for given 3D coordinates (including level transitions)
func get_neighbors_3d(q: int, r: int, level: int) -> Array[HexCell]:
	var neighbors : Array[HexCell]
	
	# Horizontal neighbors at same level
	for dir in HEX_DIRECTIONS:
		var neighbor_coord = Vector3i(q + dir.x, r + dir.y, level)
		var neighbor_cell = hex_grid.get(neighbor_coord, null)
		if neighbor_cell:
			neighbors.append(neighbor_cell)
	
	# Vertical neighbors (level transitions) - from the cell's connects_to_levels
	var current_cell = get_cell_3d(q, r, level)
	if current_cell:
		for connected_level in current_cell.connects_to_levels:
			var level_neighbor = get_cell_3d(q, r, connected_level)
			if level_neighbor:
				neighbors.append(level_neighbor)
	
	return neighbors

func get_neighbor(q: int, r: int, direction: int, level: int = 0) -> HexCell:
	var dir = HEX_DIRECTIONS[direction % 6]
	var neighbor_q = q + dir.x
	var neighbor_r = r + dir.y
	return get_cell_3d(neighbor_q, neighbor_r, level)

## Gets neighbor in a specific direction at the same level
func get_neighbor_3d(q: int, r: int, direction: int, level: int) -> HexCell:
	var dir = HEX_DIRECTIONS[direction % 6]
	var neighbor_q = q + dir.x
	var neighbor_r = r + dir.y
	return get_cell_3d(neighbor_q, neighbor_r, level)

## Gets all cells within specified hexagonal distance at a specific level
func get_cells_in_range(center: Vector2i, rang: int, level: int = 0) -> Array[HexCell]:
	var results : Array[HexCell]
	for q in range(-rang, rang + 1):
		var r_start = max(-rang, -q - rang)
		var r_end = min(rang, -q + rang)
		
		for r in range(r_start, r_end + 1):
			var s = -q - r
			var distance = (abs(q) + abs(r) + abs(s)) / 2
			if distance <= rang:
				var coord = Vector3i(center.x + q, center.y + r, level)
				var cell = hex_grid.get(coord, null)
				if cell:
					results.append(cell)
	return results

## Gets all cells within specified hexagonal distance in 3D space
func get_cells_in_range_3d(center: Vector3i, rang: int) -> Array[HexCell]:
	var results : Array[HexCell]
	for q in range(-rang, rang + 1):
		var r_start = max(-rang, -q - rang)
		var r_end = min(rang, -q + rang)
		
		for r in range(r_start, r_end + 1):
			var s = -q - r
			var distance = (abs(q) + abs(r) + abs(s)) / 2
			if distance <= rang:
				# Check all levels at this hex location
				for level_key in hex_grid.keys():
					var level_coord = level_key as Vector3i
					if level_coord.x == center.x + q and level_coord.y == center.y + r:
						var cell = hex_grid.get(level_key, null)
						if cell:
							results.append(cell)
	return results
#endregion
