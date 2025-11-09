# UI/HexInfoPanel.gd
# A UI panel that displays information about the hex cell the cursor is hovering over
extends Control

## Emitted when a hex cell is hovered over
signal hex_hovered(cell: HexCell)
## Emitted when the mouse leaves a hex cell
signal hex_unhovered

@onready var _camera := get_viewport().get_camera_3d()

var current_hex_cell: HexCell = null
var hover_timer := 0.0
@export var hover_delay := 0.1  # Delay in seconds before showing info

@export var show_on_hover := true  # Whether to show info on hover or only when requested
@export var auto_update := true    # Whether to automatically update the panel

# UI elements that will be populated with hex information
@export var title_label: Label 
@export var coordinates_label: Label 
@export var elevation_label: Label 
@export var terrain_label: Label 
@export var movement_costs_label: Label 
@export var cover_label: Label 
@export var occupancy_label: Label 
@export var structure_label: Label 

func _ready() -> void:
	# Hide the panel by default
	hide()
	
	# Connect to the hex click handler if it exists
	if HexClickHandler.instance:
		# We'll use the same raycast logic for hover detection
		pass

func _process(delta: float) -> void:
	if auto_update and show_on_hover:
		_update_hovered_hex(delta)

func _update_hovered_hex(delta: float) -> void:
	var hovered_cell = _get_hovered_hex_cell()
	
	if hovered_cell != current_hex_cell:
		# Hex cell changed
		if current_hex_cell:
			# Emit signal for previous cell
			hex_unhovered.emit()
		
		current_hex_cell = hovered_cell
		
		if current_hex_cell:
			# Reset hover timer for new cell
			hover_timer = 0.0
			# Emit signal for new cell
			hex_hovered.emit(current_hex_cell)
		else:
			# Hide panel if no cell is hovered
			hide()
	
	if current_hex_cell:
		hover_timer += delta
		if hover_timer >= hover_delay:
			_update_hex_info(current_hex_cell)
			show()

func _get_hovered_hex_cell() -> HexCell:
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	
	# Check if mouse is over UI elements
	if _is_mouse_over_ui(mouse_pos):
		return null
	
	# Skip if mouse is over any UI control
	if _is_mouse_over_any_ui_control():
		return null
	
	# Convert to world coordinates for raycast
	var from = _camera.project_ray_origin(mouse_pos)
	var to = from + _camera.project_ray_normal(mouse_pos) * 1000
	
	# Perform raycast to get the clicked object
	var space_state = viewport.world_3d.direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		return null
	
	# Get the hex cell at the clicked position
	var world_pos = result.position
	var hex_cell = HexGridManager.instance.get_cell_at_position_3d(world_pos)
	
	return hex_cell

func _is_mouse_over_ui(mouse_pos: Vector2) -> bool:
	# Check if mouse is over this panel specifically
	if get_global_rect().has_point(mouse_pos):
		return true
	return false

func _is_mouse_over_any_ui_control() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	for control in get_tree().get_nodes_in_group("ui_control"):
		if control is Control and control.visible and control.get_global_rect().has_point(mouse_pos):
			return true
	return false

func _update_hex_info(cell: HexCell) -> void:
	if not cell:
		hide()
		return
	
	# Update the UI elements with cell information
	title_label.text = "Hex Information"
	
	# Coordinates
	coordinates_label.text = "Coordinates: (%d, %d, %d)" % [cell.q, cell.r, cell.level]
	
	# Elevation
	elevation_label.text = "Elevation: %d" % cell.elevation
	
	# Terrain type
	if cell.terrain_data:
		terrain_label.text = "Terrain: %s" % cell.terrain_data.name
	else:
		terrain_label.text = "Terrain: Unknown"
	
	# Movement costs for different unit types
	var movement_text = "Movement Costs:\n"
	if cell.terrain_data:
		var mobility_names = {
			Unit.MobilityType.BIPEDAL: "Bipedal",
			Unit.MobilityType.WHEELED: "Wheeled", 
			Unit.MobilityType.HOVER: "Hover",
			Unit.MobilityType.TRACKED: "Tracked",
			Unit.MobilityType.AERIAL: "Aerial"
		}
		
		for mobility_type in Unit.MobilityType.keys():
			var type_enum = Unit.MobilityType[mobility_type]
			var cost = cell.terrain_data.get_movement_cost(type_enum)
			if cost < 999:  # Not impassable
				movement_text += "  %s: %d MP\n" % [mobility_names[type_enum], cost]
			else:
				movement_text += "  %s: Impassable\n" % mobility_names[type_enum]
	else:
		movement_text += "  Data unavailable"
	
	movement_costs_label.text = movement_text
	
	# Cover type
	var cover_names = {
		HexCell.CoverType.NONE: "None",
		HexCell.CoverType.LIGHT: "Light (25%)",
		HexCell.CoverType.HEAVY: "Heavy (50%)"
	}
	cover_label.text = "Cover: %s" % cover_names[cell.cover]
	
	# Occupancy
	if cell.unit:
		occupancy_label.text = "Occupied by: %s" % cell.unit.unit_name
	else:
		occupancy_label.text = "Occupied: None"
	
	# Structure type
	var structure_names = {
		HexCell.StructureType.GROUND: "Ground",
		HexCell.StructureType.BRIDGE: "Bridge",
		HexCell.StructureType.FLOOR: "Floor",
		HexCell.StructureType.TUNNEL: "Tunnel",
		HexCell.StructureType.STAIRS_UP: "Stairs Up",
		HexCell.StructureType.STAIRS_DOWN: "Stairs Down",
		HexCell.StructureType.ELEVATOR: "Elevator",
		HexCell.StructureType.ROOFTOP: "Rooftop"
	}
	structure_label.text = "Structure: %s" % structure_names[cell.structure_type]

# Public method to manually set and show info for a specific hex
func set_hex_info(cell: HexCell) -> void:
	current_hex_cell = cell
	hover_timer = hover_delay  # Skip the delay when manually setting
	_update_hex_info(cell)
	show()

# Public method to clear and hide the panel
func clear_hex_info() -> void:
	current_hex_cell = null
	hide()
