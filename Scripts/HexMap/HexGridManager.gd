# hex_grid_manager.gd
extends Node3D
class_name HexGridManager
## Central manager for hexagonal grid operations with Battletech movement rules
##
## Features:
## - Directional pathfinding costs
## - Elevation-aware movement
## - Unit-specific mobility constraints
## - Asymmetric terrain costs

#region Configuration
@export_category("Grid Configuration")
## Number of concentric rings around center (0 = single hex)
@export var grid_radius: int = 10
## Size of individual hexes (X: width, Y: height)
@export var hex_size: Vector2 = Vector2(2, 2)
## Vertical height per elevation level
@export var elevation_step: float = 1.0

@export_category("Pathfinding")
## Terrain data resource for movement rules
@export var terrain_data: TerrainData
## Reference to custom A* implementation
var astar: DirectionalAStar
#endregion

#region Internal State
## Dictionary of hex cells (key: Vector2i(q,r))
var hex_grid: Dictionary = {}
## Cache for unit positions (unit: Node3D → HexCell)
var _unit_positions: Dictionary = {}
#endregion

#region Signals
signal grid_initialized
signal cell_updated(q: int, r: int)
signal unit_moved(unit: Node3D, from: Vector3i, to: Vector3i)
#endregion

#region Constants
const HEX_DIRECTIONS = [
    Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
    Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]
#endregion

#region Core Grid Management
func _ready() -> void:
    generate_hex_grid()
    initialize_astar()

## Generates hexagonal grid with axial coordinates
func generate_hex_grid() -> void:
    hex_grid.clear()
    
    # Generate concentric rings of hex cells
    for q in range(-grid_radius, grid_radius + 1):
        # Calculate valid r range for current q to maintain hexagonal shape
        var r1 = max(-grid_radius, -q - grid_radius)
        var r2 = min(grid_radius, -q + grid_radius)
        
        for r in range(r1, r2 + 1):
            var cell = HexCell.new(q, r)  
            cell.grid_manager = self
            cell.position = axial_to_world(q, r)
            hex_grid[Vector2i(q, r)] = cell
            add_child(cell)
    
    grid_initialized.emit()
## Initializes directional pathfinding graph
func initialize_astar() -> void:
    astar = DirectionalAStar.new()
    
    # Add all cells to A*
    for cell in hex_grid.values():
        var point_id = _get_astar_id(cell.q, cell.r)
        astar.add_point(point_id, cell.position)
    
    # Create directional connections
    for cell in hex_grid.values():
        _connect_cell_neighbors(cell)

## Creates directional connections for a cell
func _connect_cell_neighbors(cell: HexCell) -> void:
    var from_id = _get_astar_id(cell.q, cell.r)
    
    for neighbor in get_neighbors(cell.q, cell.r):
        var to_id = _get_astar_id(neighbor.q, neighbor.r)
        var forward_cost = calculate_directional_cost(cell, neighbor)
        var reverse_cost = calculate_directional_cost(neighbor, cell)
        
        astar.add_directional_connection(from_id, to_id, forward_cost)
        astar.add_directional_connection(to_id, from_id, reverse_cost)
#endregion

#region Pathfinding
## Calculates movement cost between two cells (directional)
func calculate_directional_cost(source: HexCell, target: HexCell) -> float:
    var base_cost = terrain_data.get_movement_cost(target.terrain_type)
    var elevation_diff = target.elevation - source.elevation
    
    # Elevation modifiers
    if elevation_diff > 0:
        base_cost += elevation_diff * terrain_data.elevation_cost_multiplier
    else:
        base_cost += abs(elevation_diff) * terrain_data.downhill_cost_multiplier
    
    # Unit mobility modifiers (example implementation)
    if source.unit and source.unit.has_method("get_mobility_factor"):
        base_cost *= source.unit.get_mobility_factor(target.terrain_type)
    
    return max(base_cost, 0.1)


## Converts world position to A* point ID
func _get_astar_id_from_world(world_pos: Vector3) -> int:
    var axial_coords = world_to_axial(world_pos)
    return _get_astar_id(axial_coords.x, axial_coords.y)

## Finds path with unit-specific movement rules
func find_unit_path(unit: Node3D, start: Vector3, end: Vector3) -> Array[Vector3]:
    var start_id = _get_astar_id_from_world(start)
    var end_id = _get_astar_id_from_world(end)
    
    if !astar.has_point(start_id) || !astar.has_point(end_id):
        return []
    
    # Apply unit-specific mobility rules
    _apply_unit_mobility(unit)
    var path = astar.get_point_path(start_id, end_id)
    _reset_mobility()
    
    return path
    
#endregion

#region Unit Management

## Gets current cell for specified unit
func get_unit_cell(unit: Node3D) -> HexCell:
    for cell in hex_grid.values():
        if cell.unit == unit:
            return cell
    return null

