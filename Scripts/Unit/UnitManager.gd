# UnitManager.gd
# Handles unit lifecycle, tracking, and battlefield presence
# Implements BattleTech-specific rules for unit destruction and status effects

extends Node
class_name UnitManager

static var instance : UnitManager
### Signals ###
signal unit_spawned(unit: Node, position: Vector3)  # Unit created and placed
signal unit_destroyed(unit: Node, wreckage: Node)    # Unit destroyed + wreck ref
signal unit_damaged(unit: Node, section: String, damage: int)  # Location-based damage

### Properties ###
var active_units: Array = []              # All operational units
var destroyed_units: Array = []           # Wreckage and disabled units


# Preloaded resources
@export var default_wreckage_scene: PackedScene  # Fallback wreckage

### Dependencies ###
#@onready var hex_grid : HexGridManager    # Spatial tracking


enum MobilityType {
	BIPEDAL,    # Humanoid mechs/units
	WHEELED,    # Wheeled vehicles
	HOVER,      # Hovercraft/floating units
	TRACKED,    # Tank-like units
	AERIAL      # Flying units (limited)
}

func _init():
	instance = self
# --------------------------
#region Public API
# --------------------------

## Spawns a unit using BattleTech unit profile data
## @param profile: UnitData - Contains stats/configuration
## @param spawn_hex: Vector3i - Initial grid position
## @param team: int - Controlling faction/player
func spawn_unit(unit_scene: PackedScene, spawn_hex: Vector3i, team: int = -1, id: String = "") -> Node:
	
	
	
	# Instantiate and configure unit
	var unit : Unit = unit_scene.instantiate()
	unit.name = "%s_%s" % [unit.name, id]
	unit.initialize(team, id)
	
	# Register unit
	active_units.append(unit)
	
	
	
	# Heat not implemented
	#unit.heat_critical.connect(_on_heat_critical.bind(unit))
	unit.unit_destroyed.connect(_on_unit_destroyed.bind(unit))
	
	# Set initial battlefield position
	HexGridManager.instance.place_unit(unit, spawn_hex.x, spawn_hex.y)
	
	emit_signal("unit_spawned", unit, spawn_hex)
	return unit

func _generate_unit_id(profile: Unit) -> String:
	# Generate a unique unit ID based on profile and timestamp
	return "%s_%d" % [profile.unit_name, Time.get_time_dict_from_system()]

## Gets all units belonging to a specific team
## @param team: int - Team ID to filter by
## @param include_destroyed: bool - Whether to include wreckage
func get_units_by_team(team: int, include_destroyed: bool = false) -> Array:
	var source = active_units + (destroyed_units if include_destroyed else [])
	return source.filter(func(u): return u.team == team)


## Finds units in a specific hex location
## @param hex: Vector3i - Grid coordinates to check
## @param include_wreckage: bool - Whether to count destroyed units
func get_units_in_hex(hex: Vector3i, include_wreckage: bool = false) -> Array:
	var source = active_units + (destroyed_units if include_wreckage else [])
	return source.filter(func(u): return HexGridManager.instance.world_to_hex(u.position) == hex)

#endregion

# --------------------------
#region Signal Handlers
# --------------------------



## Handles unit destruction events
## @param unit: Node - Destroyed unit
func _on_unit_destroyed(unit: Unit) -> void:
	# Create wreckage using profile-specific scene or fallback
	var wreckage_scene = unit.profile.wreckage_scene if unit.profile.wreckage_scene else default_wreckage_scene
	var wreckage = wreckage_scene.instantiate()
	
	# Position wreckage and update grid
	wreckage.position = unit.position
	HexGridManager.instance.update_terrain(unit.grid_position, "Wreckage")
	
	# Update registries
	active_units.erase(unit)
	destroyed_units.append(wreckage)
	
	
	emit_signal("unit_destroyed", unit, wreckage)
	unit.queue_free()

#endregion

# --------------------------
#region Core Logic
# --------------------------



## Cleans up invalid unit references at turn end
func _cleanup_units() -> void:
	# Remove null references
	active_units = active_units.filter(func(u): return is_instance_valid(u))
	
	# Remove wreckage after 3 turns
	for i in range(destroyed_units.size()-1, -1, -1):
		if destroyed_units[i].expiration_turns <= 0:
			destroyed_units.remove_at(i)

#endregion
