# AttackSystem.gd
extends Node
class_name AttackSystem

static var instance: AttackSystem

signal attack_resolved(attacker: Unit, target: Unit, result: AttackResult)

@export var hex_grid: HexGridManager
@export var line_of_sight: LineOfSight

# Pre-instantiated, reusable handlers
var _standard_handler: StandardAttackHandler
var _cluster_handler: ClusterAttackHandler

func _init():
	instance = self

func _ready():
	assert(hex_grid != null, "HexGridManager must be assigned")
	assert(line_of_sight != null, "LineOfSight must be assigned")
	
	# Initialize handlers once
	_standard_handler = StandardAttackHandler.new(hex_grid, line_of_sight)
	_cluster_handler = ClusterAttackHandler.new(hex_grid, line_of_sight)

func resolve_attack(attacker: Unit, target: Unit, weapon: WeaponData) -> void:
	var result = AttackResult.new()
	
	if !_validate_attack(attacker, target, weapon):
		result.valid = false
		attack_resolved.emit(attacker, target, result)
		return

	var handler = _get_attack_handler(weapon)
	result = handler.resolve_attack(attacker, target, weapon)
	
	attack_resolved.emit(attacker, target, result)

func _get_attack_handler(weapon: WeaponData) -> AttackHandler:
	match weapon.attack_pattern:
		WeaponData.AttackPattern.CLUSTER:
			return _cluster_handler
		_:
			return _standard_handler

func _validate_attack(attacker: Unit, target: Unit, weapon: WeaponData) -> bool:
	var distance = hex_grid.get_distance(
		attacker.grid_position,
		target.grid_position
	)
	return (
		distance >= weapon.minimum_range &&
		distance <= weapon.maximum_range &&
		line_of_sight.has_clear_path(attacker, target)
	)
