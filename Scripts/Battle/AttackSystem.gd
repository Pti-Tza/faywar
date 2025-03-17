# AttackSystem.gd
extends Node

class_name AttackSystem

signal attack_resolved(attacker: UnitHandler, target: UnitHandler, result: AttackResult)

const CRITICAL_THRESHOLD = 8

var _weapon_handlers = {
    WeaponData.WeaponType.BALLISTIC: BallisticAttackHandler,
    WeaponData.WeaponType.ENERGY: EnergyAttackHandler,
    WeaponData.WeaponType.MISSILE: MissileAttackHandler
}

@export var hex_grid_manager : HexGridManager
@export var line_of_sight : LineOfSight 



func resolve_attack(attacker: UnitHandler, target: UnitHandler, weapon_data: WeaponData) -> void:
    var handler_class = _weapon_handlers.get(weapon_data.weapon_type)
    if not handler_class:
        push_error("No handler for weapon type: %s" % weapon_data.weapon_type)
        attack_resolved.emit(attacker, target, {"valid": false, "reason": "No handler for weapon type"})
        return
    
    var handler = handler_class.new(attacker, target, weapon_data)
    var result = handler.resolve_attack()
    attack_resolved.emit(attacker, target, result)

func _validate_attack(attacker: UnitHandler, target: UnitHandler, weapon_data: WeaponData) -> bool:
    var distance = hex_grid_manager.get_hex_distance(attacker.current_hex, target.current_hex)
    return (
        attacker.heat_system.can_fire() &&
        attacker.ammo_system.has_ammo(weapon_data) &&
        LineOfSight.has_clear_path(attacker, target) &&
        distance >= weapon_data.min_range &&
        distance <= weapon_data.max_range
    )



### AttackResult Struct ###
class  AttackResult:
    var hit: bool = false
    var damage: float = 0.0
    var ammo_used: int = 0
    var heat_generated: float = 0.0
    var ammo_explosion: bool = false
    var ammo_location: String = ""
    var critical_hit: bool = false
   

### CONSTANTS ###
const CRITICAL_DMG_MULTIPLIER = 2.0

### INITIALIZATION ###
func _init(
    attacker: UnitHandler,
    target: UnitHandler,
    weapon_data: WeaponData,
    hex_grid: HexGridManager,
    line_of_sight: LineOfSight
):
    self.attacker = attacker
    self.target = target
    self.weapon_data = weapon_data
    self.hex_grid = hex_grid
    self.line_of_sight = line_of_sight

func _ready():
    assert(hex_grid != null, "HexGridManager must be assigned")
    assert(line_of_sight != null, "LineOfSight must be assigned")



### PRIVATE METHODS ###
### 1. Initialization ###


### 2. Validation ###
func _is_attack_valid() -> bool:
    var distance = hex_grid.get_hex_distance(attacker.current_hex, target.current_hex)
    
    return (
        attacker.can_fire() and
        attacker.has_ammo(weapon_data) and
        line_of_sight.is_path_clear(attacker, target) and
        distance >= weapon_data.effective_range.x and
        distance <= weapon_data.effective_range.y
    )

func _calculate_hit_chance() -> float:
    var base_chance = weapon_data.base_accuracy
    var distance_penalty = _get_range_penalty()  # e.g., 0.1 per hex beyond optimal range
    var evasion_penalty = target.get_evasion()   # e.g., 0.2 for agile targets
    return max(base_chance - distance_penalty - evasion_penalty, 0.0)

func _get_range_penalty() -> float:
    var distance = hex_grid.get_hex_distance(attacker.current_hex, target.current_hex)
    if distance > weapon_data.effective_range.y:
        return 0.3  # Heavy penalty beyond max range
    elif distance < weapon_data.effective_range.x:
        return -0.1  # Bonus for optimal range
    return 0.0        

### 3. Attack Execution ###
func _perform_attack(result: AttackResult) -> AttackResult:
    # Override in derived classes
    var damage = _calculate_damage()
    var critical = _is_critical_hit()
    
    result.damage = damage
    result.critical_hit = critical
    result.hit = true
    
    return result

func _calculate_damage() -> float:
    var base_damage = weapon_data.damage
    var critical_multiplier = _is_critical_hit() if CRITICAL_DMG_MULTIPLIER else 1.0
    return base_damage * critical_multiplier

func _is_critical_hit() -> bool:
    var roll = DiceRoller.roll_2d6()
    return roll >= weapon_data.critical_threshold

### 4. Post-Effects ###
func _process_post_attack_effects(result: AttackResult):
    _apply_heat(result[HEAT_GENERATED])
    _handle_ammo_explosion(result)
    _update_ammo(result[AMMO_USED])

func _apply_heat(heat: float):
    attacker.add_heat(heat)
    attacker.check_shutdown()

func _handle_ammo_explosion(result: AttackResult):
    if not result[AMMO_EXPLOSION]:
        return
    
    var explosion_damage = weapon_data.ammo_explosion_damage
    var heat_penalty = weapon_data.ammo_heat_penalty
    
    attacker.apply_damage(result[AMMO_LOCATION], explosion_damage, true)
    attacker.add_heat(heat_penalty)

func _update_ammo(ammo_used: int):
    attacker.use_ammo(weapon_data, ammo_used)

### 5. Signaling ###
func _emit_attack_resolved(result: AttackResult):
    emit_signal("attack_resolved", attacker, target, result)