# ComponentData.gd
extends Resource
class_name ComponentData


## Component definition with static properties
@export var component_name: String = "Unnamed Component"
@export var max_health: float = 10.0
@export var is_critical: bool = false
@export var destruction_effect: PackedScene


