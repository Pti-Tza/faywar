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

## Current hex position in 2D (q, r) - used for legacy compatibility
var current_hex: Vector2i:
	get:
		return Vector2i(current_hex_3d.x, current_hex_3d.y)
	set(value):
		current_hex_3d = Vector3i(value.x, value.y, current_hex_3d.z)

@export var unit_height: float = 10.0
@export var this_unit_can_brace: bool = true

## Unique identifier system for mission-critical units
@export var unit_id: String = ""  # "enemy_commander_1"
@export var heat_system: HeatSystem
@export var hit_profile: HitProfile

var _cached_controller: BaseController = null
var remaining_mp : int
var max_mp : int # Store the max MP for reference
var can_brace : bool


var can_attack: bool:
	get:
		# Check if unit has any operational weapons with ammo
		for section in sections:
			for handler in section.component_handlers:
				if handler.component_data is WeaponData:
					var weapon = handler.component_data as WeaponData
					# Check if weapon is operational (handler has health > 0) and has ammo if it uses ammo
					var is_operational = handler.is_operational()
					var has_ammo = not weapon.uses_ammo or weapon.current_ammo > 0
					if is_operational and has_ammo:
						return true
		# If no weapons available, return false
		return false

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
	
	# Create or update hit profile based on sections
	if not hit_profile:
		hit_profile = HitProfile.new()
		add_child(hit_profile)
	
	# Generate hit profile from section hit chances
	_generate_hit_profile()
	
	_connect_signals()
	
	# Initialize movement points
	max_mp = walk_mp
	remaining_mp = max_mp

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

func initialize(desired_team, desired_id):
	team = 	desired_team
	unit_id = desired_id

## Replenish movement points at the start of a turn
func start_turn() -> void:
	remaining_mp = max_mp
	can_brace = true

## Deduct movement points after moving
## @param mp_cost: int - Movement points to deduct
## @return bool - True if unit had enough MP, false otherwise
func use_mp(mp_cost: int) -> bool:
	if remaining_mp >= mp_cost:
		remaining_mp -= mp_cost
		return true
	else:
		return false

## Get the remaining movement points
func get_remaining_mp() -> int:
	return remaining_mp

## Get the maximum movement points
func get_max_mp() -> int:
	return max_mp

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

# Generate hit profile from section hit chances
func _generate_hit_profile() -> void:
	if not hit_profile:
		return
	
	# Initialize hit weights for each direction
	var front_hit_weights: Dictionary = {}
	var rear_hit_weights: Dictionary = {}
	var left_hit_weights: Dictionary = {}
	var right_hit_weights: Dictionary = {}
	
	# Collect hit chances from all sections
	for section in sections:
		var section_name = section.section_name if section.section_name != "" else section.name
		
		# Add section's hit chances to each direction
		front_hit_weights[section_name] = section.front_hit_chance
		rear_hit_weights[section_name] = section.rear_hit_chance
		left_hit_weights[section_name] = section.left_hit_chance
		right_hit_weights[section_name] = section.right_hit_chance
	
	# Normalize the weights for each direction
	hit_profile.front_hit_weights = _normalize_weights(front_hit_weights)
	hit_profile.rear_hit_weights = _normalize_weights(rear_hit_weights)
	hit_profile.left_hit_weights = _normalize_weights(left_hit_weights)
	hit_profile.right_hit_weights = _normalize_weights(right_hit_weights)
		
	hit_profile.valid_sections = sections

# Normalize weights so they sum to 1.0 for probability calculations
func _normalize_weights(weights: Dictionary) -> Dictionary:
	var total = 0.0
	for value in weights.values():
		total += value
	
	if total == 0:
		# If all weights are 0, distribute evenly
		var count = weights.size()
		if count == 0:
			return weights
		var equal_weight = 1.0 / count
		var normalized = {}
		for section in weights.keys():
			normalized[section] = equal_weight
		return normalized
	
	var normalized = {}
	for section in weights.keys():
		normalized[section] = weights[section] / total
	
	return normalized

# Get all weapons from all sections
func get_weapons() -> Array[WeaponData]:
	var weapons: Array[WeaponData] = []
	for section in sections:
		for handler in section.component_handlers:
			if handler.component_data is WeaponData:
				weapons.append(handler.component_data)
	return weapons

# Activate bracing for the unit
func activate_brace() -> void:
	# Set can_brace to false to prevent further bracing this turn
	can_brace = false
	# Additional brace logic can be added here
