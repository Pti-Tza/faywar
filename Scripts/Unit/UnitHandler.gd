extends Node3D

class_name UnitHandler


## Emitted when any section takes damage
signal unit_damaged(section_name: String, damage: float)
## Emitted when unit is destroyed
signal unit_destroyed
## Emitted when heat level changes
signal heat_changed(new_value: float)

## Reference to UnitData resource containing unit configuration
var unit_data: UnitData

# Runtime state 
var section_handlers: Array[SectionHandler] = []  # Child sections
var current_heat: float = 0.0                     # Current heat level

# Initialize unit when added to scene tree
func _ready():
    _initialize_sections()
    _connect_signals()

## Public method to damage specific section
## @param section_name: String - Name of section to damage
## @param damage: float - Amount of damage to apply
func apply_damage(section_name: String, damage: float) -> void:
    var handler = _get_section_handler(section_name)
    if handler:
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
        section_handlers.append(handler)
        add_child(handler)

# Connect section destruction signals
func _connect_signals() -> void:
    for handler in section_handlers:
        handler.section_destroyed.connect(_on_section_destroyed)

# Find section handler by name
func _get_section_handler(section_name: String) -> SectionHandler:
    for handler in section_handlers:
        if handler.section_data.section_name == section_name:
            return handler
    return null

# Handle section destruction event
func _on_section_destroyed() -> void:
    if _check_critical_destruction():
        unit_destroyed.emit()
        queue_free()

# Check if all critical sections are destroyed
func _check_critical_destruction() -> bool:
    for section_name in unit_data.critical_sections:
        if _get_section_handler(section_name).current_structure > 0:
            return false
    return true

# Monitor for overheating conditions
func _check_overheat() -> void:
    if current_heat >= unit_data.heat_capacity:
        _trigger_shutdown()

# Handle overheating consequences
func _trigger_shutdown() -> void:
    # Apply emergency damage to all sections
    for handler in section_handlers:
        handler.apply_damage(5.0)  # Constant emergency damage value