
extends Node
class_name BaseController
# Signals
signal turn_started(controller: BaseController)
signal turn_ended(controller: BaseController)
signal action_selected(action: String)

# Must be implemented by inheritors
func begin_turn(unit: Node) -> void:
    pass

func process_turn(delta: float) -> void:
    pass

func end_turn() -> void:
    turn_ended.emit(self)