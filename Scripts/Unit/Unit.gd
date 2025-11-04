extends Node3D
class_name Unit

## Emitted when any section takes damage
signal unit_damaged(section: UnitSection, damage: float)
## Emitted when unit is destroyed
signal unit_destroyed(unit: Unit)
## Emitted when heat level changes
signal heat_changed(new_value: float)

enum MobilityType {
	BIPEDAL,    # Humanoid mechs/units
	WHEELED,    # Wheeled vehicles
	HOVER,      # Hovercraft/floating units
	TRACKED,    # Tank-like units
	AERIAL      # Flying units (limited)
}

## Unit definition with static properties
@export var unit_name: String = "Unnamed Unit"
@export var classification: String = "classification"
var sections: Array[UnitSection] = []
@export var mobility_type: MobilityType = MobilityType.BIPEDAL
@export var max_elevation_change: int = 2

@export var icon: Texture2D

@export var walk_mp: int = 4
@export var run_mp_bonus: int = 2
@export var jump_mp: int = 0

@export var team: int = 0
@export var initiative: float = 1.0
@export var agility: float = 1.0

## Current hex position in 3D (q, r, level)
@export var current_hex_3d: Vector3i = Vector3i(0, 0, 0)

@export var unit_height: float = 10.0

## Unique identifier system for mission-critical units
@export var unit_id: String = ""  # "enemy_commander_1"
@export var heat_system: HeatSystem
@export var hit_profile: Resource

var _cached_controller: BaseController = null

var controller: BaseController:
	get:
		if _cached_controller == null:
			var controllers = BattleController.instance.controllers
			for ctrl in controllers:
				if ctrl is BaseController and ctrl.team_index == team:
					_cached_controller = ctrl
					break
		return _cached_controller
	set(value):
		if value and value is BaseController:
			team = value.team_index
			_cached_controller = value
		else:
			push_warning("Attempted to set controller to invalid value: ", value)
			_cached_controller = null
			


# Initialize unit when added to scene tree
func _ready():
	sections.clear()
	for child in get_children():
		if child is UnitSection:
			sections.append(child)
			for component in child.component_handlers:
				component.component_destroyed.connect(_on_component_destroyed.bind(component.component_data))
	
	_connect_signals()

## Gets the current hex cell the unit is occupying
func get_current_hex_cell() -> HexCell:
	var hex_grid = HexGridManager.instance
	if hex_grid:
		return hex_grid.get_cell_3d(current_hex_3d.x, current_hex_3d.y, current_hex_3d.z)
	return null

## Sets the unit's hex position in 3D space
func set_hex_position_3d(q: int, r: int, level: int) -> bool:
	var hex_grid = HexGridManager.instance
	if not hex_grid:
		push_error("No HexGridManager instance found")
		return false
	
	var target_cell = hex_grid.get_cell_3d(q, r, level)
	if not target_cell:
		push_error("No hex cell at coordinates (%d, %d, %d)" % [q, r, level])
		return false
	
	if target_cell.unit and target_cell.unit != self:
		push_error("Target hex is already occupied")
		return false
	
	# Remove from old position
	var old_cell = get_current_hex_cell()
	if old_cell:
		old_cell.unit = null
	
	# Update position
	current_hex_3d = Vector3i(q, r, level)
	
	# Place in new position
	target_cell.unit = self
	
	# Update world position
	var world_pos = hex_grid.axial_to_world_3d(q, r, level)
	global_position = world_pos
	
	return true
	sections.clear()
	for child in get_children():
		if child is UnitSection:
			sections.append(child)
			for component in child.component_handlers:
				component.component_destroyed.connect(_on_component_destroyed.bind(component.component_data)) 
	
	_connect_signals()

func initialize(desired_team, desired_id):
	team = 	desired_team
	unit_id = desired_id

## Public method to damage specific section
## @param section_name: String - Name of section to damage
## @param damage: float - Amount of damage to apply
func apply_damage(section: UnitSection, damage: float) -> void:
	
	section.apply_damage(damage)
	unit_damaged.emit(section, damage)

## Public method to apply heat to the unit
## @param heat: float - Amount of heat to add
func apply_heat(heat: float) -> void:
	heat_system.add_heat(heat)
	

# Connect section destruction signals
func _connect_signals() -> void:
	for handler in sections:
		handler.section_destroyed.connect(_on_section_destroyed)

# Find section handler by name
func _get_section_by_name(section_name: String) -> UnitSection:
	return sections.filter(func(u): return u.name == section_name)[0]

# Handle section destruction event
func _on_section_destroyed(_section : UnitSection) -> void:
	#if _check_critical_destruction():
	if _section.section_data.critical == true :
		unit_destroyed.emit(self)
		queue_free()

func _on_component_destroyed(comp_ : ComponentHandler) -> void:
	if comp_.component_data.is_critical:        
		# Instant destruction
		unit_destroyed.emit()

func get_total_armor() -> int:
	return sections.reduce(func(acc, s): return acc + s.current_armor, 0)

func get_total_structure() -> int:
	return sections.reduce(func(acc, s): return acc + s.current_structure, 0) 

func get_total_max_armor() -> int:
	return sections.reduce(func(acc, s): return acc + s.max_armor, 0)

func get_total_max_structure() -> int:
	return sections.reduce(func(acc, s): return acc + s.max_structure, 0) 	
	       

## Returns the total armor for a specific section
func get_section_armor(section: String) -> int:
	for sec in sections:
		if sec.name == section:
			return sec.armor
	push_error("Section not found: ", section)
	return 0

## Returns the total structure for a specific section
func get_section_structure(section: String) -> int:
	for sec in sections:
		if sec.name == section:
			return sec.structure
	push_error("Section not found: ", section)
	return 0

## Get hit profile based on attack angle
func get_hit_profile(attack_angle: float) -> Dictionary:
	if hit_profile and hit_profile.has_method("get_hit_weights_for_angle"):
		return hit_profile.get_hit_weights_for_angle(attack_angle)
	else:
		# Default hit profile if none is set - assumes standard sections exist
		return {"Front": 25, "Rear": 25, "Left": 25, "Right": 25}
