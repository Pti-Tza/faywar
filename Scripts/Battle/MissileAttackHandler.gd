# MissileAttackHandler.gd
extends BaseAttackHandler

class_name MissileAttackHandler

### 
# MissileAttackHandler handles missile attack mechanics
# - Consumes ammunition
# - Determines number of missiles hitting the target
# - Applies damage to the target with critical hit checks
###

const CLUSTER_TABLE = {
    "LRM": [0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    "SRM": [0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
}

#-------------------------------------------------------------
# Protected Methods
#-------------------------------------------------------------

## Perform missile attack logic
## @param result: Base attack result dictionary
## @return: Updated attack result dictionary
func _perform_attack(result: Dictionary) -> Dictionary:
    result.ammo_used = attacker.ammo_system.consume_ammo(weapon_data)
    
    if result.ammo_used <= 0:
        return result
    
    var roll = DiceRoller.roll_2d6()
    var missiles_hit = CLUSTER_TABLE.get(weapon_data.name, []).get(roll - 2, 0)
    result.damage = missiles_hit * weapon_data.damage_per_missile
    
    for i in range(missiles_hit):
        var location = _get_hit_location(target)
        var dmg = weapon_data.damage_per_missile
        _apply_damage_with_crit_check(target, dmg, location)
    
    result.hit = missiles_hit > 0
    return result

#-------------------------------------------------------------
# Private Methods
#-------------------------------------------------------------

## Get hit location on target unit
## @param target: Target unit
## @return: String representing the hit location
func _get_hit_location(target: UnitHandler) -> String:
    # Assuming UnitHandler has a method to get hit location
    return target.component_system.get_hit_location()

## Apply damage to target unit with critical hit check
## @param target: Target unit
## @param damage: Damage amount
## @param location: Hit location
func _apply_damage_with_crit_check(target: UnitHandler, damage: float, location: String) -> void:
    var roll = DiceRoller.roll_2d6()
    var critical = roll >= AttackSystem.CRITICAL_THRESHOLD
    
    # Find the component handler for the hit location
    var component_handler = _get_component_handler(target, location)
    if component_handler:
        component_handler.apply_damage(damage)
        if critical:
            component_handler.apply_damage(damage)  # Double damage for critical hits
            print("Critical hit on %s at %s!" % [target.name, location])
    else:
        print("No component found for location: %s" % location)

## Get component handler for a specific location
## @param target: Target unit
## @param location: Hit location
## @return: ComponentHandler or null if not found
func _get_component_handler(target: UnitHandler, location: String) -> ComponentHandler:
    # Assuming UnitHandler has a method to get the component handler by location
    return target.get_component_handler_by_location(location)