# turnmanager.gd

extends Node
class_name TurnManager

## Emitted when turn order changes
signal turn_order_updated(order: Array)
## Emitted when new round starts
signal round_started(round_number: int)
## Emitted when unit begins turn
signal unit_turn_started(unit: Node)
## Emitted when all AP is spent
signal round_ended()

# Region: Configuration ------------------------------------------------------
@export var base_actions_per_round: int = 1  # Default AP per unit
var unit_manger : UnitManager
# Region: Runtime State ------------------------------------------------------
var _current_round: int = 0
var _turn_queue: Array = []  # Max-heap based on initiative
var _destroyed_units: Array = []

# Region: Public API ---------------------------------------------------------

func start_new_round() -> void:
    """Initialize new round with fresh initiative calculations"""
    _current_round += 1
    _destroyed_units.clear()
    _refresh_initiative_queue()
    round_started.emit(_current_round)
    _process_next_unit()

func cancel_current_turn() -> void:
    """Handle interruption (e.g., unit destroyed mid-action)"""
    if _turn_queue.is_empty():
        return
    
    var current_unit = _peek_next_unit()
    current_unit.refund_ap()
    _destroyed_units.append(current_unit)
    _process_next_unit()

# Region: Core Turn Logic ----------------------------------------------------

func _process_next_unit() -> void:
    """Advance to next unit in initiative order"""
    if _turn_queue.is_empty():
        _end_round()
        return
    
    var unit = _pop_next_unit()
    
    if _validate_unit(unit):
        unit_turn_started.emit(unit)
        unit.connect("action_completed", _on_unit_action_completed)
    else:
        _process_next_unit()

func _on_unit_action_completed(unit: Node, ap_used: int) -> void:
    """Handle AP deduction and requeue if remaining AP > 0"""
    unit.disconnect("action_completed", _on_unit_action_completed)
    
    if unit.current_ap > 0:
        unit.current_ap -= ap_used
        if unit.current_ap > 0:
            _requeue_unit(unit)
    
    _process_next_unit()

# Region: Initiative Management ----------------------------------------------

func _refresh_initiative_queue() -> void:
    """Rebuild initiative queue with fresh calculations"""
    _turn_queue.clear()
    var all_units = UnitManager.get_all_units()
    
    for unit in all_units:
        unit.current_ap = base_actions_per_round
        var initiative = _calculate_unit_initiative(unit)
        _heap_insert(initiative, unit)
    
    _emit_turn_order()

func _calculate_unit_initiative(unit: Node) -> float:
    """Calculate initiative value with tiebreaker"""
    var base = unit.stats.initiative
    var variance = randf_range(-0.1, 0.1)  # Prevent exact ties
    var tiebreaker = unit.stats.speed / 100.0
    return base + variance + tiebreaker

func _requeue_unit(unit: Node) -> void:
    """Reinsert unit into queue with current initiative"""
    var current_initiative = _get_current_initiative(unit)
    _heap_insert(current_initiative, unit)
    _emit_turn_order()

# Region: Priority Queue Implementation --------------------------------------

func _heap_insert(initiative: float, unit: Node) -> void:
    """Max-heap insertion based on initiative"""
    _turn_queue.append({"initiative": initiative, "unit": unit})
    var index = _turn_queue.size() - 1
    
    while index > 0:
        var parent = (index - 1) >> 1
        if _turn_queue[parent].initiative >= initiative:
            break
        _swap(index, parent)
        index = parent

func _pop_next_unit() -> Node:
    """Extract highest initiative unit"""
    if _turn_queue.is_empty():
        return null
    
    var result = _turn_queue[0].unit
    var last = _turn_queue.pop_back()
    
    if _turn_queue.size() > 0:
        _turn_queue[0] = last
        _heapify_down(0)
    
    return result

func _heapify_down(index: int) -> void:
    var size = _turn_queue.size()
    while true:
        var left = (index << 1) + 1
        var right = (index << 1) + 2
        var largest = index
        
        if left < size && _turn_queue[left].initiative > _turn_queue[largest].initiative:
            largest = left
        if right < size && _turn_queue[right].initiative > _turn_queue[largest].initiative:
            largest = right
        
        if largest == index:
            break
        
        _swap(index, largest)
        index = largest

# Region: Helper Methods -----------------------------------------------------

func _validate_unit(unit: Node) -> bool:
    """Check if unit can act"""
    return unit.current_ap > 0 && !unit.is_destroyed && !_destroyed_units.has(unit)

func _end_round() -> void:
    """Cleanup round state and notify systems"""
    UnitManager.reset_unit_states()
    round_ended.emit()

func _emit_turn_order() -> void:
    """Send current turn order to UI systems"""
    var order = _turn_queue.map(func(entry): return entry.unit)
    turn_order_updated.emit(order)

func _swap(a: int, b: int) -> void:
    var temp = _turn_queue[a]
    _turn_queue[a] = _turn_queue[b]
    _turn_queue[b] = temp

# Example Unit Implementation -----------------------------------------------

class Unit:
    var stats: Dictionary = {
        "initiative": 5,
        "speed": 50
    }
    var current_ap: int = 1
    var is_destroyed: bool = false
    
    signal action_completed(ap_used: int)
    
    func refund_ap() -> void:
        current_ap += 1  # Example implementation
    
    func perform_action() -> void:
        # Action logic here
        emit_signal("action_completed", 1)