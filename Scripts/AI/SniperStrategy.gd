
extends AIStrategy
class_name SniperStrategy

func calculate_movement() -> Dictionary:
    var best_cover = PositionEvaluator.find_defensive_position(unit)
    return {
        "valid": true,
        "target": best_cover,
        "path": Pathfinder.find_path(unit.position, best_cover)
    }

func calculate_combat() -> Dictionary:
    var best_target = ThreatAnalyzer.get_weakest_target(unit)
    return {
        "valid": true,
        "target": best_target,
        "weapon": CombatPlanner.select_long_range_weapon(unit)
    }