# dice_roller.gd
class_name DiceRoller
extends Node

## Enum: Different dice resolution systems supported
## - STANDARD: Sum all dice + modifier (Default)
## - SUCCESS_COUNT: Count successes (World of Darkness)
## - DROP_LOWEST/HAIGHEST: D&D-style advantage/disadvantage
## - TARGET_NUMBER: Binary success against target (Shadowrun)
## - EXPLODING: Savage Worlds-style exploding dice
enum RollType {
    STANDARD,       
    SUCCESS_COUNT,  
    DROP_LOWEST,    
    DROP_HIGHEST,   
    TARGET_NUMBER,  
    EXPLODING       
}

## Signal: Emitted after any roll with full results
## @param results: Array[int] - Individual die results
## @param total: int - Processed total
## @param metadata: Dictionary - Roll configuration
signal dice_rolled(results: Array, total: int, metadata: Dictionary)

## Signal: Emitted when critical success conditions met
## @param metadata: Dictionary - Original roll parameters
signal critical_success(metadata: Dictionary)

## Signal: Emitted when critical failure conditions met 
## @param metadata: Dictionary - Original roll parameters
signal critical_failure(metadata: Dictionary)

## Enable roll history tracking for debugging/replays
@export var enable_history: bool = true

## Maximum stored rolls in history (memory management)
@export var max_history_size: int = 20

# Internal storage for roll history
var _history: Array = []

#-------------------------------------------------------------
# Public API
#-------------------------------------------------------------

## Main dice rolling method with full configuration
## @param dice_count: Number of dice to roll (≥1)
## @param dice_sides: Sides per die (≥2)
## @param modifier: Flat number added to final result
## @param roll_type: RollType enum value
## @param options: Type-specific parameters {
##     explode: bool,          # Enable exploding dice
##     success_threshold: int, # For SUCCESS_COUNT
##     target_number: int      # For TARGET_NUMBER
## }
## @return: Dictionary {
##     results: Array[int],    # Raw die values
##     total: int,             # Processed result
##     metadata: Dictionary,   # Roll config + timestamp
##     dropped: Array[int]     # Dropped dice if applicable
## }
func roll(
    dice_count: int = 1,
    dice_sides: int = 6,
    modifier: int = 0,
    roll_type: RollType = RollType.STANDARD,
    options: Dictionary = {}
) -> Dictionary:
    # Validate input to prevent invalid states
    if dice_sides < 2:
        push_error("Invalid dice sides: %d - must be ≥2" % dice_sides)
        return {}
    
    # Capture roll metadata for signals/history
    var metadata = {
        "timestamp": Time.get_datetime_string_from_system(),
        "dice_count": dice_count,
        "dice_sides": dice_sides,
        "modifier": modifier,
        "roll_type": RollType.keys()[roll_type],
        "options": options
    }
    
    # Core dice generation
    var results = _roll_dice(dice_count, dice_sides, options)
    # Result processing based on roll type
    var processed = _process_results(results, modifier, roll_type, options)
    
    # History management
    var history_entry = metadata.duplicate()
    history_entry["raw_results"] = results
    history_entry["processed_total"] = processed.total
    _update_history(history_entry)
    
    # Event system
    dice_rolled.emit(results, processed.total, metadata)
    _check_critical(results, processed.total, metadata)
    
    return {
        "results": results,
        "total": processed.total,
        "metadata": metadata,
        "dropped": processed.dropped
    }

## BattleTech-optimized 2D6 roll with modifier
## @param modifier: Piloting/Gunnery skill modifier
## @return: Total result including modifier
func roll_2d6(modifier: int = 0) -> int:
    var result = roll(2, 6, modifier)
    return result.total

## Batch roll for AI/mass combat calculations
## @param iterations: Number of times to repeat roll
## @return: Array of roll result dictionaries
func batch_roll(
    iterations: int,
    dice_count: int,
    dice_sides: int,
    modifier: int = 0
) -> Array:
    var batch = []
    for i in iterations:
        batch.append(roll(dice_count, dice_sides, modifier))
    return batch

#-------------------------------------------------------------
# Core Logic
#-------------------------------------------------------------

## Generates raw dice results with optional exploding
## @private
func _roll_dice(count: int, sides: int, options: Dictionary) -> Array:
    var results = []
    var rng = RandomNumberGenerator.new()
    rng.randomize()
    
    for i in count:
        var result = rng.randi_range(1, sides)
        results.append(result)
        
        # Handle exploding dice recursively
        if options.get("explode", false) && result == sides:
            var explosion = _roll_dice(1, sides, options)
            results.append_array(explosion)
    
    return results

## Processes raw results based on roll type
## @private
func _process_results(
    results: Array,
    modifier: int,
    roll_type: RollType,
    options: Dictionary
) -> Dictionary:
    var processed = results.duplicate()
    var dropped = []
    
    match roll_type:
        RollType.DROP_LOWEST:
            processed.sort()
            dropped = [processed.pop_front()]
        RollType.DROP_HIGHEST:
            processed.sort()
            dropped = [processed.pop_back()]
        RollType.SUCCESS_COUNT:
            var target = options.get("success_threshold", 5)
            return {"total": processed.filter(func(r): return r >= target).size(), "dropped": []}
        RollType.TARGET_NUMBER:
            var target = options.get("target_number", 10)
            return {"total": (processed[0] + modifier) >= target, "dropped": []}
    
    return {
        "total": processed.reduce(func(a, b): return a + b, 0) + modifier,
        "dropped": dropped
    }

## Checks for critical success/failure conditions
## @private
func _check_critical(results: Array, total: int, metadata: Dictionary) -> void:
    var sides = metadata.dice_sides
    var crit_success = false
    var crit_fail = false
    
    # BattleTech-specific critical checks
    if metadata.dice_count == 2 && metadata.dice_sides == 6:
        # Standard BattleTech critical thresholds
        crit_success = total >= metadata.options.get("critical_threshold", 12)
        crit_fail = total <= metadata.options.get("fumble_threshold", 2)
    else:
        # Generic critical detection
        match metadata.dice_count:
            1: # Single die systems
                crit_success = results[0] == sides
                crit_fail = results[0] == 1
            _: # Multi-dice systems
                var max_possible = metadata.dice_count * sides
                crit_success = total >= max_possible * 0.9  # Top 10%
                crit_fail = total <= max_possible * 0.1     # Bottom 10%
    
    if crit_success:
        critical_success.emit(metadata)
    elif crit_fail:
        critical_failure.emit(metadata)

#-------------------------------------------------------------
# History Management
#-------------------------------------------------------------

## Maintains roll history FIFO buffer
## @private
func _update_history(entry: Dictionary) -> void:
    _history.append(entry)
    if _history.size() > max_history_size:
        _history.pop_front()

## Gets last roll for debugging
## @return: Last roll dictionary or empty
func get_last_roll() -> Dictionary:
    return _history.back() if !_history.is_empty() else {}

## Clears roll history
func clear_history() -> void:
    _history.clear()

## Gets full roll history copy
## @return: Array of roll dictionaries
func get_history() -> Array:
    return _history.duplicate()