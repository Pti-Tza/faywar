# movement_system.gd
extends Node
class_name MovementSystem


## Emitted when movement starts
signal movement_started(unit: Node3D, path: Array[Vector3])
## Emitted during movement progress
signal movement_updated(unit: Node3D, current_position: Vector3)
## Emitted when movement completes
signal movement_finished(unit: Node3D)
## Emitted when movement is interrupted
signal movement_interrupted(unit: Node3D)

# Configuration
@export var movement_speed: float = 5.0          # Units per second
@export var rotation_speed: float = 2.0          # Radians per second
@export var height_offset: float = 0.5           # Units hover above ground

# State
var current_path: Array[Vector3] = []
var is_moving: bool = false
var current_unit: Node3D = null

# Dependencies
@onready var hex_grid = HexGridManager
@onready var heat_system: HeatSystem
@onready var pilot_system: PilotSystem

func _process(delta: float) -> void:
	if is_moving and current_path.size() > 0:
		_move_along_path(delta)

# Public API ----------------------------------------------------------------

## Start movement for a unit along a validated path
func start_movement(unit: Node3D, path: Array[Vector3]) -> void:
	if is_moving:
		return
	
	current_unit = unit
	current_path = path
	is_moving = true
	movement_started.emit(unit, path)
	
	# Initialize movement components
	heat_system = unit.get_node_or_null("HeatSystem")
	pilot_system = unit.get_node_or_null("PilotSystem")

## Calculate valid movement range
func get_movement_range(unit: Node3D) -> Array[HexCell]:
	var movement_points = unit.unit_data.movement_points
	var start_cell = hex_grid.get_unit_cell(unit)
	return hex_grid.get_cells_in_range(start_cell, movement_points)

## Cancel current movement
func cancel_movement() -> void:
	if is_moving:
		is_moving = false
		movement_interrupted.emit(current_unit)
		_cleanup_movement()

# Core Movement Logic -------------------------------------------------------

func _move_along_path(delta: float) -> void:
	var target_pos = current_path[0]
	var current_pos = current_unit.global_transform.origin
	
	# Horizontal movement
	var horizontal_pos = Vector3(target_pos.x, current_pos.y, target_pos.z)
	var new_pos = current_pos.move_toward(horizontal_pos, movement_speed * delta)
	
	# Vertical movement (smooth height transitions)
	var target_height = hex_grid.get_cell_height(current_path[0]) + height_offset
	new_pos.y = lerp(current_pos.y, target_height, delta * movement_speed)
	
	# Rotation handling
	var direction = (horizontal_pos - current_pos).normalized()
	if direction.length() > 0.1:
		var target_rot = atan2(direction.x, direction.z)
		current_unit.rotation.y = lerp_angle(
			current_unit.rotation.y, 
			target_rot, 
			rotation_speed * delta
		)
	
	current_unit.global_transform.origin = new_pos
	movement_updated.emit(current_unit, new_pos)
	
	# Check if reached waypoint
	if new_pos.distance_to(horizontal_pos) < 0.1:
		current_path.remove_at(0)
		_handle_cell_transition()
		
		if current_path.is_empty():
			_finish_movement()

func _handle_cell_transition() -> void:
	# Update grid tracking
	var old_cell = hex_grid.get_unit_cell(current_unit)
	var new_cell = hex_grid.world_to_axial(current_unit.global_transform.origin)
	
	hex_grid.move_unit(current_unit, new_cell.q, new_cell.r)
	
	# Apply terrain effects
	var terrain_data = hex_grid.get_cell_terrain_data(new_cell)
	_apply_movement_cost(terrain_data)
	_apply_terrain_effects(terrain_data)

func _apply_movement_cost(terrain_data: TerrainData.TerrainType) -> void:
	var movement_cost = terrain_data.get_movement_cost()
	
	# Reduce remaining movement points
	current_unit.current_movement_points -= movement_cost
	
	# Generate heat based on movement type
	if current_unit.is_jumping:
		heat_system.add_heat(movement_cost * 2.0)
	elif current_unit.is_running:
		heat_system.add_heat(movement_cost * 1.5)

func _apply_terrain_effects(terrain_data: TerrainData.TerrainType) -> void:
	# Example: Forest provides cover
	if terrain_data.id == "forest":
		current_unit.add_status("partial_cover")
	
	# Example: Water slows movement
	if terrain_data.id == "water":
		movement_speed *= 0.7

func _finish_movement() -> void:
	is_moving = false
	movement_finished.emit(current_unit)
	_cleanup_movement()
	
	# Final piloting check for stability
	var check = pilot_system.roll_skill_check("piloting")
	if not check.success:
		_handle_fall(check.margin)

func _handle_fall(stability_margin: int) -> void:
	current_unit.emit_signal("unit_fell", stability_margin)
	# Apply fall damage to unit and pilot
	current_unit.take_damage(stability_margin)
	pilot_system.take_damage(1)

func _cleanup_movement() -> void:
	current_path = []
	current_unit = null
	heat_system = null
	pilot_system = nullextends Node
