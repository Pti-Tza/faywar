extends Node
class_name BattleController

## Tactical combat state controller managing turn-based battle execution
##
## Handles unit turns, victory conditions, and combat system coordination.
## Orchestrates interaction between game systems during active missions.
## Mission Completion or failure is triggered by MissionEvent 

static var instance : BattleController

#region Signals
## Emitted when combat sequence begins
signal combat_started
## Emitted when turn phase changes (UNIT_TURN_START, AI_PHASE, etc)
signal turn_phase_changed(phase: String)
## Emitted when victory conditions are met
signal victory_achieved
## Emitted when defeat conditions are triggered
signal defeat_occurred
## Action Handling
signal action_validated(action: String, valid: bool)
signal action_executed(action: String, result: Dictionary)


signal unit_selected(unit: Unit)
signal movement_executed(unit: Unit, path: Array[HexCell])

#endregion

#region Exported Properties
@export_category("Subsystems")
## Initiative tracking and turn order management
@export var initiative_system: InitiativeSystem
## Tactical battlefield grid and pathfinding
@export var grid_map: HexGridManager
## Unit spawning and lifecycle management
@export var unit_loader: UnitManager
@export var movement_system: MovementSystem
@export var attack_system: AttackSystem
@export var mission_director: MissionDirector

@export_category("Combat Rules")
## Maximum number of rounds before automatic timeout
@export var max_turns: int = 20
##  Controllers
@export var controllers: Array[BaseController]

#endregion

#region Private Variables
var _current_turn: int = 0            # Current round number
var _active_unit: Unit = null   # Unit currently taking action
var _combat_log: Array[String] = []   # Record of significant combat events
#endregion

func _init() -> void:
    instance=self

#region Turn Handle
#func _ready() -> void:
   # initiative_system.initialize(initiative_data)

func start_combat_round() -> void:
    initiative_system.reset_round()
    _process_next_unit()
#endregion

#region State Lifecycle Methods
## Initialize combat state with mission parameters
## @param context: Dictionary containing mission data and deployment info
func start_battle():

    # Initialize mission director
    _initialize_mission_director()
    # Begin combat sequence
    _start_combat_sequence()



## Get unique identifier for this state
## @return: String constant representing battle state
func get_state_name() -> String:
    return "BATTLE"
#endregion

#region Public Methods
## Force early termination of current unit's turn
func end_turn_early() -> void:
    if _active_unit:
        # Clean up unit turn state
        _active_unit.end_turn()
        # Progress to next unit
        _process_next_unit()
#endregion

#region Private Implementation

## Spawn units onto battlefield according to deployment data
## @param context: Contains player/enemy unit configurations
func _spawn_units(context: Dictionary) -> void:
    # Spawn player units at designated locations
    unit_loader.spawn_team(context.player_units, context.player_spawns)
    # Spawn enemy units at hostile spawn points
    unit_loader.spawn_team(context.enemy_units, context.enemy_spawns)

## Initialize mission director
func _initialize_mission_director() -> void:
    mission_director.initialize_mission(unit_loader)
    mission_director.mission_completed.connect(_on_mission_completed)
    mission_director.mission_failed.connect(_on_mission_failed)

## Begin combat sequence and initialize turn order
func _start_combat_sequence() -> void:
    # Calculate initial initiative order
    initiative_system.initialize(unit_loader.get_all_units())
    # Signal combat start to other systems
    combat_started.emit()
    # Begin first unit's turn
    _process_next_unit()

## Progress to next unit in initiative order
func _process_next_unit() -> void:
    if initiative_system.has_actions_remaining():
        # Get next unit from initiative queue
        _active_unit = initiative_system.get_next_unit()
        # Start unit's turn sequence
        _start_unit_turn(_active_unit)
        emit_signal("unit_selected", _active_unit)
    else:
        # Handle end of combat round
        _end_combat_round()

