# UnitProfile.gd
# A modular data resource for defining unit types and their properties.
# Supports Mechs, Vehicles, Infantry, and custom unit types.

class_name UnitProfile
extends Resource

# --------------------------
# Core Identification
# --------------------------

## Unique identifier for this unit profile
@export var profile_id: String = ""

## Display name for the unit
@export var unit_name: String = "Unnamed Unit"

## Unit type (Mech, Vehicle, Infantry, etc.)
@export var unit_type: String = "Mech"

## Path to the scene used for this unit
@export var unit_scene: PackedScene

# --------------------------
# Movement Properties
# --------------------------

## Base movement points (MP) for walking
@export var walk_mp: int = 4

## Additional MP when running (total = walk_mp + run_mp_bonus)
@export var run_mp_bonus: int = 2

## Jump capability (0 = no jump jets)
@export var jump_mp: int = 0

## Movement type (Biped, Quad, Tracked, Hover, etc.)
@export var movement_type: String = "Biped"

# --------------------------
# Combat Properties
# --------------------------

## Base armor points (total across all sections)
@export var base_armor: int = 100

## Base structure points (internal durability)
@export var base_structure: int = 50

## Heat capacity before shutdown
@export var heat_capacity: int = 30

## Heat dissipation per turn
@export var heat_dissipation: int = 2

# --------------------------
# Section Definitions
# --------------------------

## Armor and structure values for each section
@export var sections: Array[UnitSection] = []

## Critical hit slots for each section
@export var critical_slots: Dictionary = {
    "CTorso": ["Engine", "Gyro"],
    "LArm": ["Laser", "Actuator"]
}

# --------------------------
# Damage Modifiers
# --------------------------

## Damage multipliers by damage type
@export var damage_modifiers: Dictionary = {
    "Energy": 1.0,
    "Ballistic": 1.0,
    "Missile": 0.5
}

# --------------------------
# Methods
# --------------------------

## Returns the total armor for a specific section
func get_section_armor(section: String) -> int:
    for sec in sections:
        if sec.name == section:
            return sec.armor
    push_error("Section not found: ", section)
    return 0

## Returns the total structure for a specific section
func get_section_structure(section: String) -> int:
    for sec in sections:
        if sec.name == section:
            return sec.structure
    push_error("Section not found: ", section)
    return 0

## Returns the critical slots for a specific section
func get_critical_slots(section: String) -> Array:
    return critical_slots.get(section, [])

## Returns the damage modifier for a specific damage type
func get_damage_modifier(damage_type: String) -> float:
    return damage_modifiers.get(damage_type, 1.0)

## Validates the profile for missing or invalid data
func is_valid() -> bool:
    if unit_name.is_empty():
        push_error("UnitProfile: Missing unit name")
        return false
    if !unit_scene:
        push_error("UnitProfile: Missing unit scene")
        return false
    if sections.is_empty():
        push_warning("UnitProfile: No sections defined")
    return true