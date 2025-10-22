extends Node
class_name BaseController

### Class-level documentation ###
'''
BaseController is an abstract class for managing unit turns.
It provides a framework for both AI and player controllers.
Subclasses must implement the `begin_turn`, `process_turn`, and `end_turn` methods.
'''
@export var hex_grid : HexGridManager
@export var attack_system : AttackSystem
### Signals ###
signal turn_started(controller: BaseController)
    # Emitted when the turn starts
signal turn_ended(controller: BaseController)
    # Emitted when the turn ends
signal action_selected(action_type: String, details: Dictionary)



signal movement_intent(unit: Unit)
signal attack_intent(unit: Unit)

    # Emitted when an action is selected

### Exported Properties ###
# None required for base controller

### Internal State ###
var _current_unit: Unit
    # Reference to the unit currently controlled

# Team aligment
var team_index: int = 0

func is_ally(other_controller: BaseController) -> bool:
    return TeamManager.instance.are_allies(team_index, other_controller.team_index)

func is_enemy(other_controller: BaseController) -> bool:
    return TeamManager.instance.are_enemies(team_index, other_controller.team_index)

func get_hostile_teams() -> Array[int]:
    return TeamManager.instance.get_hostile_teams(team_index)

### Public API ###
func begin_turn(unit: Unit) -> void:
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