## Begin turn sequence for specific unit
## @param unit: CombatUnit starting their turn
func _start_unit_turn(unit: Unit) -> void:
    # Notify systems of phase change
    turn_phase_changed.emit("UNIT_TURN_START")
    
    # Create and assign controller based on unit team
    for controller in controllers:
     if controller.team_index == unit.team : controller.begin_turn(unit)   
     # Connect signals
     controller.turn_ended.connect(_on_unit_turn_ended)
     controller.action_selected.connect(_on_controller_action)



## Handle end of combat round and check turn limits
func _end_combat_round() -> void:
    _current_turn += 1
    if _current_turn >= max_turns:
        # Handle turn limit expiration
        _handle_timeout()
    else:
        # Reset initiative for new round
        initiative_system.reset_for_new_round()
        # Start next round
        _process_next_unit()

func _handle_timeout() -> void:
    push_warning("Combat timed out after %d turns." % max_turns)
    defeat_occurred.emit()

## Handle unit turn completion
func _on_unit_turn_ended(controller: BaseController):
    # Disconnect signal handler
    if is_instance_valid(controller):
        controller.disconnect("turn_ended", _on_unit_turn_ended)
        controller.disconnect("action_selected", _on_controller_action)
    # Progress to next unit
    _process_next_unit()


func _on_action_requested(action: String, details: Dictionary):
    if not validate_turn_ownership(details.unit):
        action_validated.emit(action, false)
        return
    
    var validation = false
    match action:
        "move":
            validation = MovementSystem.instance.validate(details)
        "attack":
            validation = AttackSystem.instance.validate(details)
    
    action_validated.emit(action, validation)
    
    if validation:
        var result = execute_action(action, details)
        action_executed.emit(action, result)

func execute_action(action: String, details: Dictionary) -> Dictionary:
    match action:
        "move":
            return MovementSystem.instance.execute(details)
        "attack":
            return AttackSystem.instance.execute(details)
    return {}


func validate_turn_ownership(details: Dictionary) -> bool:
    """Validates if the acting unit has turn ownership.
    
    Returns true only if:
    1. There is an active unit in the current turn
    2. The acting unit matches the active unit
    3. The unit reference is valid"""
    
    # Null check active unit
    if not is_instance_valid(_active_unit):
        push_warning("Turn validation failed: No active unit")
        return false
    
    # Check details contains valid unit reference
    if not details.has("unit") or not is_instance_valid(details.unit):
        push_warning("Turn validation failed: Invalid unit reference")
        return false
    
    # Ownership check
    var is_owner = (details.unit.uuid == _active_unit.uuid)
    
    # Debug logging
    if not is_owner:
        var active_name = _active_unit.unit_data.name
        var attempt_name = details.unit.unit_data.name
        push_warning("Turn violation: %s attempted action during %s's turn" % [attempt_name, active_name])
    
    return is_owner



func _on_controller_action(action_type: String, details: Dictionary) -> void:
    match action_type:
        "move":
            _handle_move_action(details)
        "attack":
            _handle_attack_action(details)
        "ability":
            _handle_ability_action(details)
        _:
            push_error("Unknown action type: ", action_type)

func _handle_move_action(details: Dictionary) -> void:
    if movement_system.validate_move(_active_unit, details.path):
        movement_system.execute_move(_active_unit, details.path)
        emit_signal("movement_executed", _active_unit, details.path)
    else:
        push_warning("Invalid move path for ", _active_unit.unit_data.name)

func _handle_attack_action(details: Dictionary) -> void:
    var target = details.target
    var weapon = details.weapon
    if attack_system.validate_attack(_active_unit, target, weapon):
        attack_system.resolve_attack(_active_unit, target, weapon)
    else:
        push_warning("Invalid attack from ", _active_unit.unit_data.name)

func _handle_ability_action(details: Dictionary) -> void:
    # Implement ability-specific logic
    pass




## Handle mission completion
func _on_mission_completed(victory_type: String) -> void:
    print("Mission completed with victory type: %s" % victory_type)
    victory_achieved.emit()

## Handle mission failure
func _on_mission_failed(reason: String) -> void:
    print("Mission failed due to: %s" % reason)
    defeat_occurred.emit()


#endregion
