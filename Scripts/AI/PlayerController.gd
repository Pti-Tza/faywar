extends BaseController
class_name PlayerController




func begin_turn(unit: UnitHandler) -> void:
    _current_unit = unit
    movement_intent.emit(unit)  # Let BattleUIController handle visualization

func handle_move_input(path: Array[HexCell]) -> void:
    action_selected.emit("move", {
        "unit": _current_unit,
        "path": path
    })

func handle_attack_input(target: UnitHandler, weapon: WeaponData) -> void:
    action_selected.emit("attack", {
        "source": _current_unit,
        "target": target,
        "weapon": weapon
    })

func cancel_action() -> void:
    action_selected.emit("cancel", {})