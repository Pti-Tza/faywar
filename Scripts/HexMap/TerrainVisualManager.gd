# TerrainVisualManager.gd
extends Node3D
class_name TerrainVisualManager
## Manages dynamic terrain blending between adjacent hex cells

signal terrain_visuals_updated(cell: HexCell)

@export_category("Configuration")

@export var transition_distance: float = 1.0
@export var blend_sharpness: float = 0.5
@export var grid_manager: HexGridManager

@export_category("Performance")
@export var max_active_blends: int = 4:
	set(value):
		max_active_blends = clamp(value, 2, 6)

# Internal state management
var _cell_materials := {}
var _terrain_material_cache := {}
var _neighbor_cache := {}

func _ready() -> void:
	print("Visuals ready")
	initialize_grid_connections()
	#preload_terrain_materials()

func initialize_grid_connections() -> void:
	print("Visuals ready2")
	if not HexGridManager.instance:
		push_error("HexGridManager instance not available")
		return
	print("Visuals ready3")
	grid_manager = HexGridManager.instance
	HexGridManager.instance.cell_updated.connect(_on_cell_updated)
	HexGridManager.instance.grid_initialized.connect(_on_grid_initialized)

#func preload_terrain_materials() -> void:
#	for terrain_id in terrain_data.terrains:
#		_get_terrain_material(terrain_id)

func _on_grid_initialized() -> void:
	print("initializing_visuals0")
	initialize_visuals(grid_manager.cells)

func initialize_visuals(grid: Array[HexCell]) -> void:
	print("initializing_visuals")
	for cell in grid:
		if not is_instance_valid(cell):
			continue
		_create_cell_material(cell)
		_update_cell_neighbors(cell)

func _create_cell_material(cell: HexCell) -> void:
	var blend_mat = ShaderMaterial.new()
	blend_mat.shader = preload("res://Shaders/terrain_blend.gdshader")
	
	# Initialize default parameters
	blend_mat.set_shader_parameter("transition_distance", transition_distance)
	blend_mat.set_shader_parameter("blend_sharpness", blend_sharpness)
	reset_blend_arrays(blend_mat)
	
	_cell_materials[cell] = {
		"material": blend_mat,
		"neighbors": []
	}
	
	if cell.mesh_instance:
		cell.mesh_instance.material_override = blend_mat
	else:
		push_warning("Cell %s has no mesh instance" % cell.name)
	
	_update_cell_visuals(cell)

func reset_blend_arrays(material: ShaderMaterial) -> void:
	material.set_shader_parameter("active_blend_count", 0)
	material.set_shader_parameter("blend_albedos", [])
	material.set_shader_parameter("blend_normals", [])
	material.set_shader_parameter("blend_directions", [])

func _update_cell_visuals(cell: HexCell) -> void:
	var mats = _cell_materials.get(cell)
	if not mats:
		return
	
	#var base_mat = _get_terrain_material(cell.terrain_id)
	#Only standart material untill
	#var base_mat = _get_terrain_material(cell.terrain_data.visual_material.resource_name)
	#if not base_mat:
		return
	
	#mats.material.set_shader_parameter("base_albedo", base_mat.albedo_texture)
	#mats.material.set_shader_parameter("base_normal", base_mat.normal_texture)
	_calculate_blend_factors(cell)

func _calculate_blend_factors(cell: HexCell) -> void:
	var mats = _cell_materials.get(cell)
	if not mats:
		return
	
	var valid_neighbors = grid_manager.get_neighbors(cell.q, cell.r).filter(
		func(n): return is_instance_valid(n) #and n.terrain_id != cell.terrain_id
	)
	
	var blend_albedos = []
	var blend_normals = []
	var blend_directions = []
	
	for neighbor in valid_neighbors.slice(0, max_active_blends - 1):
		var n_mat = neighbor.mesh_instance.material_override
		if not n_mat:
			continue
		
		var dir_vec = (neighbor.global_position - cell.global_position).normalized()
		var dir_2d = Vector2(dir_vec.x, dir_vec.z).normalized()
		
		blend_albedos.append(n_mat.albedo_texture)
		blend_normals.append(n_mat.normal_texture)
		blend_directions.append(dir_2d)
	
	mats.material.set_shader_parameter("active_blend_count", blend_albedos.size())
	mats.material.set_shader_parameter("blend_albedos", blend_albedos)
	mats.material.set_shader_parameter("blend_normals", blend_normals)
	mats.material.set_shader_parameter("blend_directions", blend_directions)
	
	terrain_visuals_updated.emit(cell)

func _update_cell_neighbors(cell: HexCell) -> void:
	for neighbor in grid_manager.get_neighbors(cell.q, cell.r):
		if is_instance_valid(neighbor):
			_calculate_blend_factors(neighbor)

#func _get_terrain_material(terrain_id: String) -> Material:
#	if not _terrain_material_cache.has(terrain_id):
#		var terrain = terrain_data.get_terrain(terrain_id)
#		if terrain:
#			_terrain_material_cache[terrain_id] = terrain.get_variant_material()
#		else:
#			push_error("Missing terrain type: %s" % terrain_id)
#			return StandardMaterial3D.new()
#	return _terrain_material_cache[terrain_id]

func _on_cell_updated(q: int, r: int) -> void:
	var cell = grid_manager.get_cell(q, r)
	if is_instance_valid(cell):
		_update_cell_visuals(cell)
		_update_cell_neighbors(cell)

func _exit_tree() -> void:
	for cell in _cell_materials:
		if is_instance_valid(cell) and cell.mesh:
			cell.mesh.material_override = null
	_cell_materials.clear()
	_terrain_material_cache.clear()
