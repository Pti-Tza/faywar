class_name SectionHandler
extends Node

## Emitted when armor takes damage (amount, remaining)
signal armor_damaged(amount: float, remaining: float)
## Emitted when structure takes damage (amount, remaining)
signal structure_damaged(amount: float, remaining: float)
## Emitted when section structure reaches zero
signal section_destroyed

## Reference to SectionData resource containing static properties
@export var section_data: SectionData

# Runtime state
var current_armor: float      # Current armor points
var current_structure: float  # Current structure points
var component_handlers: Array[ComponentHandler] = []  # Child components

# Initialize section state when added to scene tree
func _ready():
    current_armor = section_data.max_armor
    current_structure = section_data.max_structure
    _initialize_components()

## Main damage entry point for the section
## @param base_damage: float - Raw damage before armor reduction
func apply_damage(base_damage: float) -> void:
    # First apply damage to armor
    var armor_damage = min(base_damage, current_armor)
    current_armor -= armor_damage
    armor_damaged.emit(armor_damage, current_armor)
    
    # Calculate remaining damage to apply to structure
    var remaining_damage = base_damage - armor_damage
    if remaining_damage > 0:
        _apply_structure_damage(remaining_damage)

# Handles damage to internal structure
func _apply_structure_damage(damage: float) -> void:
    var structure_damage = min(damage, current_structure)
    current_structure -= structure_damage
    structure_damaged.emit(structure_damage, current_structure)
    
    if current_structure <= 0:
        section_destroyed.emit()
    else:
        # Distribute residual damage to critical components
        _distribute_component_damage(damage)

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