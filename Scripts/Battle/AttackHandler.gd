# AttackHandler.gd
class_name AttackHandler
extends RefCounted

# Shared dependencies
var hex_grid: HexGridManager
var line_of_sight: LineOfSight

# Base initialization with required systems
func _init(grid: HexGridManager, los: LineOfSight):
	hex_grid = grid
	line_of_sight = los

# Main method to be overridden by child classes
func resolve_attack(attacker: Unit, target: Unit, weapon: WeaponData) -> AttackResult:
	push_error("resolve_attack() not implemented in base AttackHandler")
	return AttackResult.new()

# region Core Calculation Methods -------------------------------------------------

func calculate_attack_angle(attacker: Unit, target: Unit) -> float:
	var attacker_pos = hex_grid.get_world_position(attacker.grid_position)
	var target_pos = hex_grid.get_world_position(target.grid_position)
	var attack_vector = (attacker_pos - target_pos).normalized()
	var target_forward = target.get_global_transform().basis.z.normalized()
	
	var relative_angle = rad_to_deg(attack_vector.signed_angle_to(
		target_forward, 
		Vector3.UP
	))
	return fposmod(relative_angle + 180, 360) - 180  # Normalize to -180..180

func determine_hit_location(target: Unit, attack_angle: float) -> String:
	var facing = _get_relative_facing(attack_angle)
	var profile = target.hit_profile.get_hit_profile(attack_angle)
	return _roll_hit_location(profile)


func check_critical_hit(base_chance: float, weapon: WeaponData) -> bool:
	var critical_threshold = weapon.critical_threshold
	var roll = DiceRoller.roll_2d6()
	return roll >= (critical_threshold - weapon.critical_hit_bonus)

# endregion

# region Helper Methods ----------------------------------------------------------

func _get_relative_facing(angle: float) -> String:
	var abs_angle = abs(angle)
	if abs_angle > 150: return "rear"
	if abs_angle > 90: return "side"
	return "front"

func _roll_hit_location(profile: Dictionary) -> String:
	var roll = randf()
	var cumulative = 0.0
	
	for location in profile:
		cumulative += profile[location]
		if roll <= cumulative:
			return location
	
	push_warning("Hit location roll failed, defaulting to CTorso")
	return "ctorso"

func _check_penetration(target: Unit, location: String, damage: float) -> bool:
	var armor = target.get_armor(location)
	var structure = target.get_structure(location)
	return damage > armor || (structure > 0 && armor == 0)

# endregion
