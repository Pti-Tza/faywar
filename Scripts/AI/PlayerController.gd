
extends BaseController
class_name PlayerController

func begin_turn(unit: Node) -> void:
    super(unit)
    UnitManager.select_unit(unit)
    ActionMenu.enable()

func process_turn(delta: float) -> void:
    # Input handling inherited from player logic
    pass