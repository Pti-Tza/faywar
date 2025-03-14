
extends AIStrategy
class_name BerserkerStrategy
func calculate_movement() -> Dictionary:
    var nearest_enemy = ThreatAnalyzer.find_nearest_enemy(unit)
    return {
        "valid": true,
        "target": nearest_enemy.position,
        "path": Pathfinder.find_path(unit.position, nearest_enemy.position)
    }

func calculate_combat() -> Dictionary:
    var best_weapon = CombatPlanner.select_most_damaging_weapon(unit)
    return {
        "valid": true,
        "target": ThreatAnalyzer.get_priority_target(unit),
        "weapon": best_weapon
    }