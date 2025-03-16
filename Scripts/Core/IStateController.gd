
extends Node
class_name IStateController
## Base interface for all state controllers in the game state machine
##
## Provides core lifecycle methods and transition validation for game states
## Implementations should override all base methods

signal state_entered(context: Dictionary)
signal state_exited(transition_data: Dictionary)

## Called when entering this state
## @param context: Dictionary containing initialization data from previous state
## @warning: Implementations must call super()
func enter_state(context: Dictionary) -> void:
    state_entered.emit(context)

## Called when exiting this state
## @return: Dictionary containing transition payload for next state
## @warning: Implementations must call super()
func exit_state() -> Dictionary:
    var transition_data = {}
    state_exited.emit(transition_data)
    return transition_data

## Get unique state identifier
## @return: String in SCREAMING_SNAKE_CASE format
func get_state_name() -> String:
    push_error("get_state_name() not implemented in base state controller")
    return "BASE_STATE"

## Handle input events specific to this state
## @param event: Godot InputEvent to process
func handle_input(event: InputEvent) -> void:
    pass

## Validate potential state transition
## @param next_state: Requested state identifier
## @return: Boolean indicating valid transition
func can_transition_to(next_state: String) -> bool:
    return true

## Cleanup resources when state is invalidated
## @param error: Error context for recovery
func emergency_cleanup(error: String) -> void:
    push_warning("Emergency cleanup triggered: %s" % error)
    queue_free()