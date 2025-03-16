# mission_director.gd
extends Node
class_name MissionDirector
## Central mission logic controller
signal objective_updated(objective: MissionObjective)
signal mission_failed(reason: String)
signal mission_completed(victory_type: String)

@export var scenario: MissionScenario
@export var battle_controller: BattleController  # Changed from MissionScenario
var _active_objectives: Array[MissionObjective] = []
var _unit_loader: UnitManager = null

func _ready():
    _initialize_objectives()
    if battle_controller:  # Ensure reference is valid
        battle_controller.combat_started.connect(_on_combat_started)

func _initialize_objectives():
    for objective in scenario.primary_objectives + scenario.secondary_objectives:
        objective.status = MissionObjective.Status.PENDING
        _active_objectives.append(objective)

func _on_combat_started():
    _start_primary_objectives()

func _process(delta):
    _check_failure_conditions()
    _update_objectives()

func _start_primary_objectives():
    for objective in scenario.primary_objectives:
        objective.start()

func _check_failure_conditions():
    for condition in scenario.failure_conditions:
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
    if scenario.primary_objectives.all(func(obj): return obj.status == MissionObjective.Status.COMPLETED):
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