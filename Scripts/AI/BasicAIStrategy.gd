# BasicAIStrategy.gd
extends AIStrategy
class_name BasicAIStrategy

# Shared dependencies
var unit_manager: UnitManager
var hex_grid: HexGridManager
var attack_system: AttackSystem

# Runtime state
var _current_unit: Unit
var _enemy_units: Array[Unit]





func calculate_movement() -> Dictionary:
    var best_target = _find_nearest_enemy()
    if not best_target:
        return {"valid": false}
    
    var path = hex_grid.find_unit_path_3d(
        _current_unit,
        _current_unit.current_hex_3d,
        best_target.current_hex_3d
    )
    
    # Get movement system to validate move
    var move_cost = hex_grid.get_path_cost(path)
    if move_cost > _current_unit.remaining_mp:
        path = path.slice(0, _current_unit.remaining_mp)
    
    return {
        "valid": path.size() > 1,
        "target": path[-1],
        "path": path
    }

func calculate_combat() -> Dictionary:
    var target = _find_nearest_enemy()
    if not target:
        return {"valid": false}
    
    var best_weapon = _select_best_weapon(target)
    if not best_weapon:
        return {"valid": false}
    
    return {
        "valid": true,
        "target": target,
        "weapon": best_weapon
    }

func get_priority() -> float:
    # Higher priority for units with more firepower
    var firepower = _current_unit.weapons.reduce(
        func(acc, w): return acc + w.damage, 0.0
    )
    return firepower

# Helper methods
func _find_nearest_enemy() -> Unit:
    var nearest = null
    var min_distance = INF
    
    for enemy in _enemy_units:
        var distance = hex_grid.get_distance(
            _current_unit.current_hex,
            enemy.current_hex
        )
        if distance < min_distance:
            min_distance = distance
            nearest = enemy
    
    return nearest

func _select_best_weapon(target: Unit) -> WeaponData:
    var best_weapon = null
    var best_score = -INF
    
    for weapon in _current_unit.weapons:
        if attack_system._validate_attack(_current_unit, target, weapon):
            var score = _calculate_weapon_score(weapon, target)
            if score > best_score:
                best_score = score
                best_weapon = weapon
    
    return best_weapon

func _calculate_weapon_score(weapon: WeaponData, target: Unit) -> float:
    # Simple scoring: damage potential adjusted by range
    var distance = hex_grid.get_distance(
        _current_unit.current_hex,
        target.current_hex
    )
    
    var range_mod = 1.0 - clamp(
        (distance - weapon.optimal_range) / 
        (weapon.maximum_range - weapon.optimal_range),
        0.0,
        1.0
    )
    
    return weapon.damage * range_mod