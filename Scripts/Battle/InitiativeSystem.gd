# initiative_system.gd
class_name InitiativeSystem
extends Node
## Speed-based initiative implementation with tiebreaker support
static var instance: InitiativeSystem
## Current initiative order
var _turn_order: Array[UnitHandler] = []
## Configuration resource
## Random number generator for tiebreaks
var _rng: RandomNumberGenerator
## Deferred prediction update timer
var _prediction_timer: Timer

@export_category("Calculation Parameters")
## Weight multiplier for unit speed in initiative calculation
## Higher values increase speed's impact on turn order
@export var base_speed_weight: float = 1.0

## Weight multiplier for unit agility in initiative calculation
## Combines with speed for composite initiative score
@export var agility_weight: float = 0.5

## Random variance range applied to initiative scores (min, max)
## Adds unpredictability while maintaining stat dominance
## Format: Vector2(x = minimum variance, y = maximum variance)
@export var variance_range: Vector2 = Vector2(-0.1, 0.1)

@export_category("Tiebreakers")
## Ordered list of tiebreaker criteria (first match wins)
## Valid values: "speed", "agility", "random"
## Example: ["speed", "random"] - Compare speed, then random if tied
@export var tiebreaker_priority := ["speed", "agility", "random"]

## Seed value for deterministic random tiebreakers
## Zero = true random, Non-zero = reproducible results
@export var random_seed: int = 0

@export_category("UI Configuration")
## Delay (in seconds) before updating turn order predictions
## Prevents visual jitter during rapid calculations
@export var prediction_update_delay: float = 0.2


signal round_reset
signal unit_added
signal unit_removed(unit: UnitHandler)
signal turn_order_updated(_turn_order: Array[UnitHandler])

func _init():
	_prediction_timer = Timer.new()
	_prediction_timer.wait_time = 0.2
	_prediction_timer.one_shot = true
	_prediction_timer.timeout.connect(_emit_updated_order)
	add_child(_prediction_timer)
	instance = self
	_rng = RandomNumberGenerator.new()
	_rng.seed = random_seed

func add_unit(unit: UnitHandler) -> void:
	if not _turn_order.has(unit):
		_turn_order.append(unit)
		_queue_order_update()
		unit_added.emit(unit)

func remove_unit(unit: UnitHandler) -> void:
	if unit in _turn_order:
		_queue_order_update()
		unit_removed.emit(unit)

func get_turn_order() -> Array[UnitHandler]:
	return _turn_order.duplicate()

func get_next_unit() -> UnitHandler:
	if _turn_order.is_empty():
		return null
	return _turn_order.pop_front()

func reset_round() -> void:
	_recalculate_initiatives()
	round_reset.emit()
	_queue_order_update()

func recalculate_order() -> void:
	_turn_order.sort_custom(_compare_units)
	_queue_order_update()

## Core initiative calculation
func _recalculate_initiatives() -> void:
	for unit in _turn_order:
		var variance = _rng.randf_range(
			variance_range.x,
			variance_range.y
		)
		unit.initiative = _calculate_unit_initiative(unit) + variance
	
	_turn_order.sort_custom(_compare_units)

func _calculate_unit_initiative(unit: UnitHandler) -> float:
	return (
		unit.stats.speed * base_speed_weight +
		unit.stats.agility * agility_weight
	)

## Custom sort comparison with tiebreakers
func _compare_units(a: UnitHandler, b: UnitHandler) -> bool:
	if a.initiative != b.initiative:
		return a.initiative > b.initiative
	
	for tiebreaker in tiebreaker_priority:
		match tiebreaker:
			"speed":
				if a.stats.speed != b.stats.speed:
					return a.stats.speed > b.stats.speed
			"agility":
				if a.stats.agility != b.stats.agility:
					return a.stats.agility > b.stats.agility
			"random":
				return _rng.randf() > 0.5
	
	return true

## Debounce prediction updates
func _queue_order_update() -> void:
	if not _prediction_timer.is_stopped():
		_prediction_timer.stop()
	_prediction_timer.start()

func _emit_updated_order() -> void:
	turn_order_updated.emit(_turn_order.duplicate())
