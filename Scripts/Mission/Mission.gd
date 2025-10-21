# mission_director.gd
extends Node
class_name MissionDirector
## Central mission logic controller
signal objective_updated(objective: MissionObjective)
signal mission_failed(reason: String)
signal mission_completed(victory_type: String)

@export var battle_controller: BattleController  # Changed from MissionScenario
var _active_objectives: Array[MissionObjective] = []
var _unit_loader: UnitManager = null

@export_category("Mission Metadata")
@export var mission_name: String = "Operation Phoenix" 
	# Display name for the mission
@export var mission_id: String = "campaign_1_mission_3" 
	# Unique identifier for tracking and loading
@export var mission_description: String = "Eliminate hostile forces in a strategic engagement." 
	# Brief description for UI display
@export var mission_difficulty: int = 0 
	# 0=Easy, 1=Medium, 2=Hard (for procedural adjustments)

@export_category("Team Configuration")
@export var team_relationships := {
	# Team 0 (Player)
	0: {
		allies = [3],  # Team 3 is ally
		enemies = [1, 2]  # Teams 1 and 2 are hostile
	},
	# Team 1 (Enemy)
	1: {
		allies = [2],
		enemies = [0, 3]
	}
}

### Objective Configuration ###
@export_category("Mission Objectives")
@export var objectives: Array[MissionObjective] = []



func _ready():
	if !battle_controller:
		battle_controller = BattleController.instance
	_initialize_objectives()
	if battle_controller:  # Ensure reference is valid
		battle_controller.combat_started.connect(_on_combat_started)

func _initialize_objectives():
	for objective in objectives:
		objective.status = MissionObjective.Status.PENDING
		_active_objectives.append(objective)

func _on_combat_started():
	_start_primary_objectives()

func _process(delta):
	_check_failure_conditions()
	_update_objectives()

func _start_primary_objectives():
	for objective in objectives:
		objective.start()

func _check_failure_conditions():
	for condition in objectives:
		if condition.check_condition():
			mission_failed.emit(condition.failure_message)
			break

func _update_objectives():
	for objective in _active_objectives:
		if objective.check_completion():
			objective.status = MissionObjective.Status.COMPLETED
			objective_updated.emit(objective)
			_check_victory()

func _check_victory():
	if objectives.all(func(obj): return obj.status == MissionObjective.Status.COMPLETED):
		mission_completed.emit("DECISIVE_VICTORY")

func initialize_mission(unit_loader: UnitManager):
	_unit_loader = unit_loader
	for objective in _active_objectives:
		if objective.objective_type == MissionObjective.Type.PRIMARY:
			objective.connect_to_unit_loader(unit_loader)
	_check_pre_spawned_units()

func _check_pre_spawned_units():
	for unit in _unit_loader.get_all_units():
		for objective in _active_objectives:
			if objective.objective_type == MissionObjective.Type.PRIMARY:
				objective._on_unit_spawned(unit)
