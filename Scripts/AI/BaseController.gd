extends Node
class_name BaseController

### Class-level documentation ###
'''
BaseController is an abstract class for managing unit turns.
It provides a framework for both AI and player controllers.
Subclasses must implement the `begin_turn`, `process_turn`, and `end_turn` methods.
'''

### Signals ###
signal turn_started(controller: BaseController)
    # Emitted when the turn starts
signal turn_ended(controller: BaseController)
    # Emitted when the turn ends
signal action_selected(action: String)
    # Emitted when an action is selected

### Exported Properties ###
# None required for base controller

### Internal State ###
var _current_unit: Node = null
    # Reference to the unit currently controlled

### Public API ###
func begin_turn(unit: Node) -> void:
    '''
    @brief Begins the turn for the specified unit
    @param unit: Node - The unit to control
    @note Must be implemented by subclasses
    '''
    assert(unit != null, "Unit cannot be null")
    _current_unit = unit
    turn_started.emit(self)

func process_turn(delta: float) -> void:
    '''
    @brief Processes the turn logic
    @param delta: float - Time elapsed since the last frame
    @note Must be implemented by subclasses
    '''
    pass

func end_turn() -> void:
    '''
    @brief Ends the turn and resets internal state
    '''
    _current_unit = null
    turn_ended.emit(self)