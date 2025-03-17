# AttackSystem.gd
extends Node

class_name AttackSystem

signal attack_resolved(attacker: Node, target: Node, result: Dictionary)

const CRITICAL_THRESHOLD = 8

var _weapon_handlers = {
    WeaponData.WeaponType.BALLISTIC: BallisticAttackHandler,
    WeaponData.WeaponType.ENERGY: EnergyAttackHandler,
    WeaponData.WeaponType.MISSILE: MissileAttackHandler
}
var _range_cache = {}
@export var hex_grid_manager : HexGridManager
@export var line_of_sight : LineOfSight 

func resolve_attack(attacker: Node, target: Node, weapon_data: WeaponData) -> void:
    var handler_class = _weapon_handlers.get(weapon_data.weapon_type)
    if not handler_class:
        push_error("No handler for weapon type: %s" % weapon_data.weapon_type)
        attack_resolved.emit(attacker, target, {"valid": false, "reason": "No handler for weapon type"})
        return
    
    var handler = handler_class.new(attacker, target, weapon_data)
    var result = handler.resolve_attack()
    attack_resolved.emit(attacker, target, result)

func _validate_attack(attacker: Node, target: Node, weapon_data: WeaponData) -> bool:
    var distance = hex_grid_manager.get_hex_distance(attacker.current_hex, target.current_hex)
    return (
        attacker.heat_system.can_fire() &&
        attacker.ammo_system.has_ammo(weapon_data) &&
        line_of_sight.has_clear_path(attacker, target) &&
        distance >= weapon_data.min_range &&
        distance <= weapon_data.max_range
    )