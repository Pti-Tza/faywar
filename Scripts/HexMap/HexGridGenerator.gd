
extends Node3D
class_name HexGridGenerator


#This script generates Hex terrain passability data using existing TerrainMesh Textures and slopes 


#@export_tool_button("Generate grid") var redraw_line_grid_button: Callable = generate_grid
#@export_tool_button("Clear Child") var clear_button: Callable = clear_child

@export var auto_gen: bool 

@export var grid_manager: HexGridManager
@export var terrain_mesh: Terrain3D
@export var auto_size: bool = true
@export var cell_size: float = 1.0
@export var grid_padding: float = 2.0  # Extra cells beyond terrain edges
@export var gen_on_start : bool

var grid_radius: int = 0

@export var terrain_width : float = 512
@export var terrain_height : float = 512

var grid_width: int = 10
var grid_height: int = 10

@export var default_terrain_data: TerrainData
@export var slope_terrain_data: TerrainData
@export var terrain_datas: Array[TerrainData] = []
@export var generate_debug_mesh: bool
@export var debug_mesh: MeshInstance3D

@export var debug_colors: Dictionary = {
	"water": Color.SKY_BLUE,
	"plains": Color.LAWN_GREEN,
	"forest": Color.FOREST_GREEN,
	"mountain": Color.SADDLE_BROWN
}

var cells: Array[HexCell] = []
var terrain_size

# Multi-level generation parameters
@export var max_levels: int = 5  # Maximum number of levels to generate
@export var level_spacing: float = 3.0  # Vertical spacing between levels
@export var enable_multi_level_generation: bool = false  # Toggle for multi-level generation

func _ready() -> void:
	
	if gen_on_start:

		await get_tree().process_frame
		generate_grid()
func _process(delta: float) -> void:
	if auto_gen:
		await get_tree().process_frame
		generate_grid()

func generate_grid():
	clear_child()
	await get_tree().process_frame
	if auto_size:
		_calculate_grid_dimensions()
	
	# Hex layout calculations
	var hex_width = cell_size * sqrt(3)
	var hex_height = cell_size * 1.5
	
	grid_width = int(terrain_width / hex_width)
	grid_height = int(terrain_height / hex_height)
	
	var half_width : int = grid_width / 2
	var half_height : int = grid_height / 2
	
	var offset :Vector3
	if auto_size:
		#offset = Vector3(terrain_size.x/2 - hex_width/2 ,0, terrain_size.z/2 - hex_height/2 )
		offset = Vector3.ZERO
	else:
		#offset = Vector3(terrain_width/2,0, terrain_height/2 )
		offset = Vector3.ZERO
	
	# Generate cells for multiple levels if enabled
	if enable_multi_level_generation:
		for level in range(max_levels):
			_generate_level_cells(half_width, half_height, level, offset)
	else:
		# Generate only ground level cells (existing behavior)
		for row in range(grid_height):
			for col in range(grid_width):
				
				
				# Convert to centered integer indices
				var centered_col = col - half_width
				var centered_row = row - half_height

				# For flat-topped hexes in "odd-r" layout:
				var q = centered_col - (centered_row >> 1)
				var r = centered_row
				
				var world_pos = axial_to_world(q, r)
				#world_pos = world_pos-offset
				var elevation = await sample_terrain_height(world_pos)
				
				var cell = HexCell.new(q, r, elevation, grid_manager, Vector3.ZERO, 0)  # Level 0 for ground level
				
				if terrain_mesh.data.get_texture_id(world_pos) != null:
					if terrain_datas.size() > int(terrain_mesh.data.get_texture_id(world_pos).x) and terrain_datas[int(terrain_mesh.data.get_texture_id(world_pos).x)] != null and not terrain_mesh.data.get_control_auto(world_pos):
						cell.terrain_data = terrain_datas[int(terrain_mesh.data.get_texture_id(world_pos).x)]
				else:
					cell.terrain_data = default_terrain_data
					
				if get_terrain_slope_angle(world_pos) > 40:
					cell.terrain_data = slope_terrain_data
				cell.position = grid_manager.axial_to_world_3d(q, r, 0)  # Position with level 0 using HexGridManager function
				cell.elevation = elevation
				cells.append(cell)
				add_child(cell)
	
	if generate_debug_mesh:
		_debug_draw_map(cells,offset)
	grid_manager.initialize_from_data(cells)
	print("total cells ",cells.size())

