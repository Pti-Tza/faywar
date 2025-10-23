extends Node3D
class_name HexHoverHighlighter

@export var grid_manager: HexGridManager
@export var decal_highlighter: HexDecalHighlighter
@export var highlight_radius: int = 2
@export var center_color: Color = Color.YELLOW
@export var ring_color: Color = Color(0.5, 0.5, 0, 0.7)  # Semi-transparent amber


var _current_center: HexCell = null
var _last_position: Vector3 = Vector3.ZERO
var _update_threshold: float = 0.1  # Update when cursor moves this far

func _ready():
	# Validate dependencies
	assert(grid_manager != null, "HexGridManager reference required")
	assert(decal_highlighter != null, "DecalHighlighter reference required")
	
	# Initial setup
	decal_highlighter.clear_highlights()

func _process(_delta):
	# Only update if cursor has moved significantly
	var cursor_pos : Vector3 = _get_cursor_world_position()
	if cursor_pos.distance_to(_last_position) > _update_threshold:
		_update_hover_highlight(cursor_pos)
		#print(" pos ", cursor_pos)
		_last_position = cursor_pos

func _update_hover_highlight(cursor_pos: Vector3):
	print(" cursor", cursor_pos)
	var new_center : HexCell = grid_manager.get_cell_at_position(cursor_pos)
	#print(" axial ", grid_manager.world_to_axial(cursor_pos))
	
	if new_center==null:
		return
	
	print(" coords", new_center.axial_coords)
	# Only update if center cell changed
	if new_center != _current_center:
		_current_center = new_center
		_highlight_circle(new_center)

func _highlight_circle(center_cell: HexCell):
	if !center_cell:
		decal_highlighter.clear_highlights()
		return
	
	var cells : Array[HexCell] = grid_manager.get_cells_in_range(center_cell.axial_coords, highlight_radius)
	var colored_cells = []
	
	if(cells.size()==0):
		return
	
	# Apply different colors based on distance
	for cell in cells:
		var distance = grid_manager.get_hex_distance(
			center_cell.axial_coords, 
			cell.axial_coords
		)
		
		var color = ring_color
		if distance == 0:
			color = center_color
		elif distance == 1:
			color = ring_color.lightened(0.2)
		
		colored_cells.append({
			"cell": cell,
			"color": color
		})
	
	# Update decals with new highlights
	decal_highlighter.highlight_colored_cells(colored_cells)

func _get_cursor_world_position() -> Vector3:
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Create ray from camera through mouse position
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_dir * 1000
	
	# Perform raycast against terrain
	var params = PhysicsRayQueryParameters3D.new()
	params.from = ray_origin
	params.to = ray_end
	params.collide_with_areas = true
	
	var result = get_world_3d().direct_space_state.intersect_ray(params)
	return result.position if result else ray_end

func set_highlight_radius(new_radius: int):
	highlight_radius = clamp(new_radius, 1, 5)
	if _current_center:
		_highlight_circle(_current_center)

func clear_highlights():
	decal_highlighter.clear_highlights()
	_current_center = null
