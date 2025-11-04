# HeatSystem.gd
class_name HeatSystem
extends Node

## BattleTech-inspired heat management system with shutdown risks and ammo explosions

# Signals
## Heat level changed - passes new value and delta
signal heat_changed(new_heat: float, delta: float)
## Unit entered overheating state (70%+ max heat)
signal overheating_started()
## Unit reached critical heat (90%+ max heat)
signal critical_heat_reached()
## Unit automatically shut down from heat
signal shutdown_triggered()
## Heat returned below safe thresholds
signal heat_normalized()

# Configuration
## Maximum heat capacity before forced shutdown
@export_range(1.0, 100.0) var max_heat: float = 30.0:
	set(value):
		max_heat = max(value, 0.1)

## Base heat dissipation rate (points/second)
@export var heat_dissipation: float = 2.0

## Overheat threshold percentage (0.0-1.0)
@export_range(0.0, 1.0) var shutdown_threshold: float = 0.7

## Critical heat threshold percentage (0.0-1.0)
@export_range(0.0, 1.0) var critical_threshold: float = 0.9

# Runtime State
## Current heat level (clamped to 0-max_heat)
var current_heat: float = 0.0:
	set(value):
		var previous = current_heat
		current_heat = clamp(value, 0.0, max_heat)
		heat_changed.emit(current_heat, current_heat - previous)
		_check_heat_state(previous)

## True when above shutdown threshold
var is_overheating: bool = false

## True if unit is shutdown from heat
var is_shut_down: bool = false

# Dependencies
## Parent unit (Mech) containing this system
var _parent_unit: Node = null

## Optional coolant system for heat reduction
var _coolant_system: Node = null

func _ready() -> void:
	_acquire_dependencies()
	_connect_external_signals()

func _acquire_dependencies() -> void:
	## Cache required nodes from parent unit
	_parent_unit = get_parent()
	_coolant_system = _parent_unit.get_node_or_null("CoolantSystem")
	
	if not _parent_unit.has_method("roll_piloting_check"):
		push_warning("Parent unit missing piloting check method - shutdowns disabled")

# Public API
func add_heat(amount: float) -> void:
	## Apply heat to the system with coolant mitigation
	var effective_amount = _coolant_system.process_heat_generation(amount) if _coolant_system else amount
	current_heat += effective_amount

func dissipate_heat(delta: float) -> void:
	## Reduce heat over time with optional cooling boosts
	var cooling = heat_dissipation * delta
	cooling += _coolant_system.get_cooling_bonus() * delta if _coolant_system else 0.0
	current_heat = max(current_heat - cooling, 0.0)

func force_shutdown() -> void:
	## Immediately shut down unit and emit signals
	if is_shut_down:
		return
	is_shut_down = true
	shutdown_triggered.emit()

func reset() -> void:
	## Reset system to default state
	current_heat = 0.0
	is_overheating = false
	is_shut_down = false

# Heat State Management
func _check_heat_state(previous_heat: float) -> void:
	## Evaluate heat state changes and trigger consequences
	var was_overheating = previous_heat >= _overheat_threshold()
	is_overheating = current_heat >= _overheat_threshold()
	
	_handle_state_transitions(was_overheating)
	_check_critical_heat()
	_attempt_automatic_shutdown()

func _handle_state_transitions(was_overheating: bool) -> void:
	## Emit signals when entering/leaving overheating state
	if is_overheating != was_overheating:
		if is_overheating:
			overheating_started.emit()
		else:
			heat_normalized.emit()

func _check_critical_heat() -> void:
	## Handle critical heat thresholds and potential explosions
	if current_heat >= _critical_threshold():
		critical_heat_reached.emit()
		_risk_ammo_explosion()

func _attempt_automatic_shutdown() -> void:
	## Roll for automatic shutdown when overheating
	if is_overheating and not is_shut_down and _parent_unit.has_method("roll_piloting_check"):
		var heat_ratio = current_heat / max_heat
		if not _parent_unit.roll_piloting_check("heat_shutdown", heat_ratio):
			force_shutdown()

# BattleTech Mechanics
func _risk_ammo_explosion() -> void:
	## Calculate chance for ammunition explosion per BT rules
	if not _parent_unit.has_method("check_ammo_explosion"):
		return
	
	var explosion_chance = remap(
		current_heat,
		_critical_threshold(),
		max_heat,
		0.3,  # 30% chance at critical threshold
		1.0    # 100% chance at max heat
	)
	
	if randf() < explosion_chance:
		_parent_unit.check_ammo_explosion()

func _overheat_threshold() -> float:
	return max_heat * shutdown_threshold

func _critical_threshold() -> float:
	return max_heat * critical_threshold

# External System Integration
func _connect_external_signals() -> void:
	## Connect to parent unit's activity signals
	# Weapon heat generation
	if _parent_unit.has_signal("weapon_fired"):
		_parent_unit.connect("weapon_fired", _on_weapon_fired)
	else:
		push_warning("Parent unit missing 'weapon_fired' signal - weapon heat disabled")
	
	# Movement heat generation
	if _parent_unit.has_signal("movement_performed"):
		_parent_unit.connect("movement_performed", _on_movement_performed)
	else:
		push_warning("Parent unit missing 'movement_performed' signal - movement heat disabled")

func _on_weapon_fired(weapon_data: WeaponData) -> void:
	## Handle heat from weapon usage
	add_heat(weapon_data.heat_generation)

func _on_movement_performed(move_type: String, distance: float) -> void:
	## Calculate heat from different movement types
	var heat_values = {
		"walk": 0.1,
		"run": 0.3,
		"jump": 1.5
	}
	add_heat(heat_values.get(move_type, 0.0) * distance)
