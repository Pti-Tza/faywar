# game_manager.gd
extends Node
class_name GameManager
## Main game coordination system handling turn sequence, phase management, 
## and high-level game rules enforcement

### REGION: Signals -----------------------------------------------------------
signal game_state_changed(new_state: GameState)
signal game_phase_changed(new_phase: GamePhase)
signal turn_advanced(new_turn: int)
signal active_player_changed(new_player_id: int)

### REGION: Enums -------------------------------------------------------------
enum GameState { INIT, PLAYING, PAUSED, GAME_OVER }
enum GamePhase { INITIATIVE, MOVEMENT, ATTACK, HEAT, END }

### REGION: Dependencies ------------------------------------------------------
## Reference to initiative tracking system
@export var initiative_system: Node
## Reference to heat management system
@export var heat_system: HeatSystem
## Reference to unit management system
@export var unit_manager: Node
## Player controller scene template
@export var player_controller: PackedScene
## AI controller scene template
@export var ai_controller: PackedScene

### REGION: Game State --------------------------------------------------------
var current_state: GameState = GameState.INIT:
    set(value):
        if current_state != value:
            current_state = value
            game_state_changed.emit(value)
            
var current_phase: GamePhase = GamePhase.INITIATIVE:
    set(value):
        if current_phase != value:
            current_phase = value
            game_phase_changed.emit(value)
            _handle_phase_transition()

var current_turn: int = 1
var active_player_id: int = -1  # -1 indicates no active player
var players: Array = []

### REGION: Turn Execution ----------------------------------------------------
var active_controller: BaseController = null

func _ready() -> void:
    _validate_dependencies()
    initialize_players()
    change_game_state(GameState.PLAYING)
    start_new_turn()

func _validate_dependencies() -> void:
    assert(initiative_system != null, "InitiativeSystem not assigned!")
    assert(heat_system != null, "HeatSystem not assigned!")
    assert(unit_manager != null, "UnitManager not assigned!")

### REGION: Public API --------------------------------------------------------

func start_new_turn() -> void:
    """Begin a new full turn sequence with initiative rolling"""
    var initiative_order = initiative_system.get_initiative_order()
    
    if initiative_order.is_empty():
        push_error("No units available for new turn")
        end_game()
        return
    
    current_turn += 1
    turn_advanced.emit(current_turn)
    _set_game_phase(GamePhase.INITIATIVE)
    set_active_player(initiative_order[0].player_id)

func advance_phase() -> void:
    """Progress to next phase in BattleTech sequence"""
    if current_state != GameState.PLAYING:
        push_warning("Can't advance phase while game is %s" % GameState.keys()[current_state])
        return
    
    match current_phase:
        GamePhase.INITIATIVE: _set_game_phase(GamePhase.MOVEMENT)
        GamePhase.MOVEMENT:   _set_game_phase(GamePhase.ATTACK)
        GamePhase.ATTACK:     _set_game_phase(GamePhase.HEAT)
        GamePhase.HEAT:       _set_game_phase(GamePhase.END)
        GamePhase.END:        start_new_turn()

func set_active_player(player_id: int) -> void:
    """Set currently acting player with validation"""
    if active_player_id == player_id: return
    
    if players.any(func(p): return p.id == player_id):
        active_player_id = player_id
        active_player_changed.emit(player_id)
    else:
        push_error("Attempted to set invalid player ID: %d" % player_id)

### REGION: Phase Handling ----------------------------------------------------

func _handle_phase_transition() -> void:
    """Execute phase-specific initialization logic"""
    match current_phase:
        GamePhase.INITIATIVE:
            initiative_system.roll_initiative()
            _activate_first_unit()
            
        GamePhase.MOVEMENT:
            _enable_movement_controls()
            
        GamePhase.ATTACK:
            _enable_attack_controls()
            
        GamePhase.HEAT:
            heat_system.process_heat_for_units(unit_manager.get_all_units())
            
        GamePhase.END:
            _cleanup_turn()

func _activate_first_unit() -> void:
    """Start turn for first unit in initiative order"""
    var next_unit = initiative_system.get_next_unit()
    if next_unit:
        start_unit_turn(next_unit)
    else:
        push_error("No units in initiative order")
        end_game()

func _cleanup_turn() -> void:
    """Perform end-of-turn maintenance"""
    unit_manager.reset_all_unit_states()
    initiative_system.clear_current_order()

### REGION: Unit Control ------------------------------------------------------

func start_unit_turn(unit: Node) -> void:
    """Initialize appropriate controller for unit"""
    if active_controller:
        active_controller.queue_free()
    
    active_controller = _create_controller(unit)
    add_child(active_controller)
    
    active_controller.turn_ended.connect(_on_controller_turn_ended)
    active_controller.begin_turn(unit)

func _create_controller(unit: Node) -> BaseController:
    """Instantiate correct controller type based on unit"""
    return (player_controller if unit.is_player_controlled 
            else ai_controller).instantiate()

func _on_controller_turn_ended(_controller: BaseController) -> void:
    """Handle completed unit turn"""
    active_controller.queue_free()
    active_controller = null
    advance_phase()

### REGION: Game Flow Control -------------------------------------------------

func end_game() -> void:
    """Transition to game over state"""
    change_game_state(GameState.GAME_OVER)
    get_tree().paused = true
    # Implement game over screen logic here

### REGION: Helper Methods ----------------------------------------------------

func initialize_players() -> void:
    """Initialize player data - implement with actual player setup"""
    players = []
    # Example: players.append(Player.new(1, "Player 1"))

func _set_game_phase(new_phase: GamePhase) -> void:
    """Wrapper for phase changes with validation"""
    if current_state == GameState.PLAYING:
        current_phase = new_phase
    else:
        push_warning("Phase change blocked in state: %s" % GameState.keys()[current_state])