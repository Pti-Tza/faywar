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
## Number of concentric rings around center (0 = single hex)
@export var radius: int = 10
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


var terrain_texture_array: Texture2DArray
var terrain_normal_array: Texture2DArray
var terrain_index_map: Dictionary = {}  # {TerrainData: {base_idx: int, count: int}}
var noise := FastNoiseLite.new()

func _init():
	instance = self

#endregion

#region Internal State
## Dictionary of hex cells (key: Vector2i(q,r))
var hex_grid: Dictionary = {}
var cells : Array[HexCell]
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
	if create_empty_grid : 
		generate_hex_grid(radius) 
		

	

func print_map_size():
	await get_tree().process_frame
	var center_cell = get_cell(0, 0)
	if center_cell:
		print("Map generation successful!")
		print("Neighbors: ", get_neighbors(0, 0).size())
	else:
		print("Generation failed - check connections")
		
	var map_stats = {
		"width": 2 * radius + 1,
		"height": 2 * radius + 1,
		"expected_cells":  1 + 6 * (radius * (radius + 1)) / 2,
		"actual_cells": hex_grid.size()
	}
	print("Battletech Map Initialized:\n", JSON.stringify(map_stats, "\t"))	




## Generates hexagonal grid with axial coordinates
func generate_hex_grid(radius : int) -> void:
	hex_grid.clear()
	cells.clear()
	# Generate concentric rings of hex cells
	for q in range(-radius, radius + 1):
		# Calculate valid r range for current q to maintain hexagonal shape
		var r1 = max(-radius, -q - radius)
		var r2 = min(radius, -q + radius)
		
		for r in range(r1, r2 + 1):
			var cell = HexCell.new(q, r)
			
			cell.position = axial_to_world(q, r)  # Set position directly
			add_child(cell)  # Add to scene tree FIRST
			hex_grid[Vector2i(q, r)] = cell
			cells.append(cell)
			
	print_map_size()		
	#initialize_astar()		
	update_cells_meshes(cells)		
	grid_initialized.emit()

func initialize_grid(cell_data: Array[HexCell]):
	# Clear previous mesh if exists
	var terrain_mesh = $TerrainMesh
	if terrain_mesh:
		terrain_mesh.queue_free()
	
	# Build texture arrays first
	if !build_texture_arrays():
		push_error("Failed to build texture arrays")
		return
	
	# Create new mesh instance
	var new_mesh = MeshInstance3D.new()
	new_mesh.name = "TerrainMesh"
	add_child(new_mesh)
	
	# Generate ACTUAL terrain mesh with elevation data
	_generate_smooth_terrain_mesh(cell_data)
	
	# Set material parameters
	var material = terrain_mesh.material_override
	if !material:
		material = StandardMaterial3D.new()
		new_mesh.material_override = material
	
	#material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.set_shader_parameter("albedo_array", terrain_texture_array)
	material.set_shader_parameter("normal_array", terrain_normal_array)

func _generate_smooth_terrain_mesh(cell_data: Array[HexCell]):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var vertex_map = {}
	var vertex_count = 0
	
	# Generate smooth terrain from cell data
	for cell in cell_data:
		var center_pos = cell.position
		center_pos.y = cell.elevation * elevation_step
		
		# Generate elevated corners
		var corners = []
		for i in 6:
			var angle = deg_to_rad(60 * i + 30)
			var dir = Vector3(cos(angle), 0, sin(angle))
			var corner_pos = center_pos + dir * outer_radius
			corner_pos.y = cell.elevation * elevation_step
			corners.append(corner_pos)
		
		# Create subdivided edges
		var ring_vertices = []
		for i in 6:
			var next_i = (i + 1) % 6
			var edge_points = []
			for j in divisions + 1:
				var t = j / float(divisions)
				var pos = corners[i].lerp(corners[next_i], t)
				edge_points.append(pos)
			
			if i == 0:
				ring_vertices.append_array(edge_points)
			else:
				ring_vertices.append_array(edge_points.slice(1))
		
		# Add vertices and indices
		var center_idx = _add_vertex(st, vertex_map, center_pos, vertex_count)
		var ring_indices = []
		for pos in ring_vertices:
			ring_indices.append(_add_vertex(st, vertex_map, pos, vertex_count))
		
		# Create triangles
		for i in ring_indices.size():
			var j = (i + 1) % ring_indices.size()
			st.add_index(center_idx)
			st.add_index(ring_indices[i])
			st.add_index(ring_indices[j])
	
	# Finalize and assign mesh
	st.generate_normals()
	st.generate_tangents()
	$TerrainMesh.mesh = st.commit()

func _generate_smooth_corners(center: Vector3) -> Array:
	var corners = []
	for i in 6:
		var angle = deg_to_rad(60 * i + 30)
		var offset = Vector3(
			cos(angle) * outer_radius,
			0,
			sin(angle) * outer_radius
		)
		var pos = center + offset
		pos.y = _sample_terrain_height(pos)
		corners.append(pos)
	return corners

func subdivide_edge(a: Vector3, b: Vector3, divisions: int) -> Array:
	var points = []
	for i in divisions + 1:
		var t = i / float(divisions)
		var pos = a.lerp(b, t)
		pos.y = _sample_terrain_height(pos)
		points.append(pos)
	return points

func _sample_terrain_height(pos: Vector3) -> float:
	# Sample noise with octaves for natural variation
	var height = noise.get_noise_2d(pos.x * noise_scale, pos.z * noise_scale)
	return height * height_multiplier

