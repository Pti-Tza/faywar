extends AIStrategy
class_name BerserkerStrategy

### Class-level documentation ###
'''
BerserkerStrategy is an AI strategy that focuses on aggressive movement and combat.
It targets the nearest enemy and uses the most damaging weapon available.
'''

### Exported Properties ###
# None required for berserker strategy

### Internal State ###
# Inherits _unit from AIStrategy

### Public API ###
func initialize(unit: Node) -> void:
    '''
    @brief Initializes the berserker strategy with the given unit
    @param unit: Node - The unit to control
    '''
    super.initialize(unit)
    assert(ThreatAnalyzer != null, "ThreatAnalyzer reference is missing")
    assert(Pathfinder != null, "Pathfinder reference is missing")
    assert(CombatPlanner != null, "CombatPlanner reference is missing")

func calculate_movement() -> Dictionary:
    '''
    @brief Calculates the movement plan for the berserker unit
    @return: Dictionary - Movement plan with keys: "valid", "target", "path"
    '''
    var nearest_enemy = ThreatAnalyzer.find_nearest_enemy(_unit)
    if nearest_enemy:
        return {
            "valid": true,
            "target": nearest_enemy.position,
            "path": Pathfinder.find_path(_unit.position, nearest_enemy.position)
        }
    return {"valid": false}

func calculate_combat() -> Dictionary:
    '''
    @brief Calculates the combat plan for the berserker unit
    @return: Dictionary - Combat plan with keys: "valid", "target", "weapon"
    '''
    var best_weapon = CombatPlanner.select_most_damaging_weapon(_unit)
    var priority_target = ThreatAnalyzer.get_priority_target(_unit)
    if priority_target and best_weapon:
        return {
            "valid": true,
            "target": priority_target,
            "weapon": best_weapon
        }
    return {"valid": false}

func get_priority() -> float:
    '''
    @brief Gets the priority of the current plan
    @return: float - Priority value (higher values indicate higher priority)
    '''
    return 1.0  # High priority for berserker strategy