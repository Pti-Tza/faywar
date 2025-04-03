
extends Node3D
class_name HexGridGenerator


var redraw_line_grid_button: Callable = generate_grid

@export var terrain_mesh: Terrain3D
@export var auto_size: bool = true
@export var cell_size: float = 1.0
@export var grid_padding: float = 2.0  # Extra cells beyond terrain edges
@export var gen_on_start : bool

var grid_radius: int = 0
@export var grid_width: int = 10
@export var grid_height: int = 5
@export var hex : HexMapGenerator
@export var default_terrain_data: TerrainData
var cells: Array[HexCell] = []
var terrain_size 
func _ready() -> void:
	
	if gen_on_start:

		await get_tree().process_frame
		generate_grid()

func generate_grid():
	cells.clear()
	if auto_size:
		_calculate_grid_dimensions()
	
	# Hex layout calculations
	var hex_horizontal_spacing = cell_size * sqrt(3)
	var hex_vertical_spacing = cell_size * 1.5
	
	var hex_width = cell_size * sqrt(3)
	var hex_height = cell_size * 1.5
	

	var offset :Vector3
	if auto_size:
		offset = Vector3(terrain_size.x/2 - hex_width/2 ,0, terrain_size.z/2 - hex_height/2 )
	else:
		offset = Vector3(grid_width * hex_width/2,0, grid_height * hex_height/2 )
			
	for row in grid_height:
		for col in grid_width:
			
			# Offset coordinates for rectangle layout
			var q = col - (row >> 1)  # Offset-q axial coordinate
			var r = row
			
			var world_pos = axial_to_world(q, r) 
			world_pos = world_pos-offset
			var elevation = await sample_terrain_height(world_pos)
			
			var cell = HexCell.new(q,r,elevation)
			cell.initialize(q, r, elevation)
			cell.terrain_data = default_terrain_data
			cell.position = world_pos
			cell.elevation= elevation
			cells.append(cell)
			add_child(cell)
			
	hex._debug_draw_map(cells,offset)
	print("total cells ",cells.size())
func _calculate_grid_dimensions():
	if !terrain_mesh || !terrain_mesh.mesh:
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
	var result = space_state.intersect_ray(query)
	if result:
		print(pos)
		print(result.position)
		print('-------')
		return result.position.y
	else:
		
		
		return 0.0
	#return  if result else 0.0


func _on_terrain_3d_ready() -> void:
	generate_grid()
