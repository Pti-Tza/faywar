# initiative_system.gd
class_name InitiativeSystem
extends InitiativeManager
## Speed-based initiative implementation with tiebreaker support

## Current initiative order
var _turn_order: Array[UnitHandler] = []
## Configuration resource
var _config: InitiativeData
## Random number generator for tiebreaks
var _rng: RandomNumberGenerator
## Deferred prediction update timer
var _prediction_timer: Timer

func _init():
    _prediction_timer = Timer.new()
    _prediction_timer.wait_time = 0.2
    _prediction_timer.one_shot = true
    _prediction_timer.timeout.connect(_emit_updated_order)
    add_child(_prediction_timer)

func initialize(data: InitiativeData) -> void:
    _config = data
    _rng = RandomNumberGenerator.new()
    _rng.seed = data.random_seed

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
            _config.variance_range.x,
            _config.variance_range.y
        )
        unit.initiative = _calculate_unit_initiative(unit) + variance
    
    _turn_order.sort_custom(_compare_units)

func _calculate_unit_initiative(unit: UnitHandler) -> float:
    return (
        unit.stats.speed * _config.base_speed_weight +
        unit.stats.agility * _config.agility_weight
    )

## Custom sort comparison with tiebreakers
func _compare_units(a: UnitHandler, b: UnitHandler) -> bool:
    if a.initiative != b.initiative:
        return a.initiative > b.initiative
    
    for tiebreaker in _config.tiebreaker_priority:
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