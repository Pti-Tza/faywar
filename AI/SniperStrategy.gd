extends AIStrategy
class_name SniperStrategy

### Class-level documentation ###
'''
SniperStrategy is an AI strategy that focuses on defensive positioning and long-range combat.
It finds the best defensive position and targets the weakest enemy with long-range weapons.
'''

### Exported Properties ###
# None required for sniper strategy

### Internal State ###
# Inherits _unit from AIStrategy

### Public API ###
func initialize(unit: Node) -> void:
    '''
    @brief Initializes the sniper strategy with the given unit
    @param unit: Node - The unit to control
    '''
    super.initialize(unit)
    assert(PositionEvaluator != null, "PositionEvaluator reference is missing")
    assert(ThreatAnalyzer != null, "ThreatAnalyzer reference is missing")
    assert(CombatPlanner != null, "CombatPlanner reference is missing")
    assert(Pathfinder != null, "Pathfinder reference is missing")

func calculate_movement() -> Dictionary:
    '''
    @brief Calculates the movement plan for the sniper unit
    @return: Dictionary - Movement plan with keys: "valid", "target", "path"
    '''
    var best_cover = PositionEvaluator.find_defensive_position(_unit)
    if best_cover:
        return {
            "valid": true,
            "target": best_cover,
            "path": Pathfinder.find_path(_unit.position, best_cover)
        }
    return {"valid": false}

func calculate_combat() -> Dictionary:
    '''
    @brief Calculates the combat plan for the sniper unit
    @return: Dictionary - Combat plan with keys: "valid", "target", "weapon"
    '''
    var best_target = ThreatAnalyzer.get_weakest_target(_unit)
    var long_range_weapon = CombatPlanner.select_long_range_weapon(_unit)
    if best_target and long_range_weapon:
        return {
            "valid": true,
            "target": best_target,
            "weapon": long_range_weapon
        }
    return {"valid": false}

func get_priority() -> float:
    '''
    @brief Gets the priority of the current plan
    @return: float - Priority value (higher values indicate higher priority)
    '''
    return 0.5  # Medium priority for sniper strategy