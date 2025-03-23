# AttackSystem.gd
extends Node
class_name AttackSystem

static var instance: AttackSystem

signal attack_resolved(attacker: UnitHandler, target: UnitHandler, result: AttackResult)

const CRITICAL_THRESHOLD = 8
const SIDE_ANGLE = 60  # Degrees for side arc determination



@export var hex_grid : HexGridManager
@export var line_of_sight : LineOfSight 

### CONSTANTS ###
const CRITICAL_DMG_MULTIPLIER = 2.0

### INITIALIZATION ###
func _init() :
 instance= self

func _ready():
    assert(hex_grid != null, "HexGridManager must be assigned")
    assert(line_of_sight != null, "LineOfSight must be assigned")


func resolve_attack(attacker: UnitHandler, target: UnitHandler, weapon: WeaponData) -> void:
    var result = AttackResult.new()
    
    if !_validate_attack(attacker, target, weapon):
        result.valid = false
        attack_resolved.emit(attacker, target, result)
        return

    var handler = _get_attack_handler(weapon)
    result = handler.resolve_attack(attacker, target, weapon)
    
    attack_resolved.emit(attacker, target, result)

func _get_attack_handler(weapon: WeaponData) -> AttackHandler:
    if weapon.attack_pattern==WeaponData.AttackPattern.CLUSTER:
            return ClusterAttackHandler.new(hex_grid, line_of_sight)   
    else:              
            return StandardAttackHandler.new(hex_grid, line_of_sight)

func _validate_attack(attacker: UnitHandler, target: UnitHandler, weapon: WeaponData) -> bool:
    var distance = hex_grid.get_distance(
        attacker.grid_position,
        target.grid_position
    )
    return (
        distance >= weapon.minimum_range &&
        distance <= weapon.maximum_range &&
        line_of_sight.has_clear_path(attacker, target)
    )


