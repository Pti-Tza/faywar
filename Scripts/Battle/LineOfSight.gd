# LineOfSight.gd
extends Node
class_name LineOfSight

### 
# LineOfSight handles line-of-sight calculations between units on a hex grid.
# It checks for obstacles, elevation changes, and other terrain-based restrictions.
###

#-------------------------------------------------------------
# Public API
#-------------------------------------------------------------

## Checks if there is a clear line of sight between two units
## @param attacker: Attacking unit (Node3D)
## @param target: Target unit (Node3D)
## @return: bool - True if line of sight is clear, False otherwise
static func has_clear_path(attacker: Node3D, target: Node3D) -> bool:
	var hex_grid = attacker.hex_grid_manager
	if not hex_grid:
		push_error("Attacker missing HexGridManager reference")
		return false
	
	var start_hex = hex_grid.get_unit_cell(attacker)
	var end_hex = hex_grid.get_unit_cell(target)
	
	if not start_hex or not end_hex:
		push_error("Invalid start or end hex coordinates")
		return false
	
	var path = hex_grid.get_path(start_hex.axial_coord, end_hex.axial_coord)
	if path.size() == 0:
		push_error("No path found between units")
		return false
	
	for cell in path:
		if cell.terrain_data.is_impassable:
			return false
		if cell.unit and cell.unit != attacker and cell.unit != target:
			return false
	
	return true

#-------------------------------------------------------------
# Helper Methods
#-------------------------------------------------------------

## Determines the hex path between two coordinates
## @param hex_grid: HexGridManager instance
## @param start_hex: Starting hex coordinates (Vector2i)
## @param end_hex: Ending hex coordinates (Vector2i)
## @return: Array[HexCell] - Path of hex cells
static func _get_hex_path(hex_grid: HexGridManager, unit : Unit, start_hex: Vector3, end_hex: Vector3) -> Array[HexCell]:
	return hex_grid.find_unit_path(unit, start_hex, end_hex)

## Checks if a hex cell obstructs line of sight
## @param cell: HexCell to check
## @return: bool - True if obstructed, False otherwise
static func _is_obstructed(cell: HexCell) -> bool:
	return cell.terrain_data.is_impassable or (cell.unit and cell.unit.is_visible_in_game())

#-------------------------------------------------------------
# Example Usage
#-------------------------------------------------------------

## Example usage in a script:
## var clear_path = LineOfSight.has_clear_path(attacker, target)
## if clear_path:
##     print("Clear line of sight!")
## else:
##     print("Blocked line of sight!")