func _add_vertex(st: SurfaceTool, vertex_map: Dictionary, pos: Vector3, count: int) -> int:
	var key = "%.4f,%.4f,%.4f" % [
		snapped(pos.x, 0.0001), 
		snapped(pos.y, 0.0001), 
		snapped(pos.z, 0.0001)
	]
	
	if vertex_map.has(key):
		return vertex_map[key]
	
	# Set UVs based on world position
	var uv = Vector2(
		pos.x / (radius * outer_radius * 2) + 0.5,
		pos.z / (radius * outer_radius * 2) + 0.5
	)
	st.set_uv(uv)
	st.add_vertex(pos)
	
	vertex_map[key] = count
	return count
	
func update_cells_meshes(hex_cells: Array[HexCell]) -> void:
	var valid_cells: Array[HexCell] = []
	
	# 2. Type validation and filtering
	for cell in hex_cells:
		if cell is HexCell:
			valid_cells.append(cell)
		else:
			push_error("Invalid cell type in visual mesh generation: %s" % str(cell))
	
	
	initialize_grid(valid_cells)

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
		# Battletech map validation: Check hex coordinate validity
		if not HexMath.is_valid_axial(coords.x, coords.y, radius):
			push_error("Invalid axial coordinates (%d, %d), skipping" % [coords.x, coords.y])
			continue

		# Check for duplicate coordinates
		if hex_grid.has(coords):
			push_warning("Duplicate cell at (%d, %d), overwriting" % [coords.x, coords.y])
			duplicate_count += 1
			
		# Store cell reference
		hex_grid[coords] = cell
		
		# Ensure cell is in scene tree
		if not is_instance_valid(cell.get_parent()):
			add_child(cell)
			cells.append(cell)
		# Set world position
		cell.position = axial_to_world(coords.x, coords.y)
		cell.elevation = elevation
		# Debug output
		if OS.is_debug_build():
			print("Initialized cell %s: %s (Elevation: %d)" % [
				coords,
				cell.terrain_data.name if cell.terrain_data else "Missing Terrain",
				cell.elevation
			])

	# Post-initialization checks
	print_map_size()
	
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

	initialize_grid(grid_cells)
	
	# Final validation
	var expected_cells = 1 + 6 * (radius * (radius + 1)) / 2
	if hex_grid.size() != expected_cells:
		push_error("Cell count mismatch. Expected: %d, Actual: %d" % [
			expected_cells,
			hex_grid.size()
		])
	
	grid_initialized.emit()
	
## Initializes directional pathfinding graph    
func initialize_astar():
	# Clear existing graphs
	astar_graphs.clear()
	
	# Create A* graph for each mobility type
	for mobility in UnitData.MobilityType.values():
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

func build_texture_arrays():
	# Collect all unique textures
	var all_textures : Array[Texture2D]
	var all_normals : Array[Texture2D]
	
	for cell in hex_grid.values():
		var terrain = cell.terrain_data
		if !terrain: continue
		
		# Register textures
		if !terrain_index_map.has(terrain):
			var textures = terrain.get_all_textures()
			var normals = []
			
			# Verify texture consistency
			for t in textures:
				if t.get_size() != Vector2(1024, 1024):
					push_error("Texture size mismatch in %s" % terrain.resource_path)
					return false
			
			var base_idx = all_textures.size()
			print("all textures size: ",all_textures.size())
			all_textures.append_array(textures)
			all_normals.resize(all_textures.size())
			
			# Store mapping
			terrain_index_map[terrain] = {
				"base_index": base_idx,
				"count": textures.size()
			}
	
	# Create texture arrays
	if all_textures.size() > 0:
		terrain_texture_array = create_texture_array(all_textures)
		#terrain_normal_array = create_texture_array(all_normals)
	
	return true

func create_texture_array(textures: Array[Texture2D]) -> Texture2DArray:
	var valid_images: Array[Image] = []
	
	# Validate and collect images
	for t in textures:
		if !t:
			push_error("Null texture in array, skipping")
			continue
			
		var img := t.get_image()
		if !img or img.is_empty():
			push_error("Invalid image in texture: %s" % t.resource_path)
			continue
			
		if valid_images.size() > 0:
			# Verify consistent dimensions
			if img.get_size() != valid_images[0].get_size():
				push_error("Texture size mismatch in %s" % t.resource_path)
				return null
				
		valid_images.append(img)
	
	if valid_images.is_empty():
		push_error("No valid images for texture array")
		return null
	
	# Create texture array from images
	var arr := Texture2DArray.new()
	var err := arr.create_from_images(valid_images)
	if err != OK:
		push_error("Failed to create texture array (code %d)" % err)
		return null
	
	
	
	return arr


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
## [br][param moving_unit] Optional UnitHandler attempting movement
func calculate_directional_cost_for_unit(source: HexCell, target: HexCell, moving_unit: UnitHandler = null) -> float:
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
	var start_id = _get_astar_id_from_world(start)
	var end_id = _get_astar_id_from_world(end)
	
	if !astar.has_point(start_id) || !astar.has_point(end_id):
		return []
	
	# Apply unit-specific mobility rules
	_apply_unit_mobility(unit)
	var path = astar.get_point_path(start_id, end_id)
	_reset_mobility()
	
	return path
	
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
		return true
	return false


#endregion

#region Helper Methods
func _get_r_range(q: int) -> Vector2i:
	return Vector2i(
		max(-radius, -q - radius),
		min(radius, -q + radius)
	)

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
	var results = []
	for q in range(-rang, rang + 1):
		var r_start = max(-rang, -q - rang)
		var r_end = min(rang, -q + rang)
		
		for r in range(r_start, r_end + 1):
			var s = -q - r
			var distance = (abs(q) + abs(r) + abs(s)) / 2
			if distance <= range:
				var coord = Vector2i(center.x + q, center.y + r)
				if hex_grid.has(coord):
					results.append(hex_grid[coord])
	return results
#endregion
