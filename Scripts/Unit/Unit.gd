extends Node3D
class_name Unit

## Emitted when any section takes damage
signal unit_damaged(section: UnitSection, damage: float)
## Emitted when unit is destroyed
signal unit_destroyed(unit: Unit)
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
var sections: Array[UnitSection] = []
@export var base_heat_capacity: float = 30.0
@export var base_heat_dissipation: float = 2.0
@export var mobility_type: MobilityType = MobilityType.BIPEDAL
@export var max_elevation_change: int = 2



@export var walk_mp: int = 4
@export var run_mp_bonus: int = 2
@export var jump_mp: int = 0

@export var team: int = 0


## Unique identifier system for mission-critical units
@export var unit_id: String = ""  # "enemy_commander_1"


# Runtime state 
var current_heat: float = 0.0 # Current heat level

# Initialize unit when added to scene tree
func _ready():
	sections.clear()
	for child in get_children():
		if child is UnitSection:
			sections.append(child)
			for component in child.component_handlers:
				component.component_destroyed.connect(_on_component_destroyed.bind(component.component_data)) 
	
	_connect_signals()

func initialize(desired_team, desired_id):
	team = 	desired_team
	unit_id = desired_id

## Public method to damage specific section
## @param section_name: String - Name of section to damage
## @param damage: float - Amount of damage to apply
func apply_damage(section: UnitSection, damage: float) -> void:
	
	section.apply_damage(damage)
	unit_damaged.emit(section, damage)

## Public method to apply heat to the unit
## @param heat: float - Amount of heat to add
func apply_heat(heat: float) -> void:
	current_heat = clamp(current_heat + heat, 0.0, base_heat_capacity)
	heat_changed.emit(current_heat)
	#_check_overheat()



# Connect section destruction signals
func _connect_signals() -> void:
	for handler in sections:
		handler.section_destroyed.connect(_on_section_destroyed)

# Find section handler by name
func _get_section_by_name(section_name: String) -> UnitSection:
	return sections.filter(func(u): return u.name == section_name)[0]

# Handle section destruction event
func _on_section_destroyed(_section : UnitSection) -> void:
	#if _check_critical_destruction():
	if _section.section_data.critical == true :
		unit_destroyed.emit(self)
		queue_free()

func _on_component_destroyed(comp_ : ComponentHandler) -> void:
	if comp_.component_data.is_critical:        
		# Instant destruction
		unit_destroyed.emit()

func get_total_armor() -> int:
	return sections.reduce(func(acc, s): return acc + s.current_armor, 0)

func get_total_structure() -> int:
	return sections.reduce(func(acc, s): return acc + s.current_structure, 0)        

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