## Generate cells for a specific level
func _generate_level_cells(half_width: int, half_height: int, level: int, offset: Vector3):
	for row in range(grid_height):
		for col in range(grid_width):
			
			# Convert to centered integer indices
			var centered_col = col - half_width
			var centered_row = row - half_height

			# For flat-topped hexes in "odd-r" layout:
			var q = centered_col - (centered_row >> 1)
			var r = centered_row
			
			var world_pos = axial_to_world(q, r)
			# Adjust world position for level height
			var level_elevation = await sample_terrain_height(world_pos)
			var level_world_pos = Vector3(world_pos.x, level_elevation + (level * level_spacing), world_pos.z)
			
			var cell = HexCell.new(q, r, level_elevation, grid_manager, Vector3.ZERO, level)
			
			# For higher levels, terrain data might be different based on structure
			if level == 0:  # Ground level
				if terrain_mesh.data.get_texture_id(world_pos) != null:
					if terrain_datas.size() > int(terrain_mesh.data.get_texture_id(world_pos).x) and terrain_datas[int(terrain_mesh.data.get_texture_id(world_pos).x)] != null and not terrain_mesh.data.get_control_auto(world_pos):
						cell.terrain_data = terrain_datas[int(terrain_mesh.data.get_texture_id(world_pos).x)]
				else:
					cell.terrain_data = default_terrain_data
					
				if get_terrain_slope_angle(world_pos) > 40:
					cell.terrain_data = slope_terrain_data
			else:
				# For upper levels, determine appropriate terrain based on structure type
				# This is a simplified approach - in a real implementation, you'd have specific rules for bridges, floors, etc.
				var underlying_cell = _get_ground_level_cell(q, r)
				if underlying_cell:
					# Copy terrain data from underlying cell for simple structures
					cell.terrain_data = underlying_cell.terrain_data
					# Set structure type based on level
					if level == 1:
						cell.structure_type = HexCell.StructureType.BRIDGE
					elif level > 1:
						cell.structure_type = HexCell.StructureType.FLOOR  # Using correct enum value from HexCell
				else:
					cell.terrain_data = default_terrain_data
					
			# Set position with proper 3D coordinates
			cell.position = grid_manager.axial_to_world_3d(q, r, level)
			cell.elevation = level_elevation  # Fixed variable name
			cells.append(cell)
			add_child(cell)

## Helper function to get ground level cell at specific coordinates
func _get_ground_level_cell(q: int, r: int) -> HexCell:
	for cell in cells:
		if cell.q == q and cell.r == r and cell.level == 0:
			return cell
	return null
func _calculate_grid_dimensions():
	if !terrain_mesh:
		push_error("No terrain mesh assigned!")
		return
	
	# Get terrain bounds
	var aabb = terrain_mesh.mesh.get_aabb()
	terrain_size = aabb.size * terrain_mesh.scale
	
	# Calculate grid dimensions based on terrain size and aspect ratio
	var hex_width = cell_size * sqrt(3)
	var hex_height = cell_size * 2.0
	
	# Calculate maximum possible cells while maintaining aspect ratio
	var target_width = terrain_size.x / hex_width
	var target_height = terrain_size.z / hex_height
	
	## Adjust for aspect ratio
	#var ratio = grid_width / grid_height
	#if target_width / target_height > ratio:
		#grid_height = floor(target_height)
		#grid_width = floor(grid_height * ratio)
	#else:
		#grid_width = floor(target_width)
		#grid_height = floor(grid_width / ratio)
	#
	## Ensure minimum size
	#grid_width = max(grid_width, 1)
	#grid_height = max(grid_height, 1)
	
	grid_width = target_width
	grid_height = target_height
	

