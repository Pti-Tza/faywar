
extends Resource
class_name AIStrategy
# Must be implemented by concrete strategies
func initialize(unit: Node) -> void:
    pass

func calculate_movement() -> Dictionary:
    return {"valid": false}

func calculate_combat() -> Dictionary:
    return {"valid": false}

func get_priority() -> float:
    return 0.0