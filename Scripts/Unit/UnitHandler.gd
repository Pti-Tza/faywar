extends Node3D
class_name UnitHandler

## Emitted when any section takes damage
signal unit_damaged(section_name: String, damage: float)
## Emitted when unit is destroyed
signal unit_destroyed
## Emitted when heat level changes
signal heat_changed(new_value: float)

## Unique identifier system for mission-critical units
@export var unit_id: String = ""  # "enemy_commander_1"


## Reference to UnitData resource containing unit configuration
@export var unit_data: UnitData

# Runtime state 
var section_handlers: Dictionary = {} # Child sections by name for faster lookup
var current_heat: float = 0.0 # Current heat level

# Initialize unit when added to scene tree
func _ready():
    if not unit_data:
        push_error("UnitHandler: Missing unit_data reference")
        queue_free()
        return
    _initialize_sections()
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

# Create section handlers from unit data
func _initialize_sections() -> void:
    for section_data in unit_data.sections:
        var handler = SectionHandler.new()
        handler.section_data = section_data
        section_handlers[section_data.section_name] = handler  # Use dictionary for faster lookup
        add_child(handler)

# Connect section destruction signals
func _connect_signals() -> void:
    for handler in section_handlers.values():
        handler.section_destroyed.connect(_on_section_destroyed)

# Find section handler by name
func _get_section_handler(section_name: String) -> SectionHandler:
    return section_handlers.get(section_name, null)

# Handle section destruction event
func _on_section_destroyed(_section : SectionHandler) -> void:
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