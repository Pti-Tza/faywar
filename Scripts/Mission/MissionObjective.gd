extends Node
class_name MissionObjective

### Enums ###
enum Status { PENDING, ACTIVE, COMPLETED, FAILED }
enum Type { PRIMARY, SECONDARY }

### Exported Properties ###
@export var status : Status
@export var objective_type: Type = Type.PRIMARY
@export var title: String = "Destroy Target"
@export var description: String = "Eliminate enemy command unit"
@export var target_unit_ids: Array[String] = []
@export var success_events: Array[MissionEvent] = []
@export var failure_events: Array[MissionEvent] = []



### Internal State ###
var _tracked_units: Array[Unit] = []
var _unit_loader: UnitManager = null  # Reference to UnitLoader
var progress: float = 0.0

### Signals ###
signal progress_updated(objective: MissionObjective)

### Public API ###
func start() -> void:
	status = Status.ACTIVE
	if _unit_loader:
		_check_pre_spawned_units()  # Check existing units first
		_unit_loader.unit_spawned.connect(_on_unit_spawned)
		_unit_loader.unit_destroyed.connect(_on_unit_destroyed)
	else:
		push_warning("MissionObjective: UnitManager not initialized")

func connect_to_unit_loader(unit_loader: UnitManager) -> void:
	_unit_loader = unit_loader
	_unit_loader.unit_spawned.connect(_on_unit_spawned)
	_unit_loader.unit_destroyed.connect(_on_unit_destroyed)

func check_completion() -> bool:
	# Must be implemented by subclasses
	return false

### Private Methods ###
func _check_pre_spawned_units() -> void:
	if not _unit_loader:
		push_warning("MissionObjective: UnitManager not initialized")
		return

	# Check all existing units and track if they match target IDs
	for unit in _unit_loader.active_units:
		if unit.identity.unit_id in target_unit_ids:
			_tracked_units.append(unit)

	_update_progress()  # Update initial progress

func _on_unit_spawned(unit: Unit) -> void:
	if unit.identity.unit_id in target_unit_ids:
		_tracked_units.append(unit)
		_update_progress()

func _on_unit_destroyed(unit: Unit) -> void:
	if _tracked_units.has(unit):
		_tracked_units.erase(unit)
		_update_progress()

func _update_progress() -> void:
	if target_unit_ids.size() == 0:
		progress = 1.0
	else:
		progress = 1.0 - (_tracked_units.size() / target_unit_ids.size())

	if progress >= 1.0:
		status = Status.COMPLETED
		trigger_success_events()
	elif progress <= 0.0:
		status = Status.FAILED
		trigger_failure_events()

	progress_updated.emit(self)

### Event Triggers ###
func trigger_success_events() -> void:
	for event in success_events:
		event.execute()

func trigger_failure_events() -> void:
	for event in failure_events:
		event.execute()
