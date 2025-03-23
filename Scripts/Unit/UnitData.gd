# UnitData.gd
class_name UnitData
extends Resource

enum MobilityType {
    BIPEDAL,    # Humanoid mechs/units
    WHEELED,    # Wheeled vehicles
    HOVER,      # Hovercraft/floating units
    TRACKED,    # Tank-like units
    AERIAL      # Flying units (limited)
}

## Unit definition with static properties
@export var unit_name: String = "Unnamed Unit"
@export var sections: Array[SectionData] = []
@export var critical_sections: Array[String] = ["CTorso"]
@export var base_heat_capacity: float = 30.0
@export var base_heat_dissipation: float = 2.0
@export var mobility_type: MobilityType = MobilityType.BIPEDAL
@export var max_elevation_change: int = 2

## Path to the scene used for this unit
@export var unit_scene: PackedScene

@export var walk_mp: int = 4
@export var run_mp_bonus: int = 2
@export var jump_mp: int = 0

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
#func get_critical_slots(section: String) -> Array:
 #   return critical_slots.get(section, [])


## Validates the profile for missing or invalid data
func is_valid() -> bool:
    if unit_name.is_empty():
        push_error("UnitData: Missing unit name")
        return false
    if !unit_scene:
        push_error("UnitData: Missing unit scene")
        return false
    if sections.is_empty():
        push_warning("UnitData: No sections defined")
    return true