# pilot_system.gd
extends Node
class_name PilotSystem


## Emitted when pilot takes damage
signal pilot_injured(damage: int, new_health: int)
## Emitted when skill changes
signal skill_changed(skill_type: String, new_value: float)
## Emitted when pilot status changes
signal status_changed(new_status: String)
## Emitted for important check results
signal skill_check_result(skill_type: String, success: bool, margin: int)

enum PilotStatus {HEALTHY, INJURED, UNCONSCIOUS, DEAD}

# Core pilot properties
@export var pilot_name: String = "MechWarrior"
@export var health: int = 3:
    set(value):
        health = clamp(value, 0, max_health)
        if health <= 0:
            _set_status(PilotStatus.DEAD)
@export var max_health: int = 3
@export var gunnery: float = 4.0:  # Lower is better
    set(value):
        gunnery = clamp(value, 0.1, 6.0)
        skill_changed.emit("gunnery", gunnery)
@export var piloting: float = 5.0:  # Lower is better
    set(value):
        piloting = clamp(value, 0.1, 6.0)
        skill_changed.emit("piloting", piloting)

# Specialization properties
@export var specialties: Array[String] = ["energy_weapons"]
@export var injuries: Array[String] = []
@export var status: PilotStatus = PilotStatus.HEALTHY:
    set(value):
        status = value
        status_changed.emit(PilotStatus.keys()[status])

# Internal state
var _rng = RandomNumberGenerator.new()
var _parent_unit: Node = null

func _ready() -> void:
    _parent_unit = get_parent()
    _rng.randomize()
    _connect_external_signals()

# Public API ----------------------------------------------------------------

## Execute a skill check with optional modifiers
func roll_skill_check(skill_type: String, modifiers: float = 0.0) -> Dictionary:
    var base_skill = get(skill_type)
    var effective_skill = base_skill + _calculate_injury_penalty() + modifiers
    var roll = _roll_2d6()
    var success = roll >= effective_skill
    var margin = abs(roll - effective_skill)
    
    skill_check_result.emit(skill_type, success, margin)
    return {
        "success": success,
        "roll": roll,
        "target": effective_skill,
        "margin": margin
    }

## Apply damage to pilot
func take_damage(damage: int) -> void:
    health -= damage
    pilot_injured.emit(damage, health)
    
    if health <= 0:
        _set_status(PilotStatus.DEAD)
    elif health <= max_health / 2:
        _set_status(PilotStatus.INJURED)

## Add permanent injury
func add_injury(injury_type: String) -> void:
    if not injuries.has(injury_type):
        injuries.append(injury_type)
        _apply_injury_effects(injury_type)

# Core Logic ----------------------------------------------------------------

func _calculate_injury_penalty() -> float:
    var penalty = 0.0
    for injury in injuries:
        match injury:
            "concussion": penalty += 1.0
            "broken_arm": penalty += 0.5
            "burn_wounds": penalty += 0.7
    return penalty

func _apply_injury_effects(injury_type: String) -> void:
    match injury_type:
        "concussion":
            gunnery += 1.0
            piloting += 1.0
        "broken_arm":
            gunnery += 0.5
        "burn_wounds":
            piloting += 0.7

func _set_status(new_status: PilotStatus) -> void:
    if status != new_status:
        status = new_status
        status_changed.emit(PilotStatus.keys()[new_status])
        if new_status == PilotStatus.DEAD:
            _handle_pilot_death()

func _handle_pilot_death() -> void:
    if _parent_unit.has_method("trigger_destruction"):
        _parent_unit.trigger_destruction("pilot_killed")

# Skill Check Helpers -------------------------------------------------------

func _roll_2d6() -> int:
    return _rng.randi_range(1, 6) + _rng.randi_range(1, 6)

# Signal Connections --------------------------------------------------------

func _connect_external_signals() -> void:
    # Automatic connection to common systems
    if _parent_unit.has_signal("unit_damaged"):
        _parent_unit.connect("unit_damaged", _on_unit_damaged)
    
    if _parent_unit.has_signal("heat_warning"):
        _parent_unit.connect("heat_warning", _on_heat_warning)

func _on_unit_damaged(severity: int) -> void:
    # Chance to take damage from critical hits
    if _rng.randf() < severity * 0.15:
        take_damage(1)

func _on_heat_warning(heat_level: float) -> void:
    # Chance to take heat-related injuries
    if heat_level > 0.8 and _rng.randf() < 0.3:
        add_injury("burn_wounds")