func axial_to_world(q: int, r: int) -> Vector3:
	var x = cell_size * (sqrt(3) * q + sqrt(3)/2 * r)
	var z = cell_size * (3.0/2 * r)
	return Vector3(x, 0, z)

func sample_terrain_height(pos: Vector3) -> float:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		pos + Vector3.UP * 1000+Vector3.RIGHT, 
		pos + Vector3.DOWN * 1000+Vector3.FORWARD,
		
	)
	query.hit_back_faces=true
	query.hit_from_inside=true
	query.collide_with_areas=true
	#var result = space_state.intersect_ray(query)
	var result = terrain_mesh.data.get_height(pos)
	return result
	#if result:
		#print(pos)
		#print(result.position)
		#print('-------')
		#return result.position.y
	#else:
		#
		#
		#return 0.0
	##return  if result else 0.0
func get_terrain_slope_angle(global_pos: Vector3) -> float:
	# Get the terrain normal at this position
	var normal: Vector3 = terrain_mesh.data.get_normal(global_pos)
	
	# Calculate angle between normal and vertical (up) direction
	var angle_rad: float = normal.angle_to(Vector3.UP)
	
	# Convert to degrees for readability
	var angle_deg: float = rad_to_deg(angle_rad)
	
	return angle_deg

func _debug_draw_map(_cells: Array[HexCell],offset: Vector3 = Vector3.ZERO):
	debug_mesh.mesh = null
	if _cells.is_empty():
		push_warning("Nothing to draw - empty cell array")
		return

	var im = ImmediateMesh.new()

	var default_color = Color.GRAY
	var terrain_groups = {}

	# Battletech terrain grouping
	for cell : HexCell in _cells:
		var terrain_name = "unknown"
		if cell.terrain_data.name:
			terrain_name = cell.terrain_data.name.to_lower()
		
		if not terrain_groups.has(terrain_name):
			terrain_groups[terrain_name] = []
		terrain_groups[terrain_name].append(cell)

	# Draw known terrains first
	for terrain_key in debug_colors:
		var terrain_name = terrain_key.to_lower()
		if terrain_groups.has(terrain_name):
			var color = debug_colors[terrain_key]
			_draw_terrain_surface(im, terrain_groups[terrain_name], color, grid_manager,offset)
			terrain_groups.erase(terrain_name)

	# Draw remaining terrains with default color
	for terrain_name in terrain_groups:
		_draw_terrain_surface(im, terrain_groups[terrain_name], default_color, grid_manager,offset)

	if im.get_surface_count() > 0:
		var mesh_instance = debug_mesh
		mesh_instance.mesh = im
		#add_child(mesh_instance)
	else:
		im.mesh = null

func _draw_terrain_surface(im: ImmediateMesh, _cells: Array, color: Color, _hex_grid: HexGridManager,offset: Vector3 = Vector3.ZERO):
	if _cells.is_empty():
		return

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	
	# Battletech-standard hex visualization
	for cell in _cells:
		var center = axial_to_world(cell.q, cell.r) - offset
		var elevation = cell.elevation * grid_manager.level_height_step
		
		for i in 6:
			var angle = deg_to_rad(60 * i + 30)  # Official BT rotation
			var next_angle = deg_to_rad(60 * (i + 1) + 30)
			var radius = grid_manager.outer_radius
			
			var point = center + Vector3(
				radius * cos(angle),
				elevation,
				radius * sin(angle)
			)
			
			var next_point = center + Vector3(
				radius * cos(next_angle),
				elevation,
				radius * sin(next_angle)
			)
			
			im.surface_add_vertex(point)
			im.surface_add_vertex(next_point)
	
	im.surface_end()
	
func clear_child():
	#debug_mesh.mesh = null
	var children = get_children()
	for child in children:
		child.free()
	cells.clear()
