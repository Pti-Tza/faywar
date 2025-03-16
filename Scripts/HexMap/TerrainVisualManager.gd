# TerrainVisualManager.gd
extends Node
class_name TerrainVisualManager
## Manages visual blending between different terrain types on hex grid cells

signal terrain_visuals_updated(cell: HexCell)

@export_category("Configuration")
## Reference to terrain data resource
@export var terrain_data: TerrainData
## Transition distance in grid units (1.0 = immediate neighbor)
@export var transition_distance: float = 1.0
## Reference to grid manager system
@export var grid_manager: HexGridManager

@export_category("Advanced")
## Maximum simultaneous blends per material
@export var max_blends: int = 4 : 
	set(value):
		max_blends = clamp(value, 2, 8)

# Internal state
var _cell_materials: Dictionary = {}  # HexCell: {base: Material, blend: ShaderMaterial}
var _terrain_material_cache: Dictionary = {}

func _ready() -> void:
	if !grid_manager:
		push_error("TerrainVisualManager: Missing GridManager reference")
		return
	grid_manager.cell_updated.connect(_on_cell_updated)

func initialize_visuals(grid: Array[HexCell]) -> void:
	for cell in grid:
		_create_cell_material(cell)
		_calculate_blend_factors(cell)

func _on_cell_updated(q: int, r: int) -> void:
	var cell = grid_manager.get_cell(q, r)
	if cell:
		_update_cell_visuals(cell)
		_update_neighbor_visuals(cell)

func _create_cell_material(cell: HexCell) -> void:
	if !cell.mesh:
		push_warning("Cell %s missing mesh reference" % cell.name)
		return
	
	var blend_mat = ShaderMaterial.new()
	blend_mat.shader = preload("res://Shaders/terrain_blend.gdshader")
	
	# Initialize with empty textures
	blend_mat.set_shader_parameter("base_albedo", null)
	blend_mat.set_shader_parameter("base_normal", null)
	blend_mat.set_shader_parameter("blend_textures", [])
	blend_mat.set_shader_parameter("transition_distance", transition_distance)
	
	_cell_materials[cell] = {
		"blend": blend_mat
	}
	cell.mesh.material_override = blend_mat
	
	# Initial update
	_update_cell_visuals(cell)

func _update_cell_visuals(cell: HexCell) -> void:
	var mats = _cell_materials.get(cell)
	if !mats || !mats.blend:
		return
	
	var base_mat = _get_terrain_material(cell.terrain_id)
	mats.blend.set_shader_parameter("base_albedo", base_mat.albedo_texture)
	mats.blend.set_shader_parameter("base_normal", base_mat.normal_texture)

func _update_neighbor_visuals(cell: HexCell) -> void:
	for neighbor in grid_manager.get_neighbors(cell.q, cell.r):
		_calculate_blend_factors(neighbor)

func _calculate_blend_factors(cell: HexCell) -> void:
	var mats = _cell_materials.get(cell)
	if !mats || !mats.blend:
		return
	
	var blend_data = []
	for neighbor in grid_manager.get_neighbors(cell.q, cell.r):
		if neighbor.terrain_id != cell.terrain_id:
			var n_mat = _get_terrain_material(neighbor.terrain_id)
			var dir = (neighbor.position - cell.position).normalized()
			blend_data.append({
				"albedo": n_mat.albedo_texture,
				"normal": n_mat.normal_texture,
				"direction": Vector2(dir.x, dir.z)  # Convert to 2D for shader
			})
			if blend_data.size() >= max_blends:
				break
	
	mats.blend.set_shader_parameter("blend_textures", blend_data)
	terrain_visuals_updated.emit(cell)

func _get_terrain_material(terrain_id: String) -> Material:
	if !_terrain_material_cache.has(terrain_id):
		var terrain = terrain_data.get_terrain_type(terrain_id)
		_terrain_material_cache[terrain_id] = terrain.get_random_variant_material()
	return _terrain_material_cache[terrain_id]

func _exit_tree() -> void:
	for cell in _cell_materials:
		if cell.mesh:
			cell.mesh.material_override = null
	_cell_materials.clear()
	_terrain_material_cache.clear()
