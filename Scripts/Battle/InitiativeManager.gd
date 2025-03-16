# initiative_manager.gd
class_name InitiativeManager
extends Node
## Interface for initiative management implementations

## Emitted when turn order changes
signal turn_order_updated(order: Array[UnitHandler])
## Emitted when new round starts
signal round_reset
## Emitted when unit is added to initiative
signal unit_added(unit: UnitHandler)
## Emitted when unit is removed from initiative
signal unit_removed(unit: UnitHandler)

## Initialize system with configuration data
func initialize(data: InitiativeData) -> void: pass

## Add unit to initiative tracking
func add_unit(unit: UnitHandler) -> void: pass

## Remove unit from initiative tracking
func remove_unit(unit: UnitHandler) -> void: pass

## Get current turn order prediction
func get_turn_order() -> Array[UnitHandler]: return []

## Progress to next unit in initiative order
func get_next_unit() -> UnitHandler: return null

## Reset initiative for new round
func reset_round() -> void: pass

## Force update of turn order prediction
func recalculate_order() -> void: pass