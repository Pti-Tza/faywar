# MovementSystem.gd
extends Node
class_name MovementSystem

### 
# MovementSystem handles all unit movement mechanics
# - Pathfinding using HexGridManager
# - Movement point management
# - Terrain/obstacle validation
# - Elevation change restrictions
# - Signal-based state updates
###

#--- Signals ---
signal movement_started(unit: UnitHandler, path: Array[HexCell])
signal movement_ended(unit: UnitHandler, success: bool)
signal movement_blocked(unit: UnitHandler, reason: String)

#--- Exported Properties ---
@export_category("Dependencies")
var hex_grid: HexGridManager
var unit_loader: UnitManager

@export_category("Gameplay Rules")
var max_elevation_change: int = 2
var min_clearance_distance: float = 1.5 # Minimum distance to obstacles

#--- Internal State ---
var _movement_paths: Dictionary = {} # {unit_uuid: [HexCell]}

#--- Core Methods ---

### 
# Initialize dependencies and connect signals
func _ready():
    if not hex_grid:
        push_error("MovementSystem requires HexGridManager reference")
    if not unit_loader:
        push_error("MovementSystem requires UnitManager reference")
###

### 
# Validate movement to target hex
# @param unit: Unit attempting to move
# @param target_hex: Target HexCell or axial coordinates
# @return: Dictionary { valid: bool, reason: String, cost: float }
func validate_move(unit: UnitHandler, target_hex: HexCell) -> Dictionary:
    var origin_cell = hex_grid.get_cell(unit.current_hex.x, unit.current_hex.y)
    var target_cell = target_hex
    
    var elevation_diff = target_cell.elevation - origin_cell.elevation
    if abs(elevation_diff) > max_elevation_change:
        return { "valid": false, "reason": "Exceeds elevation change limit", "cost": 0.0 }
    
    # Get pathfinding data
    var path = hex_grid.find_unit_path(unit, origin_cell.position, target_cell.position)
    if path.size() == 0:
        return { "valid": false, "reason": "No valid path", "cost": 0.0 }
    
    # Calculate total movement cost
    var total_cost = 0.0
    for i in range(1, path.size()):
        var prev_hex = hex_grid.get_cell(path[i - 1].x, path[i - 1].y)
        var curr_hex = hex_grid.get_cell(path[i].x, path[i].y)
        total_cost += curr_hex.get_movement_cost(unit.unit_data.mobility_type)
        total_cost += _calculate_elevation_cost(prev_hex, curr_hex)
        
        if curr_hex.terrain_data.is_impassable:
            return { "valid": false, "reason": "Path contains impassable terrain", "cost": 0.0 }
    
    # Check remaining movement points
    if unit.remaining_mp < total_cost:
        return { "valid": false, "reason": "Insufficient movement points", "cost": 0.0 }
    
    return { "valid": true, "reason": "", "cost": total_cost }
###

### 
# Execute validated movement
# @param unit: Unit to move
# @param target_hex: Target coordinates
# @return: bool - Movement success status
func execute_move(unit: UnitHandler, target_hex: HexCell) -> bool:
    var validation = validate_move(unit, target_hex)
    if not validation.valid:
        movement_blocked.emit(unit, validation.reason)
        return false
    
    # Update unit state
    unit.remaining_mp -= validation.cost
    _movement_paths[unit.uuid] = hex_grid.find_unit_path(unit, unit.current_hex, target_hex.axial_coord)
    
    # Begin movement animation/processing
    movement_started.emit(unit, _movement_paths[unit.uuid])
    return true
###
### 
# Process end of movement phase
# Called at turn end to finalize positions
func finalize_movement(unit: UnitHandler) -> void:
    if not _movement_paths.has(unit.uuid):
        return
        
    var path = _movement_paths[unit.uuid]
    if path.size() > 0:
        var target_cell = path[path.size() - 1]
        hex_grid.move_unit(unit, target_cell.q, target_cell.r)
        unit.current_hex = Vector2i(target_cell.q, target_cell.r)
    
    _movement_paths.erase(unit.uuid)
    movement_ended.emit(unit, true)
###

### 
# Get available movement hexes for unit
# @param unit: Unit to check
# @return: Array[HexCell] - Valid destination hexes
func get_available_hexes(unit: UnitHandler) -> Array[HexCell]:
    var origin = unit.current_hex
    var _max_range = unit.stats.movement_range
    
    var visited: Dictionary = {}  # Use Dictionary to mimic Set behavior
    var queue = [origin]
    var available_hexes: Array[HexCell] = []
    
    while queue.size() > 0:
        var current = queue.pop_front()
        visited.get_or_add(current)
        
        for neighbor in hex_grid.get_neighbors(current.x, current.y):
            var cost = neighbor.get_movement_cost(unit.unit_data.mobility_type)
            if cost <= unit.remaining_mp and not visited.has(neighbor.axial_coord):
                queue.append(neighbor.axial_coord)
                available_hexes.append(neighbor)
    
    return available_hexes
###
### 
# Calculate elevation change cost between hexes
# @private
func _calculate_elevation_cost(from_cell: HexCell, to_cell: HexCell) -> float:
    var elevation_diff = to_cell.elevation - from_cell.elevation
    return abs(elevation_diff) * to_cell.terrain_data.elevation_cost_multiplier
###

#--- Helper Methods ---

### 
# Get unit's current hex coordinates
func get_unit_hex(unit: UnitHandler) -> Vector3i:
    return hex_grid.get_unit_cell(unit).axial_coord
###

### 
# Reset movement state after turn
func reset_movement(unit: UnitHandler) -> void:
    unit.remaining_mp = unit.unit_data.base_movement
    _movement_paths.erase(unit.uuid)
###