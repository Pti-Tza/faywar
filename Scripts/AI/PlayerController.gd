extends BaseController
class_name PlayerController

static var instance : PlayerController
signal action_move_requested(unit: UnitHandler)
signal action_attack_requested(unit: UnitHandler, target: UnitHandler, weapon: WeaponData)

var current_unit: UnitHandler = null

func _ready() -> void:
    instance = self
    UnitManager.instance.unit_selected.connect(_on_unit_selected)

func begin_turn(unit: UnitHandler) -> void:
    current_unit = unit
    action_move_requested.emit(unit)


func _on_unit_selected(unit: UnitHandler) -> void:
    if unit.controller.team_index == 0:
        current_unit = unit
        action_move_requested.emit(unit)

func execute_move(target: HexCell) -> void:
    if MovementSystem.instance.validate_move(current_unit, target):
        MovementSystem.instance.execute_move(current_unit, target)
        action_move_requested.emit(current_unit)

func execute_attack(target: UnitHandler, weapon: WeaponData) -> void:
    if AttackSystem.instance.validate_attack(current_unit, target, weapon):
        AttackSystem.instance.resolve_attack(current_unit, target, weapon)
        action_attack_requested.emit(current_unit, target, weapon)