## Moves unit to new grid coordinates if valid
func move_unit(unit: Node3D, target_q: int, target_r: int) -> bool:
    var current_cell = get_unit_cell(unit)
    if !current_cell:
        return false
    
    var target_cell = get_cell(target_q, target_r)
    if target_cell && target_cell.unit == null:
        current_cell.unit = null
        target_cell.unit = unit
        unit.global_position = target_cell.position
        emit_signal("unit_moved", unit, 
            Vector3i(current_cell.q, current_cell.r, current_cell.elevation), 
            Vector3i(target_cell.q, target_cell.r, target_cell.elevation))
        return true
    return false

## Places unit and updates pathfinding graph
func place_unit(unit: Node3D, q: int, r: int) -> bool:
    var cell = get_cell(q, r)
    if cell and cell.unit == null:
        cell.unit = unit
        _unit_positions[unit] = cell
        _update_mobility_connections(cell)
        return true
    return false

## Updates connections for cells affected by unit placement
func _update_mobility_connections(cell: HexCell) -> void:
    # Update connections to/from this cell
    _connect_cell_neighbors(cell)
    for neighbor in get_neighbors(cell.q, cell.r):
        _connect_cell_neighbors(neighbor)
#endregion

#region Helper Methods
func _get_r_range(q: int) -> Vector2i:
    return Vector2i(
        max(-grid_radius, -q - grid_radius),
        min(grid_radius, -q + grid_radius)
    )

func _create_hex_cell(q: int, r: int) -> void:
    var cell = HexCell.new(q, r)
    cell.grid_manager = self
    cell.position = axial_to_world(q, r)
    hex_grid[Vector2i(q, r)] = cell
    add_child(cell)

func _get_astar_id(q: int, r: int) -> int:
    return (q << 16) | (r & 0xFFFF)

func _apply_unit_mobility(_unit: Node3D) -> void:
    # Implementation for unit-specific mobility overrides
    pass

func _reset_mobility() -> void:
    # Reset any temporary mobility changes
    pass
#endregion

#region Coordinate Conversions
## Converts axial coordinates (q, r) to world space position
func axial_to_world(q: int, r: int) -> Vector3:
    var x = hex_size.x * (sqrt(3) * q + sqrt(3)/2 * r)
    var z = hex_size.y * (3.0/2 * r)
    return Vector3(x, 0, z)

## Converts world space position to axial coordinates (q, r)
func world_to_axial(world_pos: Vector3) -> Vector2i:
    var q = (sqrt(3)/3 * world_pos.x - 1.0/3 * world_pos.z) / hex_size.x
    var r = (2.0/3 * world_pos.z) / hex_size.y
    return cube_to_axial(round_axial(q, r))

## Converts cube coordinates to axial by dropping s component
func cube_to_axial(cube: Vector3) -> Vector2i:
    return Vector2i(cube.x, cube.z)

## Rounds fractional axial coordinates to nearest valid cube coordinates
func round_axial(q: float, r: float) -> Vector3:
    var cube = Vector3(q, -q - r, r)
    var rx = roundi(cube.x)
    var ry = roundi(cube.y)
    var rz = roundi(cube.z)
    
    # Maintain cube coordinate invariant (x + y + z = 0)
    var dx = abs(rx - cube.x)
    var dy = abs(ry - cube.y)
    var dz = abs(rz - cube.z)
    
    if dx > dy and dx > dz:
        rx = -ry - rz
    elif dy > dz:
        ry = -rx - rz
    else:
        rz = -rx - ry
        
    return Vector3(rx, ry, rz)
#endregion
#region Grid Query
## Retrieves cell at specified axial coordinates
func get_cell(q: int, r: int) -> HexCell:
    return hex_grid.get(Vector2i(q, r), null)

## Gets all valid neighboring cells for given coordinates
func get_neighbors(q: int, r: int) -> Array[HexCell]:
    var neighbors = []
    for dir in HEX_DIRECTIONS:
        var neighbor_coord = Vector2i(q + dir.x, r + dir.y)
        if hex_grid.has(neighbor_coord):
            neighbors.append(hex_grid[neighbor_coord])
    return neighbors

## Gets all cells within specified hexagonal distance
func get_cells_in_range(center: Vector2i, rang: int) -> Array[HexCell]:
    var results = []
    for q in range(-rang, rang + 1):
        var r_start = max(-rang, -q - rang)
        var r_end = min(rang, -q + rang)
        
        for r in range(r_start, r_end + 1):
            var s = -q - r
            var distance = (abs(q) + abs(r) + abs(s)) / 2
            if distance <= range:
                var coord = Vector2i(center.x + q, center.y + r)
                if hex_grid.has(coord):
                    results.append(hex_grid[coord])
    return results
#endregion


#region Debug
## Debug visualization of grid structure (requires DebugDraw3D addon)
func draw_debug_grid() -> void:
    for cell in hex_grid.values():
        var center = cell.position
        for i in 6:
            var angle_deg = 60 * i
            var angle_rad = deg_to_rad(angle_deg)
            var point = center + Vector3(
                hex_size.x * cos(angle_rad),
                0,
                hex_size.y * sin(angle_rad)
            )
            var next_point = center + Vector3(
                hex_size.x * cos(angle_rad + deg_to_rad(60)),
                0,
                hex_size.y * sin(angle_rad + deg_to_rad(60))
            )
            DebugDraw3D.draw_line(point, next_point, Color.WHITE, 0.1)
#endregion