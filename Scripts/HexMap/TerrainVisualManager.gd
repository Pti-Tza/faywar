
extends Node
class_name TerrainVisualManager
# terrain_visual_manager.gd
signal terrain_visuals_updated(cell: HexCell)

# Configuration
@export var terrain_data: TerrainData
@export var transition_distance: float = 1.0  # How far transitions spread (in cells)

# Visual cache
var _cell_materials: Dictionary = {}  # HexCell: Array[ShaderMaterial]

func _ready() -> void:
	HexGridManager.cell_updated.connect(_on_cell_updated)

func initialize_visuals(grid: Array[HexCell]) -> void:
	for cell in grid:
		_create_cell_material(cell)
		_update_cell_neighbor_blends(cell)

func _on_cell_updated(q: int, r: int) -> void:
	var cell = HexGridManager.get_cell(q, r)
	if cell:
		_update_cell_visuals(cell)
		_update_neighbor_visuals(cell)

func _create_cell_material(cell: HexCell) -> void:
	var terrain_type = terrain_data.get_terrain_type(cell.terrain_id)
	var base_material = terrain_type.get_random_variant_material()
	var blend_material = ShaderMaterial.new()
	blend_material.shader = preload("res://shaders/terrain_blend.gdshader")
	
	blend_material.set_shader_parameter("base_albedo", base_material.albedo_texture)
	blend_material.set_shader_parameter("base_normal", base_material.normal_texture)
	blend_material.set_shader_parameter("blend_albedo", null)
	blend_material.set_shader_parameter("blend_normal", null)
	blend_material.set_shader_parameter("blend_factor", 0.0)
	
	_cell_materials[cell] = {
		"base": base_material,
		"blend_material": blend_material
	}
	cell.mesh.material_override = blend_material

func _update_cell_visuals(cell: HexCell) -> void:
	var materials = _cell_materials.get(cell)
	if not materials:
		return
	
	var terrain_type = terrain_data.get_terrain_type(cell.terrain_id)
	materials["base"] = terrain_type.get_random_variant_material()
	materials["blend_material"].set_shader_parameter("base_albedo", materials["base"].albedo_texture)
	materials["blend_material"].set_shader_parameter("base_normal", materials["base"].normal_texture)
	_calculate_blend_factors(cell)

func _update_neighbor_visuals(cell: HexCell) -> void:
	for neighbor in HexGridManager.get_neighbors(cell.q, cell.r):
		_calculate_blend_factors(neighbor)

func _calculate_blend_factors(cell: HexCell) -> void:
	var materials = _cell_materials.get(cell)
	if not materials:
		return
	
	var blend_textures = []
	var blend_weights = []
	
	for neighbor in HexGridManager.get_neighbors(cell.q, cell.r):
		var neighbor_terrain = terrain_data.get_terrain_type(neighbor.terrain_id)
		if neighbor_terrain.id != cell.terrain_id:
			var blend_material = neighbor_terrain.get_random_variant_material()
			blend_textures.append({
				"albedo": blend_material.albedo_texture,
				"normal": blend_material.normal_texture,
				"direction": neighbor.position - cell.position
			})
	
	# Update shader parameters
	materials["blend_material"].set_shader_parameter("blend_textures", blend_textures)
	materials["blend_material"].set_shader_parameter("transition_distance", transition_distance)
	
	terrain_visuals_updated.emit(cell)
