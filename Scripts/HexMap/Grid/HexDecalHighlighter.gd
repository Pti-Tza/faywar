class_name HexDecalHighlighter
extends Node3D

@export var decal_scene: PackedScene
@export var max_active_decals: int = 30
@export var decal_height_offset: float = 0.1

@export var hex_grid_manager: HexGridManager

var _decals_pool: Array[Decal] = []
var _active_decals: Array[Decal] = []
static var instance : HexDecalHighlighter 

func _ready():
	instance = self
	_initialize_decal_pool()

func _initialize_decal_pool():
	for i in max_active_decals:
		var decal = decal_scene.instantiate()
		decal.visible = false
		add_child(decal)
		_decals_pool.append(decal)

func highlight_cells(cells: Array[HexCell]):
	clear_highlights()
	
	for cell in cells:
		var decal = _get_available_decal()
		if decal:
			_position_decal(decal, cell)
			decal.visible = true
			_active_decals.append(decal)

func clear_highlights():
	for decal in _active_decals:
		decal.visible = false
		_decals_pool.append(decal)
	_active_decals.clear()

func _get_available_decal() -> Decal:
	if _decals_pool.is_empty():
		return null
	return _decals_pool.pop_back()

func _position_decal(decal: Decal, cell: HexCell):
	#var terrain_position : Vector3 = _get_terrain_position(cell)
	var terrain_position : Vector3 = cell._global_position
	#var normal : Vector3 = _get_terrain_normal(cell)
	
	decal.position = terrain_position + Vector3.UP * decal_height_offset
	#decal.rotation = normal.quar

func _get_terrain_position(cell: HexCell) -> Vector3:
	var grid_pos = hex_grid_manager.axial_to_world(cell.q, cell.r)
	var ray = PhysicsRayQueryParameters3D.new()
	ray.from = grid_pos + Vector3(0, 100, 0)
	ray.to = grid_pos - Vector3(0, 100, 0)
	
	var result = get_world_3d().direct_space_state.intersect_ray(ray)
	return result.position if result else grid_pos

func _get_terrain_normal(cell: HexCell) -> Vector3:
	var grid_pos = hex_grid_manager.axial_to_world(cell.q, cell.r)
	var ray = PhysicsRayQueryParameters3D.new()
	ray.from = grid_pos + Vector3(0, 100, 0)
	ray.to = grid_pos - Vector3(0, 100, 0)
	
	var result = get_world_3d().direct_space_state.intersect_ray(ray)
	return result.normal if result else Vector3.UP


func highlight_colored_cells(colored_cells: Array):
	clear_highlights()
	
	for item in colored_cells:
		var cell = item["cell"]
		var color = item["color"]
		var decal = _get_available_decal()
		
		if decal:
			_position_decal(decal, cell)
			_set_decal_color(decal, color)
			decal.visible = true
			_active_decals.append(decal)

func _set_decal_color(decal: Decal, color: Color):
	decal.modulate = color
