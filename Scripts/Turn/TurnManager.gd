extends Node
class_name TurnManager

# Configuration
@export var initiative_tiebreaker_metric: String = "tonnage"  # or "random"

# State
var units: Array = []  # Array[Unit]
var unit_initiatives: Dictionary = {}  # Unit: int
var current_unit_index: int = -1

# Signals
signal initiative_rolled(unit: Unit, value: int)
signal unit_turn_started(unit: Unit)
signal unit_turn_ended(unit: Unit)
signal all_units_acted

# Dependencies
@onready var game_manager: GameManager = get_node("/root/GameManager")

# -------------------------------
# Public API
# -------------------------------

func initialize_units(unit_list: Array) -> void:
    units = unit_list.filter(func(u): return u.is_alive)

func roll_initiative() -> void:
    if units.is_empty():
        push_error("TurnManager: No units to roll initiative")
        return
    
    unit_initiatives.clear()
    for unit in units:
        if !unit.is_alive: continue
        if !unit.has_method("calculate_initiative"):
            push_error("Unit %s missing initiative logic" % unit.name)
            continue
        
        var initiative = unit.calculate_initiative()
        unit_initiatives[unit] = initiative
        emit_signal("initiative_rolled", unit, initiative)
    
    if unit_initiatives.is_empty():
        push_error("TurnManager: All units failed initiative rolls")
        return
    
    units = units.filter(func(u): return u in unit_initiatives)
    units.sort_custom(_sort_units_by_initiative)
    _apply_tiebreakers()
    start_unit_turn(units[0])

# -------------------------------
# Turn Flow
# -------------------------------

func start_unit_turn(unit: Unit) -> void:
    if !unit.is_alive:
        advance_to_next_unit()
        return
    
    current_unit_index = units.find(unit)
    game_manager.set_active_player(unit.controller_id)
    emit_signal("unit_turn_started", unit)
    unit.start_turn()

func end_unit_turn(unit: Unit) -> void:
    if !unit.is_alive: units.erase(unit)
    emit_signal("unit_turn_ended", unit)
    unit.end_turn()
    
    if current_unit_index >= units.size() - 1:
        emit_signal("all_units_acted")
        _clean_destroyed_units()
        game_manager.advance_phase()
    else:
        start_unit_turn(units[current_unit_index + 1])

# -------------------------------
# Helpers
# -------------------------------

func _apply_tiebreakers() -> void:
    var groups = {}
    for unit in units:
        var score = unit_initiatives[unit]
        if not groups.has(score):
            groups[score] = []
        groups[score].append(unit)
    
    for score in groups:
        match initiative_tiebreaker_metric:
            "tonnage":
                groups[score].sort_custom(func(a,b): return a.tonnage > b.tonnage)
            "random":
                groups[score].shuffle()
    
    var sorted = []
    for score in groups.keys().sort().reverse():
        sorted += groups[score]
    units = sorted

func _clean_destroyed_units() -> void:
    units = units.filter(func(u): return u.is_alive)

func _sort_units_by_initiative(a: Unit, b: Unit) -> bool:
    return unit_initiatives[a] > unit_initiatives[b]

# -------------------------------
# Phase Handling
# -------------------------------

func _on_game_phase_changed(new_phase: GameManager.GamePhase) -> void:
    match new_phase:
        GameManager.GamePhase.INITIATIVE:
            if game_manager.current_turn == 1:
                initialize_units(UnitManager.get_all_units())
            roll_initiative()
        GameManager.GamePhase.END:
            reset_turn_order()

func reset_turn_order() -> void:
    current_unit_index = -1
    initialize_units(UnitManager.get_all_units())  # Re-register surviving units