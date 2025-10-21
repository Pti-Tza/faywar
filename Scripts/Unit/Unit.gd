extends Node3D
class_name Unit

## Emitted when any section takes damage
signal unit_damaged(section_name: String, damage: float)
## Emitted when unit is destroyed
signal unit_destroyed
## Emitted when heat level changes
signal heat_changed(new_value: float)

enum MobilityType {
	BIPEDAL,    # Humanoid mechs/units
	WHEELED,    # Wheeled vehicles
	HOVER,      # Hovercraft/floating units
	TRACKED,    # Tank-like units
	AERIAL      # Flying units (limited)
}

## Unit definition with static properties
@export var unit_name: String = "Unnamed Unit"
@export var sections: Array[UnitSection] = []
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




## Unique identifier system for mission-critical units
@export var unit_id: String = ""  # "enemy_commander_1"


# Runtime state 
var section_handlers: Dictionary = {} # Child sections by name for faster lookup
var current_heat: float = 0.0 # Current heat level

# Initialize unit when added to scene tree
func _ready():
	
	_connect_signals()

## Public method to damage specific section
## @param section_name: String - Name of section to damage
## @param damage: float - Amount of damage to apply
func apply_damage(section_name: String, damage: float, critical: bool) -> void:
	var handler = _get_section_handler(section_name)
	if not handler:
		push_warning("UnitHandler: Section '%s' not found" % section_name)
		return
	handler.apply_damage(damage)
	unit_damaged.emit(section_name, damage)

## Public method to apply heat to the unit
## @param heat: float - Amount of heat to add
func apply_heat(heat: float) -> void:
	current_heat = clamp(current_heat + heat, 0.0, unit_data.heat_capacity)
	heat_changed.emit(current_heat)
	_check_overheat()



# Connect section destruction signals
func _connect_signals() -> void:
	for handler in section_handlers.values():
		handler.section_destroyed.connect(_on_section_destroyed)

# Find section handler by name
func _get_section_handler(section_name: String) -> UnitSection:
	return section_handlers.get(section_name, null)

# Handle section destruction event
func _on_section_destroyed(_section : UnitSection) -> void:
	#if _check_critical_destruction():
	if _section.section_data.critical == true :
		unit_destroyed.emit()
		queue_free()

# Check if all critical sections are destroyed
#func _check_critical_destruction() -> bool:
#    for section_name in unit_data.critical_sections:
#        var handler = _get_section_handler(section_name)
#        if not handler:
#            push_error("UnitHandler: Critical section '%s' not found" % section_name)
#            return false
#        if handler.current_structure > 0:
#            return false
#    return true

# Monitor for overheating conditions
func _check_overheat() -> void:
	if current_heat >= unit_data.heat_capacity:
		_trigger_shutdown()

# Handle overheating consequences
func _trigger_shutdown() -> void:
	# Apply emergency damage to all sections
	for handler in section_handlers.values():
		handler.apply_damage(5.0) # Constant emergency damage value

func get_total_armor() -> int:
	return section_handlers.values().reduce(func(acc, s): return acc + s.current_armor, 0)

func get_total_structure() -> int:
	return section_handlers.values().reduce(func(acc, s): return acc + s.current_structure, 0)        

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
