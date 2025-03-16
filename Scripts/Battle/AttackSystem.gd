class_name AttackSystem
extends Node

signal attack_resolved(attacker: Node, target: Node, result: Dictionary)

const CRITICAL_THRESHOLD = 8
const CLUSTER_TABLE = {  }

var _weapon_handlers = {  }
var _range_cache = {}

func resolve_attack(attacker: Node, target: Node, weapon_data: WeaponData) -> void:
    var result = _base_attack_result(weapon_data)
    
    if !_validate_attack(attacker, target, weapon_data):
        attack_resolved.emit(attacker, target, result)
        return
    
    var handler = _weapon_handlers[weapon_data.weapon_type]
    result = await handler.call(attacker, target, weapon_data)
    
    _apply_post_attack_effects(attacker, result)
    attack_resolved.emit(attacker, target, result)

func _validate_attack(attacker, target, weapon) -> bool:
    var distance = HexGridManager.get_hex_distance(attacker, target)
    return (
        attacker.heat_system.can_fire() &&
        attacker.ammo_system.has_ammo(weapon) &&
        LineOfSight.has_clear_path(attacker, target) &&
        distance >= weapon.min_range &&
        distance <= weapon.max_range
    )

func _handle_missile_attack(attacker, target, weapon_data) -> Dictionary:
    var result = _base_attack_result(weapon_data)
    result.ammo_used = attacker.ammo_system.consume_ammo(weapon_data)
    
    if result.ammo_used <= 0: return result
    
    var missiles_hit = CLUSTER_TABLE[weapon_data.name][DiceRoller.roll_2d6()-2]
    result.damage = missiles_hit * weapon_data.damage_per_missile
    
    for missile in missiles_hit:
        var location = ComponentSystem.get_hit_location(target)
        var dmg = weapon_data.damage_per_missile
        _apply_damage_with_crit_check(target, dmg, location)
    
    result.hit = missiles_hit > 0
    return result

func _apply_post_attack_effects(attacker: Node, result: Dictionary) -> void:
    if result.get("heat_generated", 0) > 0:
        attacker.heat_system.check_shutdown()
    
    if result.get("ammo_explosion", false):
        _handle_ammo_explosion(attacker, result.ammo_location)