# ClusterAttackHandler.gd
extends AttackHandler
class_name ClusterAttackHandler

const CLUSTER_TABLES = {
    "SRM": [0,0,1,2,2,3,3,4,4,5,5],    # Index 0-10 (rolls 2-12)
    "LRM": [0,0,1,2,2,3,3,4,4,5,6],    # Index 0-10 (rolls 2-12)
    "ATM": [0,1,2,3,3,4,4,5,5,6,6]     # Example custom weapon
}

func resolve_attack(attacker: UnitHandler, target: UnitHandler, weapon: WeaponData) -> AttackResult:
    var result = AttackResult.new()
    result.valid = true
    
    # Get base attack angle and location
    var attack_angle = calculate_attack_angle(attacker, target)
    var base_location = determine_hit_location(target, attack_angle)
    
    # Calculate number of clusters hitting
    var cluster_roll = DiceRoller.roll_2d6()
    var hit_count = _get_hits_from_table(cluster_roll, weapon)
    
    # Generate individual cluster hits
    for i in hit_count:
        var hit = HitData.new()
        hit.angle = attack_angle
        hit.location = _get_cluster_location(base_location, weapon.cluster_spread)
        hit.damage = weapon.damage
        hit.critical = check_critical_hit(weapon.base_critical_chance, weapon)
        hit.penetrated = _check_penetration(target, hit.location, hit.damage)
        
        result.hits.append(hit)
        result.total_damage += hit.damage
        
        if hit.critical:
            result.critical_hits += 1

    # Set resource consumption (Battletech rules)
    result.heat_generated = weapon.heat_generation  # Heat per volley
    result.ammo_used = 1 if weapon.uses_ammo else 0 # One ammo per attack
    
    return result

func _get_hits_from_table(roll: int, weapon: WeaponData) -> int:
    var table = CLUSTER_TABLES.get(weapon.weapon_class, [])
    var index = clamp(roll - 2, 0, table.size() - 1)
    return min(table[index], weapon.cluster_size)

func _get_cluster_location(base_location: String, spread: float) -> String:
    if spread == 0.0 || randf() > spread:
        return base_location
    
    var adjacent_locations = _get_adjacent_locations(base_location)
    if adjacent_locations.size() > 0:
        return adjacent_locations[randi() % adjacent_locations.size()]
    return base_location

func _get_adjacent_locations(location: String) -> Array:
    match location:
        "ctorso": return ["ltorso", "rtorso", "head"]
        "ltorso": return ["ctorso", "larm", "lleg"]
        "rtorso": return ["ctorso", "rarm", "rleg"]
        "larm": return ["ltorso", "lleg"]
        "rarm": return ["rtorso", "rleg"]
        "lleg": return ["ltorso", "larm"]
        "rleg": return ["rtorso", "rarm"]
        "head": return ["ctorso"]
        _: return []