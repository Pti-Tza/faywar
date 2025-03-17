extends BaseController
class_name PlayerController

### Class-level documentation ###
'''
PlayerController manages player-controlled units during their turn.
It selects the unit and enables the action menu for player input.
'''

### Exported Properties ###
# None required for player controller

### Internal State ###
# Inherits _current_unit from BaseController

### Public API ###
func begin_turn(unit: Node) -> void:
    '''
    @brief Begins the turn for the player-controlled unit
    @param unit: Node - The unit to control
    '''
    super.begin_turn(unit)
    assert(UnitManager != null, "UnitManager reference is missing")
    assert(ActionMenu != null, "ActionMenu reference is missing")
    
    UnitManager.select_unit(unit)
    ActionMenu.enable()

func process_turn(delta: float) -> void:
    '''
    @brief Processes the player's turn logic
    @param delta: float - Time elapsed since the last frame
    @note Input handling is managed by the player logic
    '''
    pass