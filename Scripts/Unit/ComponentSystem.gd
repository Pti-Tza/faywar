class_name ComponentSystem
extends Node

# Removed BattleTech-specific enums
signal component_damaged(unit: Node, location: StringName, component: StringName, damage: int)
signal critical_failure(unit: Node, location: StringName, effect: String)

@export var unit_profile: UnitProfile # Contains type-specific config

var _structure := {}
var _components := {}

# Dictionary of component_type: max_health
var _component_health := {}

func _ready() -> void:
    assert(unit_profile != null, "UnitProfile must be assigned")
    _initialize_from_profile()

func initialize_custom_profile(profile: UnitProfile) -> void:
    unit_profile = profile
    _initialize_from_profile()

func apply_damage(damage: int, damage_type: StringName, location: StringName) -> void:
    var remaining = _apply_armor_damage(location, damage, damage_type)
    remaining = _apply_structure_damage(location, remaining)
    _check_critical_effects(location, remaining)

#region Core Systems
func _initialize_from_profile() -> void:
    _structure.clear()
    _components.clear()
    
    # Load structure from profile
    for section in unit_profile.structure_sections:
        _structure[section.name] = {
            "armor": section.armor,
            "structure": section.structure,
            "components": section.components.duplicate()
        }
    
    # Initialize component health
    for component in unit_profile.components:
        _component_health[component.id] = component.durability

func _apply_armor_damage(location: StringName, damage: int, damage_type: StringName) -> int:
    if !_structure.has(location): return 0
    
    var armor = _structure[location].armor
    var dmg_mod = unit_profile.get_damage_modifier(damage_type)
    var effective_dmg = damage * dmg_mod
    
    _structure[location].armor = max(armor - effective_dmg, 0)
    component_damaged.emit(get_parent(), location, "", effective_dmg)
    
    return max(damage - effective_dmg, 0)

func _apply_structure_damage(location: StringName, damage: int) -> int:
    if !_structure.has(location): return 0
    
    var remaining_structure = _structure[location].structure
    var effective_dmg = min(damage, remaining_structure)
    
    _structure[location].structure = remaining_structure - effective_dmg
    component_damaged.emit(get_parent(), location, "", effective_dmg)
    
    if _structure[location].structure <= 0:
        _trigger_section_destruction(location)
    
    return damage - effective_dmg

func _check_critical_effects(location: StringName, severity: int) -> void:
    var crit_chance = unit_profile.get_critical_chance(location, severity)
    if DiceRoller.roll_percent() <= crit_chance:
        _resolve_critical(location)

func _resolve_critical(location: StringName) -> void:
    var component = _get_random_component(location)
    if !component: return
    
    _component_health[component] -= 1
    if _component_health[component] <= 0:
        _handle_component_failure(component)

func _handle_component_failure(component_id: StringName) -> void:
    var component = unit_profile.get_component(component_id)
    critical_failure.emit(get_parent(), component.location, component.failure_effect)
    
    # Execute component-specific behavior
    if component.has_method("on_destroyed"):
        component.on_destroyed.call(get_parent())
    else:
        _default_failure_behavior(component)

func _default_failure_behavior(component: UnitComponent) -> void:
    match component.failure_type:
        "ammo_explosion":
            _trigger_ammo_explosion(component)
        "system_failure":
            get_parent().apply_status(component.status_effect)
        "movement_impairment":
            get_parent().movement_system.apply_penalty(component.penalty_value)
#endregion

#region Query Methods
func get_armor(location: StringName) -> int:
    return _structure.get(location, {}).get("armor", 0)

func get_structure(location: StringName) -> int:
    return _structure.get(location, {}).get("structure", 0)

func get_component_health(component_id: StringName) -> int:
    return _component_health.get(component_id, -1)

func is_operational(component_id: StringName) -> bool:
    return get_component_health(component_id) > 0
#endregion

#region Helper Methods
func _get_random_component(location: StringName) -> StringName:
    var candidates = _structure[location].components.filter(
        func(c): return is_operational(c)
    )
    return candidates[randi() % candidates.size()] if candidates else &""

func _trigger_section_destruction(location: StringName) -> void:
    for component in _structure[location].components:
        _component_health[component] = 0
        _handle_component_failure(component)

func _trigger_ammo_explosion(component: UnitComponent) -> void:
    var explosion_data = component.explosion_data
    HexGridManager.apply_area_damage(
        get_parent().grid_position,
        explosion_data.damage,
        explosion_data.radius,
        explosion_data.damage_type
    )
#endregion