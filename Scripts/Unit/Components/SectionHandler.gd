
extends Node
class_name SectionHandler
## Emitted when armor takes damage (amount, remaining)
signal armor_damaged(amount: float, remaining: float)
## Emitted when structure takes damage (amount, remaining)
signal structure_damaged(amount: float, remaining: float)
## Emitted when section structure reaches zero
signal section_destroyed

### Core Properties ###
var section_data: SectionData
var current_armor: float = 0.0
var current_structure: float = 0.0
var component_handlers: Array[ComponentHandler] = []  # Child components

# Initialize section state when added to scene tree
func _ready():
    current_armor = section_data.max_armor
    current_structure = section_data.max_structure
    _initialize_components()

## Main damage entry point for the section
## @param damage: float - Raw damage before armor reduction
### Damage Handling ###
func apply_damage(damage: float) -> void:
    # Reduce structure if armor is depleted
    if current_armor > 0:
        current_armor = max(current_armor - damage, 0.0)
        armor_damaged.emit(damage, current_armor)
    else:
        current_structure -= damage
        structure_damaged.emit(damage, current_structure)
        
        # Check for destruction
        if current_structure <= 0:
            section_destroyed.emit(section_data.section_name)

func _on_section_destroyed(section_name: String) -> void:
    # Optional: Handle section-specific effects (e.g., explosion)
    emit_signal("section_destroyed", section_name)

# Creates component handlers from section data
func _initialize_components() -> void:
    for component_data in section_data.components:
        var handler = ComponentHandler.new()
        handler.component_data = component_data
        component_handlers.append(handler)
        add_child(handler)

# Applies damage to critical components in the section
func _distribute_component_damage(damage: float) -> void:
    for handler in component_handlers:
        if handler.is_operational() && handler.component_data.is_critical:
            # Apply 50% of remaining damage to critical components
            handler.apply_damage(damage * 0.5)