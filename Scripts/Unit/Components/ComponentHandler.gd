
extends Node
class_name ComponentHandler
## Emitted when component's health changes, provides remaining health
signal component_damaged(health_remaining: float)
## Emitted when component's health reaches zero
signal component_destroyed(comp : ComponentHandler)

## Reference to the ComponentData resource containing static properties
@export var component_data: ComponentData

## Current health of the component with setter logic
var current_health: float:
	set(value):
		# Clamp health between 0 and max value, then update signals
		current_health = clamp(value, 0.0, component_data.max_health)
		component_damaged.emit(current_health)
		if current_health <= 0.0:
			component_destroyed.emit(self)

## Applies damage to the component
## @param damage: float - Amount of damage to apply
func apply_damage(damage: float) -> void:
	current_health -= damage

## Checks if component is still functional
## @return: bool - True if health > 0
func is_operational() -> bool:
	return current_health > 0.0

# Initialize component health when added to scene tree
func _ready():
	current_health = component_data.max_health
