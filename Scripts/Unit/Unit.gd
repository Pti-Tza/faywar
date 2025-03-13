extends CharacterBody3D
class_name Unit

# Enums
enum UnitType { MECH, VEHICLE, INFANTRY }
enum MovementType { BIPED, QUAD, TRACKED, HOVER }

# Exports
@export var unit_type: UnitType = UnitType.MECH
@export var movement_type: MovementType = MovementType.BIPED
@export var tonnage: int = 55
@export var heat_capacity: int = 30
@export var jump_capable: bool = false

# Systems
@export var weapon_system: WeaponSystem
@export var heat_system: HeatSystem
@export var pilot_system: PilotSystem
@export var ai_system: AISystem

# State
var current_movement_points: int = 0
var is_jumping: bool = false
var is_running: bool = false
var current_heat: int = 0
var is_shut_down: bool = false
var armor: Dictionary = {}
var structure: Dictionary = {}

# Signals
signal damage_received(damage: int, location: String)
signal heat_updated(heat: int)
signal destroyed()
signal shutdown(unit: BattleTechUnit)

func _ready():
    initialize_from_data()
    HeatEventBus.connect("thermal_attack", _on_thermal_attack)

func initialize_from_data() -> void:
    armor = unit_data.armor.duplicate()
    structure = unit_data.structure.duplicate()
    current_movement_points = unit_data.base_movement

func take_damage(damage: int, hit_location: String) -> void:
    if armor.get(hit_location, 0) > 0:
        armor[hit_location] -= damage
        if armor[hit_location] <= 0:
            _apply_structure_damage(hit_location, abs(armor[hit_location]))
    else:
        structure[hit_location] -= damage
    damage_received.emit(damage, hit_location)
    _check_for_destruction()

func _apply_structure_damage(location: String, overflow: int) -> void:
    structure[location] -= overflow
    CriticalHitSystem.roll_critical(self, location)

func _check_for_destruction() -> void:
    for part in structure.values():
        if part <= 0:
            destroy()
            break

func generate_heat(amount: int) -> void:
    current_heat = clamp(current_heat + amount, 0, heat_capacity)
    heat_updated.emit(current_heat)
    if current_heat >= 14:
        _attempt_shutdown()

func _attempt_shutdown() -> void:
    var pilot_skill = pilot_system.get_skill("shutdown_avoidance")
    if DiceRoller.roll_2d6() + pilot_skill < current_heat:
        is_shut_down = true
        shutdown.emit(self)

func start_turn() -> void:
    heat_system.dissipate_heat()
    current_movement_points = unit_data.base_movement

func destroy() -> void:
    destroyed.emit()
    queue_free()

func _on_thermal_attack(attack_data: ThermalAttackData) -> void:
    generate_heat(attack_data.heat_value)