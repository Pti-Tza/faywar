# UnitManager.gd
# Handles unit lifecycle, tracking, and battlefield presence
# Implements BattleTech-specific rules for unit destruction and status effects

extends Node
class_name UnitManager

### Signals ###
signal unit_spawned(unit: Node, position: Vector3)  # Unit created and placed
signal unit_destroyed(unit: Node, wreckage: Node)    # Unit destroyed + wreck ref
signal unit_damaged(unit: Node, section: String, damage: int)  # Location-based damage
signal unit_overheated(unit: Node, shutdown: bool)   # Heat status change

### Properties ###
var active_units: Array = []              # All operational units
var destroyed_units: Array = []           # Wreckage and disabled units
var unit_registry: Dictionary = {}        # { uuid: { node, profile, team } }

# Preloaded resources
@export var default_wreckage_scene: PackedScene  # Fallback wreckage

### Dependencies ###
@onready var hex_grid = $HexGridManager    # Spatial tracking
@onready var turn_manager = $TurnManager   # Turn sequencing

enum MobilityType {
    BIPEDAL,    # Humanoid mechs/units
    WHEELED,    # Wheeled vehicles
    HOVER,      # Hovercraft/floating units
    TRACKED,    # Tank-like units
    AERIAL      # Flying units (limited)
}
# --------------------------
#region Public API
# --------------------------

## Spawns a unit using BattleTech unit profile data
## @param profile: UnitProfile - Contains stats/configuration
## @param spawn_hex: Vector3i - Initial grid position
## @param team: int - Controlling faction/player
func spawn_unit(profile: UnitProfile, spawn_hex: Vector3i, team: int = -1, id: String = _generate_unit_id(profile)) -> Node:
    # Validate critical profile data
    assert(profile != null, "UnitProfile cannot be null")
    assert(profile.unit_scene != null, "Missing unit scene in profile")
    
    # Instantiate and configure unit
    var unit = profile.unit_scene.instantiate()
    unit.name = "%s_%s" % [profile.unit_name, id]
    unit.initialize(profile, team, id)
    
    # Register unit
    active_units.append(unit)
    unit_registry[unit.uuid] = {
        "node": unit,
        "profile": profile,
        "team": team,
        "hex": spawn_hex
    }
    
    # Connect BattleTech-critical signals
    unit.component_damaged.connect(_on_component_damaged.bind(unit))
    unit.heat_critical.connect(_on_heat_critical.bind(unit))
    unit.destroyed.connect(_on_unit_destroyed.bind(unit))
    
    # Set initial battlefield position
    hex_grid.place_unit(unit, spawn_hex)
    
    emit_signal("unit_spawned", unit, spawn_hex)
    return unit

func _generate_unit_id(profile: UnitProfile) -> String:
    # Generate a unique unit ID based on profile and timestamp
    return "%s_%d" % [profile.profile_id, Time.get_time_dict_from_system()]

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
    return source.filter(func(u): return hex_grid.world_to_hex(u.position) == hex)

#endregion

# --------------------------
#region Signal Handlers
# --------------------------

## Handles component damage events from units
## @param section: String - Damaged section (e.g., "CTorso")
## @param damage: int - Amount of damage applied
## @param unit: Node - Source unit
func _on_component_damaged(section: String, damage: int, unit: Node) -> void:
    emit_signal("unit_damaged", unit, section, damage)
    
    # BattleTech: Check for section destruction
    if unit.component_system.is_section_destroyed(section):
        _handle_section_destruction(unit, section)


## Processes heat-related critical events
## @param shutdown: bool - Whether unit shut down
## @param unit: Node - Source unit
func _on_heat_critical(shutdown: bool, unit: Node) -> void:
    emit_signal("unit_overheated", unit, shutdown)
    
    if shutdown:
        # BattleTech: Shutdown units can't take actions
        turn_manager.remove_from_initiative(unit)


## Handles unit destruction events
## @param unit: Node - Destroyed unit
func _on_unit_destroyed(unit: Node) -> void:
    # Create wreckage using profile-specific scene or fallback
    var wreckage_scene = unit.profile.wreckage_scene if unit.profile.wreckage_scene else default_wreckage_scene
    var wreckage = wreckage_scene.instantiate()
    
    # Position wreckage and update grid
    wreckage.position = unit.position
    hex_grid.update_terrain(unit.grid_position, "Wreckage")
    
    # Update registries
    active_units.erase(unit)
    destroyed_units.append(wreckage)
    unit_registry.erase(unit.uuid)
    
    emit_signal("unit_destroyed", unit, wreckage)
    unit.queue_free()

#endregion

# --------------------------
#region Core Logic
# --------------------------

## Handles BattleTech-specific section destruction consequences
## @param unit: Node - Affected unit
## @param section: String - Destroyed section
func _handle_section_destruction(unit: Node, section: String) -> void:
    match section:
        "CTorso":
            # BattleTech: Center torso destruction = total loss
            unit.destroy()
        "Legs":
            # Reduce movement capability by 50%
            unit.movement_system.apply_movement_penalty(0.5)
            # 25% chance of pilot injury per destroyed leg
            if randf() <= 0.25:
                unit.pilot_system.apply_injury("Leg Trauma")
        "Arms":
            # Disarm mounted weapons
            unit.weapon_system.disable_arm_weapons(section)
        "Engine":
            # Immediate shutdown and heat buildup
            unit.heat_system.force_shutdown()


## Cleans up invalid unit references at turn end
func _cleanup_units() -> void:
    # Remove null references
    active_units = active_units.filter(func(u): return is_instance_valid(u))
    
    # Remove wreckage after 3 turns
    for i in range(destroyed_units.size()-1, -1, -1):
        if destroyed_units[i].expiration_turns <= 0:
            destroyed_units.remove_at(i)

#endregion

# --------------------------
#region Helper Methods
# --------------------------

## Validates unit positions after movement phase
func validate_unit_positions() -> void:
    for unit in active_units:
        var reported_hex = hex_grid.world_to_hex(unit.position)
        if unit_registry[unit.uuid].hex != reported_hex:
            push_warning("Unit %s position mismatch: %s vs %s" % [
                unit.name, 
                unit_registry[unit.uuid].hex,
                reported_hex
            ])
            # Auto-correct registry
            unit_registry[unit.uuid].hex = reported_hex

#endregion            