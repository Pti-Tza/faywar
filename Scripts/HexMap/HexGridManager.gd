# HexGridManager.gd
extends Node3D
class_name HexGridManager


# Hex grid configuration
@export var grid_radius: int = 10               # Number of rings around center
@export var hex_size: Vector2 = Vector2(2, 2)   # X = width, Y = height
@export var elevation_step: float = 1.0         # Height per elevation level

# Terrain data
@export var terrain_data: TerrainData           # Resource with terrain properties

# Grid storage
var hex_grid: Dictionary = {}                   # Axial coords (q,r) : HexCell
var astar: AStar3D                               # Pathfinding system

# Signals
signal grid_initialized
signal cell_updated(q: int, r: int)
signal unit_moved(unit: Node3D, from: Vector3i, to: Vector3i)

# Hex directions in axial coordinates (q, r)
const HEX_DIRECTIONS = [
    Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
    Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]

func _ready() -> void:
    generate_hex_grid()
    initialize_astar()

# Core Grid Generation ------------------------------------------------------
func generate_hex_grid() -> void:
    for q in range(-grid_radius, grid_radius + 1):
        var r1 = max(-grid_radius, -q - grid_radius)
        var r2 = min(grid_radius, -q + grid_radius)
        
        for r in range(r1, r2 + 1):
            var cell = HexCell.new(q, r)
            cell.grid_manager = self
            cell.position = axial_to_world(q, r)
            hex_grid[Vector2i(q, r)] = cell
            add_child(cell)
    
    emit_signal("grid_initialized")

func initialize_astar() -> void:
    astar = AStar3D.new()
    
    # First add all points
    for cell in hex_grid.values():
        var point_id = _get_astar_id(cell.q, cell.r)
        astar.add_point(point_id, cell.position)
    
    # Then connect neighbors with proper weights
    for cell in hex_grid.values():
        var from_id = _get_astar_id(cell.q, cell.r)
        for neighbor in get_neighbors(cell.q, cell.r):
            var to_id = _get_astar_id(neighbor.q, neighbor.r)
            if astar.has_point(to_id):
                var cost = _calculate_movement_cost(cell, neighbor)
                
                # Connect points (bidirectional) then set weight
                astar.connect_points(from_id, to_id, true)
                astar.set_point_weight_scale(from_id, cost)

                # Set reverse weight since connection is bidirectional

                astar.set_point_weight_scale(to_id, cost)

# Coordinate Conversions ----------------------------------------------------
func axial_to_world(q: int, r: int) -> Vector3:
    var x = hex_size.x * (sqrt(3) * q + sqrt(3)/2 * r)
    var z = hex_size.y * (3.0/2 * r)
    return Vector3(x, 0, z)

func world_to_axial(world_pos: Vector3) -> Vector2i:
    var q = (sqrt(3)/3 * world_pos.x - 1.0/3 * world_pos.z) / hex_size.x
    var r = (2.0/3 * world_pos.z) / hex_size.y
    return cube_to_axial(round_axial(q, r))

func cube_to_axial(cube: Vector3) -> Vector2i:
    return Vector2i(cube.x, cube.z)

func round_axial(q: float, r: float) -> Vector3:
    var x = q
    var z = r
    var y = -x - z
    var rx = round(x)
    var ry = round(y)
    var rz = round(z)
    
    var dx = abs(rx - x)
    var dy = abs(ry - y)
    var dz = abs(rz - z)
    
    if dx > dy and dx > dz:
        rx = -ry - rz
    elif dy > dz:
        ry = -rx - rz
    else:
        rz = -rx - ry
    
    return Vector3(rx, ry, rz)

# Pathfinding ---------------------------------------------------------------
func find_path(start: Vector3, end: Vector3) -> Array[Vector3]:
    var start_coord = world_to_axial(start)
    var end_coord = world_to_axial(end)
    
    if not hex_grid.has(start_coord) or not hex_grid.has(end_coord):
        return []
    
    var start_id = _get_astar_id(start_coord.x, start_coord.y)
    var end_id = _get_astar_id(end_coord.x, end_coord.y)
    
    return astar.get_point_path(start_id, end_id)

func _calculate_movement_cost(from: HexCell, to: HexCell) -> float:
    var base_cost = terrain_data.get_movement_cost(to.terrain_type)
    var elevation_diff = abs(to.elevation - from.elevation)
    return base_cost + elevation_diff * terrain_data.elevation_cost_multiplier

# Grid Query ----------------------------------------------------------------
func get_cell(q: int, r: int) -> HexCell:
    return hex_grid.get(Vector2i(q, r), null)

func get_neighbors(q: int, r: int) -> Array[HexCell]:
    var neighbors = []
    for dir in HEX_DIRECTIONS:
        var neighbor_coord = Vector2i(q + dir.x, r + dir.y)
        if hex_grid.has(neighbor_coord):
            neighbors.append(hex_grid[neighbor_coord])
    return neighbors

func get_cells_in_range(center: Vector2i, range: int) -> Array[HexCell]:
    var results = []
    for q in range(-range, range + 1):
        # Calculate valid r range for current q
        var r_start = max(-range, -q - range)
        var r_end = min(range, -q + range)
        
        for r in range(r_start, r_end + 1):
            # Calculate cube coordinate s
            var s = -q - r
            
            # Calculate proper hexagonal distance
            var distance = (abs(q) + abs(r) + abs(s)) / 2
            
            if distance <= range:
                # Offset by center coordinates
                var coord = Vector2i(center.x + q, center.y + r)
                if hex_grid.has(coord):
                    results.append(hex_grid[coord])
    
    return results

# Unit Management -----------------------------------------------------------
func place_unit(unit: Node3D, q: int, r: int) -> bool:
    var cell = get_cell(q, r)
    if cell and cell.unit == null:
        cell.unit = unit
        unit.global_position = cell.position
        return true
    return false

func get_unit_cell(unit: Node3D) -> HexCell:
    for cell in hex_grid.values():
        if cell.unit == unit:
            return cell
    return null

func move_unit(unit: Node3D, target_q: int, target_r: int) -> bool:
    var current_cell = get_unit_cell(unit)
    if !current_cell:
        return false
    
    var target_cell = get_cell(target_q, target_r)
    if target_cell && target_cell.unit == null:
        current_cell.unit = null
        target_cell.unit = unit
        unit.global_position = target_cell.position
        # Add elevation to Vector3i (third parameter)
        emit_signal("unit_moved", unit, 
            Vector3i(current_cell.q, current_cell.r, current_cell.elevation), 
            Vector3i(target_cell.q, target_cell.r, target_cell.elevation))
        return true
    return false

# Helper Methods ------------------------------------------------------------
func _get_astar_id(q: int, r: int) -> int:
    return q * 1000 + r  # Simple unique ID generation

func _update_cell_elevation(q: int, r: int, elevation: int) -> void:
    var cell = get_cell(q, r)
    if cell:
        cell.elevation = elevation
        cell.position.y = elevation * elevation_step
        emit_signal("cell_updated", q, r)

# Debug ---------------------------------------------------------------------
func draw_debug_grid() -> void:
    for cell in hex_grid.values():
        var center = cell.position
        # Draw hex outline
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
            #DebugDraw3D.draw_line(point, next_point, Color.WHITE, 0.1)