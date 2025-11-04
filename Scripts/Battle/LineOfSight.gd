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
	
	var path = hex_grid.get_hex_path(start_hex.axial_coords, end_hex.axial_coords)
	if path.size() == 0:
		push_error("No path found between units")
		return false
	
	# Get unit heights for height-based obstruction calculation
	var attacker_height = 10.0 if not attacker.has_method("get") or not "unit_height" in attacker else attacker.unit_height
	var target_height = 10.0 if not target.has_method("get") or not "unit_height" in target else target.unit_height
	
	# Check each hex in the path (excluding start and end hexes which contain the units)
	for i in range(1, path.size() - 1):  # Skip first and last hexes
		var cell = path[i]
		
		# Check if the cell is obstructed based on all factors (terrain, units, height)
		if _is_obstructed(cell, attacker_height, target_height):
			return false
	
	return true

## Gets the cover modifier for a target unit based on terrain
## @param target: Target unit (Unit)
## @return: int - Cover modifier to be added to hit chance (positive = harder to hit)
static func get_cover_modifier(target: Unit) -> int:
	var hex_grid = target.hex_grid_manager
	if not hex_grid:
		push_error("Target missing HexGridManager reference")
		return 0
	
	var target_hex = hex_grid.get_unit_cell(target)
	if not target_hex:
		push_error("Could not find hex cell for target")
		return 0
	
	# Base cover modifier based on terrain cover type
	var cover_modifier = 0
	if target_hex.cover == HexCell.CoverType.LIGHT:
		cover_modifier = 1  # +1 to hit chance (harder to hit)
	elif target_hex.cover == HexCell.CoverType.HEAVY:
		cover_modifier = 2  # +2 to hit chance (harder to hit)
	else:
		cover_modifier = 0 # No cover
	
	# Additional modifiers could be added based on elevation, unit size, etc.
	# For example, higher elevation might provide additional cover
	var elevation = target_hex.elevation
	if elevation > 0:
		cover_modifier += 1 # Additional cover for elevated positions
	
	return cover_modifier

#-------------------------------------------------------------
# Helper Methods
#-------------------------------------------------------------

## Determines the hex path between two coordinates ignoring mobility and terrain constraints
## @param hex_grid: HexGridManager instance
## @param start_hex: Starting hex coordinates (Vector2i)
## @param end_hex: Ending hex coordinates (Vector2i)
## @return: Array[HexCell] - Path of hex cells
static func _get_hex_path(hex_grid: HexGridManager, unit : Unit, start_hex: Vector2i, end_hex: Vector2i) -> Array[HexCell]:
	return hex_grid.get_hex_path(start_hex, end_hex)

## Checks if a hex cell obstructs line of sight
## @param cell: HexCell to check
## @param attacker_height: Height of the attacking unit (optional, defaults to 10.0)
## @param target_height: Height of the target unit (optional, defaults to 10.0)
## @return: bool - True if obstructed, False otherwise
static func _is_obstructed(cell: HexCell, attacker_height: float = 10.0, target_height: float = 10.0) -> bool:
	# Check for units in the cell
	if cell.unit and cell.unit != null:
		return true
	# Check for height-based complete obstruction
	else:
		var hex_grid = HexGridManager.instance
		if hex_grid:
			var cell_height = cell.elevation * hex_grid.elevation_step  # Convert elevation level to actual height
			var min_complete_height = min(attacker_height, target_height) * 0.8  # 80% of lower unit
			return cell_height >= min_complete_height
		else:
			return false  # If we can't access the grid, assume no height obstruction


#-------------------------------------------------------------
# Example Usage
#-------------------------------------------------------------

## Example usage in a script:
## var clear_path = LineOfSight.has_clear_path(attacker, target)
## if clear_path:
##     print("Clear line of sight!")
## else:
##     print("Blocked line of sight!")

#-------------------------------------------------------------
# BattleTech-inspired Obstruction Methods
#-------------------------------------------------------------

## Enumeration for line of sight obstruction levels
enum ObstructionLevel {
	CLEAR,      # No obstruction
	PARTIAL,    # Partial obstruction (heavy woods, light buildings)
	COMPLETE    # Complete obstruction (dense terrain, heavy buildings)
}

## Checks the level of obstruction between two units based on BattleTech rules
## @param attacker: Attacking unit (Node3D)
## @param target: Target unit (Node3D)
## @return: ObstructionLevel - Level of obstruction between units
static func get_obstruction_level(attacker: Unit, target: Unit) -> ObstructionLevel:
	var hex_grid = attacker.hex_grid_manager
	if not hex_grid:
		push_error("Attacker missing HexGridManager reference")
		return ObstructionLevel.COMPLETE
	
	var start_hex = hex_grid.get_unit_cell(attacker)
	var end_hex = hex_grid.get_unit_cell(target)
	
	if not start_hex or not end_hex:
		push_error("Invalid start or end hex coordinates")
		return ObstructionLevel.COMPLETE
	
	var path = hex_grid.get_hex_path(start_hex.axial_coords, end_hex.axial_coords)
	if path.size() == 0:
		push_error("No path found between units")
		return ObstructionLevel.COMPLETE
	
	var partial_obstruction_count = 0
	var complete_obstruction_count = 0
	
	# Get unit heights for height-based obstruction calculation
	var attacker_height = attacker.unit_height
	var target_height = target.unit_height
	
	# Check each hex in the path (excluding start and end hexes which contain the units)
	for i in range(1, path.size() - 1):  # Skip first and last hexes
		var cell = path[i]
		
		# Check for height-based obstruction
		var cell_height = cell.elevation * hex_grid.elevation_step  # Convert elevation level to actual height
		var min_partial_height = min(attacker_height, target_height) * 0.5  # 50% of lower unit
		var min_complete_height = min(attacker_height, target_height) * 0.8  # 80% of lower unit
		
		if cell_height >= min_complete_height:
			complete_obstruction_count += 1
		elif cell_height >= min_partial_height:
			partial_obstruction_count += 1
		# Check for cover-based obstruction
		elif cell.cover == HexCell.CoverType.HEAVY or cell.cover == HexCell.CoverType.LIGHT:
			partial_obstruction_count += 1
		# Check for units in the path (other than attacker/target)
		elif cell.unit and cell.unit != attacker and cell.unit != target:
			# Determine if the unit provides complete or partial obstruction
			if cell.unit.has_method("provides_complete_cover") and cell.unit.provides_complete_cover():
				complete_obstruction_count += 1
			else:
				partial_obstruction_count += 1
	
	# Determine overall obstruction level based on BattleTech rules
	if complete_obstruction_count > 0:
		return ObstructionLevel.COMPLETE
	elif partial_obstruction_count > 0:
		return ObstructionLevel.PARTIAL
	else:
		return ObstructionLevel.CLEAR

