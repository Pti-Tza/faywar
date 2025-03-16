extends Resource
class_name AIStrategy

### Class-level documentation ###
'''
AIStrategy is an abstract resource for defining AI behavior.
Concrete strategies must implement `initialize`, `calculate_movement`, `calculate_combat`, and `get_priority`.
'''

### Exported Properties ###
# None required for base strategy

### Internal State ###
var _unit: Node = null
    # Reference to the unit controlled by the strategy

### Public API ###
func initialize(unit: Node) -> void:
    '''
    @brief Initializes the strategy with the given unit
    @param unit: Node - The unit to control
    @note Must be implemented by subclasses
    '''
    assert(unit != null, "Unit cannot be null")
    _unit = unit

func calculate_movement() -> Dictionary:
    '''
    @brief Calculates the movement plan for the unit
    @return: Dictionary - Movement plan with keys: "valid", "target", "path"
    @note Must be implemented by subclasses
    '''
    return {"valid": false}

func calculate_combat() -> Dictionary:
    '''
    @brief Calculates the combat plan for the unit
    @return: Dictionary - Combat plan with keys: "valid", "target", "weapon"
    @note Must be implemented by subclasses
    '''
    return {"valid": false}

func get_priority() -> float:
    '''
    @brief Gets the priority of the current plan
    @return: float - Priority value (higher values indicate higher priority)
    @note Must be implemented by subclasses
    '''
    return 0.0