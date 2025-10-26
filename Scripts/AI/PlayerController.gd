# PlayerController.gd
extends BaseController
class_name PlayerController

static var instance: PlayerController

func _init() -> void:
	instance = self

func begin_turn(unit: Unit) -> void:
	_current_unit = unit
	movement_intent.emit(unit)  # Let UI show movement range

## Handles validated move input from UI (e.g., clicked destination hex)
## @param path: Array[HexCell] - Full path from current position to destination
func handle_move_input(path: Array[HexCell]) -> void:
	if path.is_empty() or not _current_unit:
		return

	action_selected.emit("move", {
		"unit": _current_unit,
		"path": path
	})

## Handles validated attack input from UI (e.g., clicked enemy unit)
## @param target: Unit - Enemy unit to attack
## @param weapon: WeaponData - Selected weapon to use
func handle_attack_input(target: Unit, weapon: WeaponData) -> void:
	if not _current_unit or not target or not weapon:
		return

	action_selected.emit("attack", {
		"source": _current_unit,
		"target": target,
		"weapon": weapon
	})

func cancel_action() -> void:
	action_selected.emit("cancel", {})
