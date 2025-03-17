# EnergyAttackHandler.gd
extends BaseAttackHandler

class_name EnergyAttackHandler

func _perform_attack(result: Dictionary) -> Dictionary:
    var roll = DiceRoller.roll_2d6()
    var success = roll >= weapon_data.base_accuracy * 6
    if success:
        result.hit = true
        result.damage = weapon_data.damage
        var location = ComponentSystem.get_hit_location(target)
        _apply_damage_with_crit_check(target, result.damage, location)
    return result