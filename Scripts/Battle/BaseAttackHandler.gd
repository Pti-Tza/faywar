# BaseAttackHandler.gd
extends Node

class_name BaseAttackHandler

signal attack_resolved(attacker: Node, target: Node, result: Dictionary)

@export var weapon_data: WeaponData
@export var attacker: Node
@export var target: Node

func _init(attacker: Node, target: Node, weapon_data: WeaponData):
    self.attacker = attacker
    self.target = target
    self.weapon_data = weapon_data

func resolve_attack() -> Dictionary:
    var result = _base_attack_result()
    if not _validate_attack():
        return result
    result = _perform_attack(result)
    _apply_post_attack_effects(result)
    return result

func _base_attack_result() -> Dictionary:
    return {
        "hit": false,
        "damage": 0.0,
        "ammo_used": 0,
        "heat_generated": weapon_data.heat_generation,
        "ammo_explosion": false,
        "ammo_location": null
    }

func _validate_attack() -> bool:
    var distance = HexGridManager.get_hex_distance(attacker.current_hex, target.current_hex)
    return (
        attacker.heat_system.can_fire() &&
        attacker.ammo_system.has_ammo(weapon_data) &&
        LineOfSight.has_clear_path(attacker, target) &&
        distance >= weapon_data.min_range &&
        distance <= weapon_data.max_range
    )

func _perform_attack(result: Dictionary) -> Dictionary:
    # Override in derived classes
    return result

func _apply_post_attack_effects(result: Dictionary) -> void:
    if result.get("heat_generated", 0) > 0:
        attacker.heat_system.check_shutdown()
    
    if result.get("ammo_explosion", false):
        _handle_ammo_explosion(result.ammo_location)

func _handle_ammo_explosion(location: String) -> void:
    attacker.heat_system.add_heat(5.0)  # Example heat generation on ammo explosion
    attacker.apply_damage(location, 10.0, true)  # Example damage on ammo explosion

func _apply_damage_with_crit_check(_target: UnitHandler, damage: float, location: String) -> void:
    var roll = DiceRoller.roll_2d6()
    var critical = roll >= AttackSystem.CRITICAL_THRESHOLD
    #_target.apply_damage(location, damage, critical) #criticals not implemented yet
    _target.apply_damage(location, damage)