# HexMapGenerator.gd
extends Node3D
class_name HexMapGenerator

@export_category("Generation Settings")
@export var grid_radius: int = 10
@export var terrain_types: Array[TerrainData] = []
@export var height_params: Dictionary = {
	"min_elevation": 0,
	"max_elevation": 5,
	"noise_scale": 0.1,
	"octaves": 3
}

@export_category("Visualization")
@export var debug_colors: Dictionary = {
	"water": Color.SKY_BLUE,
	"plains": Color.LAWN_GREEN,
	"forest": Color.FOREST_GREEN,
	"mountain": Color.SADDLE_BROWN
}

@export var generation_presets = {
	"island": {
		"noise_type": FastNoiseLite.TYPE_PERLIN,
		"base_frequency": 0.05,
		"terrain_weights": {
			"water": 0.4,
			"sand": 0.1,
			"grass": 0.3,
			"forest": 0.2
		}
	},
	"continent": {
		"noise_type": FastNoiseLite.TYPE_SIMPLEX,
		"base_frequency": 0.03,
		"terrain_weights": {
			"water": 0.3,
			"plains": 0.4,
			"mountain": 0.3
		}
	}
}


@export var generate_on_start: bool = false


var noise := FastNoiseLite.new()

func _ready():
	print("HexMapGeneratorReady")
	configure_noise()
	if generate_on_start:
		_test_generate_map()

func configure_noise() -> void:
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = randi()
	noise.frequency = 0.05
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.0

func generate_map() -> Array[HexCell]:
	var cells: Array[HexCell] = []
	_debug_draw_map(cells)
	for q in range(-grid_radius, grid_radius + 1):
		var r1 = max(-grid_radius, -q - grid_radius)
		var r2 = min(grid_radius, -q + grid_radius)
	
		for r in range(r1, r2 + 1):
			var cell = HexCell.new(q, r)  
			cell.initialize(q, r)  # Initialize with coordinates
			cell.position = HexGridManager.instance.axial_to_world(q, r)
			var s = -q - r
			
			# Generate terrain
			var terrain = generate_terrain(q, r, s)
			cell.terrain_data = terrain
			
			# Generate elevation
			cell.elevation = generate_elevation(q, r, s)
			
			cells.append(cell)
	print("Generated %d cells" % cells.size())
	if cells.size() > 0:
		print("First cell position: ", cells[0].position)
		print("First cell terrain: ", cells[0].terrain_data.name)
	return cells

func generate_terrain(q: int, r: int, s: int) -> TerrainData:
	var noise_value = noise.get_noise_2d(q, r)
	
	# Water (30% chance)
	if noise_value < -0.4:
		return get_terrain_by_name("water")
	
	# Plains (40% chance)
	elif noise_value < 0.2:
		return get_terrain_by_name("plains")
	
	# Forest (20% chance)
	elif noise_value < 0.6:
		return get_terrain_by_name("forest")
	
	# Mountain (10% chance)
	else:
		return get_terrain_by_name("mountain")

func generate_elevation(q: int, r: int, s: int) -> int:
	var elevation_noise = noise.get_noise_3d(q, r, s)
	var normalized = (elevation_noise + 1.0) / 2.0  # Convert to 0-1 range
	return clamp(
		round(normalized * height_params.max_elevation),
		height_params.min_elevation,
		height_params.max_elevation
	)

func get_terrain_by_name(name: String) -> TerrainData:
	for terrain in terrain_types:
		if terrain.name.to_lower() == name.to_lower():
			return terrain
	push_error("Terrain type %s not found" % name)
	return null

func debug_draw_map(cells: Array[HexCell]) -> void:
	for cell in cells:
		var color = debug_colors.get(cell.terrain_data.name.to_lower(), Color.WHITE)
		color = color.darkened(0.1 * cell.elevation)
		draw_hex(cell.position, color, str(cell.elevation))

func draw_hex(position: Vector3, color: Color, label: String) -> void:
	# Implementation depends on your debug drawing system
	pass

func _test_generate_map():
	var cells = generate_map()
	
	# Validate generation
	assert(cells.size() > 0, "Failed to generate cells")
	
	var terrain_counts = {}
	for cell in cells:
		var terrain_name = cell.terrain_data.name
		terrain_counts[terrain_name] = terrain_counts.get(terrain_name, 0) + 1
	
	print("Terrain Distribution:")
	for terrain in terrain_counts:
		print("- %s: %d" % [terrain, terrain_counts[terrain]])
	
	HexGridManager.instance.initialize_from_data(cells)
	# Visual debug
	_debug_draw_map(cells)


func _debug_draw_map(cells: Array[HexCell]):
	# Add immediate geometry visualization
	var im = ImmediateMesh.new()
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	var hex_grid = HexGridManager.instance

	for cell in cells:
		var center = hex_grid.axial_to_world(cell.q, cell.r)
		im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
		
		# Draw hex outline
		for i in 6:
			var angle_deg = 60 * i + 30
			var next_angle_deg = 60 * ((i + 1) % 6) + 30
			var radius = hex_grid.hex_size
			
			var point = center + Vector3(
				radius * cos(deg_to_rad(angle_deg)),
				0,
				radius * sin(deg_to_rad(angle_deg))
			)
			
			var next_point = center + Vector3(
				radius * cos(deg_to_rad(next_angle_deg)),
				0,
				radius * sin(deg_to_rad(next_angle_deg))
			)
			
			im.surface_add_vertex(point)
			im.surface_add_vertex(next_point)
		
		im.surface_end()
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = im
	add_child(mesh_instance)        
