extends AttackHandler
class_name StandardAttackHandler

func _init(grid: HexGridManager, los: LineOfSight):
	hex_grid = grid
	line_of_sight = los

func resolve_attack(attacker: Unit, target: Unit, weapon: WeaponData) -> AttackResult:
	var result = AttackResult.new()
	result.valid = true
	
	# Calculate base hit chance components
	var base_to_hit = _calculate_base_to_hit(attacker, target, weapon)
	var final_target_number = _apply_modifiers(base_to_hit, attacker, target, weapon)
	
	# Roll 2D6 with BattleTech-style success check
	var dice_roll = DiceRoller.roll_2d6()
	if dice_roll < final_target_number:
		result.valid = false
		return result
	
	# Successful hit - process damage
	var hit_data = _process_hit(attacker, target, weapon, dice_roll)
	result.hits.append(hit_data)
	result.total_damage = hit_data.damage
	result.heat_generated = weapon.heat_generation
	result.ammo_used = 1 if weapon.uses_ammo else 0
	
	# Critical hit check on natural 12
	if dice_roll == 12:
		result.critical_hits += 1
		hit_data.critical = true
	
	return result

func _calculate_base_to_hit(attacker: Unit, target: Unit, weapon: WeaponData) -> int:
	var base = 4  # Base TN in BattleTech
	base += attacker.pilot.get_gunnery_skill()
	base += _get_range_modifier(attacker, target, weapon)
	base += target.get_movement_modifier()
	base += line_of_sight.get_cover_modifier(target)
	return base

func _get_range_modifier(attacker: Unit, target: Unit, weapon: WeaponData) -> int:
	var distance = hex_grid.get_distance(
		attacker.grid_position,
		target.grid_position
	)
	
	if distance <= weapon.minimum_range:
		return 999  # Should be caught earlier by validate_attack
	elif distance < weapon.optimal_range:
		return -1  # Short range bonus
	elif distance <= weapon.maximum_range:
		return int((distance - weapon.optimal_range) * 0.5)
	else:
		return 999  # Should be caught by validate_attack

func _apply_modifiers(base_tn: int, attacker: Unit, target: Unit, weapon: WeaponData) -> int:
	var modified_tn = base_tn
	modified_tn += attacker.get_heat_penalty()
	modified_tn -= weapon.accuracy_bonus
	modified_tn += target.get_ecm_penalty()
	return max(modified_tn, 2)  # Minimum TN of 2

func _process_hit(attacker: Unit, target: Unit, weapon: WeaponData, dice_roll: int) -> HitData:
	var hit = HitData.new()
	
	# Calculate hit location
	var attack_angle = _get_attack_angle(attacker, target)
	hit.location = target.get_hit_location(attack_angle)
	hit.angle = attack_angle
	
	# Calculate damage with potential called shot
	hit.damage = weapon.damage
	hit.penetrated = _check_armor_penetration(target, hit.location, hit.damage)
	
	# Special case for through-armor criticals
	if dice_roll == 12 && hit.penetrated:
		hit.critical = true
	
	return hit

func _get_attack_angle(attacker: Unit, target: Unit) -> float:
	var attacker_pos = hex_grid.get_world_position(attacker.grid_position)
	var target_pos = hex_grid.get_world_position(target.grid_position)
	var direction_vector = (attacker_pos - target_pos).normalized()
	return rad_to_deg(direction_vector.angle_to(target.facing_direction))

func _check_armor_penetration(target: Unit, location: String, damage: float) -> bool:
	var armor = target.get_armor(location)
	var structure = target.get_structure(location)
	return damage > armor || (structure > 0 && armor == 0)
