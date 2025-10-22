# ComponentData.gd
extends Resource
class_name ComponentData

@export var component_name: String = "Unnamed Component"
@export var max_health: float = 10.0
@export var slots_occupied: int = 1 # Slots this component occupies (e.g., 3 for a Large Laser)

@export var is_critical: bool = true # Whether this component is critical
