extends IStateController
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

signal unit_selected(unit: UnitHandler)
signal movement_executed(unit: UnitHandler, path: Array[HexCell])

#endregion

#region Exported Properties
@export_category("Subsystems")
## Initiative tracking and turn order management
@export var initiative_system: InitiativeSystem
@export var initiative_data: InitiativeData
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
## AI Controller class
@export var ai_controller_class: AIController
## Player Controller class
@export var player_controller_class: PlayerController
#endregion

#region Private Variables
var _current_turn: int = 0            # Current round number
var _active_unit: UnitHandler = null   # Unit currently taking action
var _combat_log: Array[String] = []   # Record of significant combat events
var _controllers: Dictionary = {}     # {unit_uuid: controller}
#endregion

func _init() -> void:
    instance=self

#region Turn Handle
func _ready() -> void:
    initiative_system.initialize(initiative_data)

func start_combat_round() -> void:
    initiative_system.reset_round()
    _process_next_unit()
#endregion

#region State Lifecycle Methods
## Initialize combat state with mission parameters
## @param context: Dictionary containing mission data and deployment info
func enter_state(context: Dictionary) -> void:
    super.enter_state(context)
    # Set up battlefield environment
    _setup_combat_environment(context)
    # Deploy units to battlefield
    _spawn_units(context)
    # Initialize mission director
    _initialize_mission_director()
    # Begin combat sequence
    _start_combat_sequence()

## Clean up combat state and return result data
## @return: Dictionary containing combat log, survivors, and battle outcome
func exit_state() -> Dictionary:
    var transition_data = super.exit_state()
    
    # Cleanup active unit connections
    if is_instance_valid(_active_unit):
        if _active_unit.has_signal("turn_ended"):
            _active_unit.disconnect("turn_ended", _on_unit_turn_ended)
        _active_unit = null
    
    # Store combat results
    transition_data["combat_log"] = _combat_log.duplicate()
    
    if unit_loader:
        transition_data["remaining_units"] = unit_loader.get_survivors()
        transition_data["destroyed_units"] = unit_loader.get_destroyed()
    else:
        push_warning("BattleController: Missing unit_loader reference")
        transition_data["remaining_units"] = []
        transition_data["destroyed_units"] = []
    
    # Clear battle-specific state
    _combat_log.clear()
    _current_turn = 0
    initiative_system.clear()
    _cleanup_controllers()
    
    return transition_data


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
## Configure battlefield environment from mission data
## @param context: Mission configuration data
func _setup_combat_environment(context: Dictionary) -> void:
    # Load map layout and terrain data
    grid_map.load_map(context.mission_data.map)
    # Reset turn counter
    _current_turn = 0
    # Clear previous combat records
    _combat_log.clear()

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
func _start_unit_turn(unit: UnitHandler) -> void:
    # Notify systems of phase change
    turn_phase_changed.emit("UNIT_TURN_START")
    
    # Create and assign controller based on unit team
    var controller_class = player_controller_class if unit.team == 0 else ai_controller_class
    var controller = controller_class.new()
    controller.begin_turn(unit)
    
    # Store controller in dictionary
    _controllers[unit.uuid] = controller
    
    # Add controller to scene tree
    add_child(controller)

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
    # Progress to next unit
    _process_next_unit()

## Handle mission completion
func _on_mission_completed(victory_type: String) -> void:
    print("Mission completed with victory type: %s" % victory_type)
    victory_achieved.emit()

## Handle mission failure
func _on_mission_failed(reason: String) -> void:
    print("Mission failed due to: %s" % reason)
    defeat_occurred.emit()

## Cleanup controllers at the end of combat
func _cleanup_controllers() -> void:
    for controller in _controllers.values():
        controller.queue_free()
    _controllers.clear()
#endregion