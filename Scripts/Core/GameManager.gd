extends Node
class_name GameManager

# Game state
enum GameState { INIT, PLAYING, PAUSED, GAME_OVER }
enum GamePhase { INITIATIVE, MOVEMENT, ATTACK, HEAT, END }

var current_state: GameState = GameState.INIT:
    set = change_game_state
var current_phase: GamePhase = GamePhase.INITIATIVE:
    set = change_game_phase
var current_turn: int = 1
var active_player_id: int = -1  # -1 = unassigned
var players: Array = []

# Signals
signal game_state_changed(new_state: GameState)
signal game_phase_changed(new_phase: GamePhase)
signal turn_advanced(new_turn: int)
signal active_player_changed(new_player_id: int)

# -------------------------------
# Core Functions
# -------------------------------

func _ready() -> void:
    initialize_players()
    change_game_state(GameState.PLAYING)
    start_new_turn()

func initialize_players() -> void:
    # Connect to your player config system
    players = []  # Replace with actual player setup

func change_game_state(new_state: GameState) -> void:
    if current_state == new_state:
        return
    if current_state == GameState.GAME_OVER && new_state != GameState.GAME_OVER:
        push_error("Invalid state transition from GAME_OVER")
        return
    current_state = new_state
    emit_signal("game_state_changed", new_state)

func change_game_phase(new_phase: GamePhase) -> void:
    if current_phase == new_phase:
        return
    if current_state != GameState.PLAYING && new_phase != GamePhase.INITIATIVE:
        push_error("Can't change phase while game isn't playing")
        return
    current_phase = new_phase
    emit_signal("game_phase_changed", new_phase)
    _handle_phase_start()

func _handle_phase_start() -> void:
    match current_phase:
        GamePhase.INITIATIVE:
            InitiativeSystem.roll_initiative()
        GamePhase.HEAT:
            HeatSystem.resolve_all_heat()

# -------------------------------
# Turn Handling
# -------------------------------

func start_new_turn() -> void:
    var initiative_order = InitiativeSystem.get_order()
    if initiative_order.is_empty():
        push_error("No units available for new turn")
        end_game()
        return
    
    current_turn += 1
    emit_signal("turn_advanced", current_turn)
    change_game_phase(GamePhase.INITIATIVE)
    set_active_player(initiative_order[0].player_id)

func advance_phase() -> void:
    if current_state != GameState.PLAYING:
        push_warning("Can't advance phase while game is ", GameState.keys()[current_state])
        return

    match current_phase:
        GamePhase.INITIATIVE:
            if !_all_units_ready():
                return
            change_game_phase(GamePhase.MOVEMENT)
        GamePhase.MOVEMENT:
            change_game_phase(GamePhase.ATTACK)
        GamePhase.ATTACK:
            change_game_phase(GamePhase.HEAT)
        GamePhase.HEAT:
            change_game_phase(GamePhase.END)
        GamePhase.END:
            start_new_turn()

# -------------------------------
# Player Management
# -------------------------------

func set_active_player(player_id: int) -> void:
    if active_player_id == player_id:
        return
    if !players.any(func(p): return p.id == player_id):
        push_error("Invalid player ID: ", player_id)
        return
    active_player_id = player_id
    emit_signal("active_player_changed", player_id)

# -------------------------------
# Helper Functions
# -------------------------------

func _all_units_ready() -> bool:
    # Check if all AI/players have prepped their turns
    return UnitManager.are_all_units_ready()

func _resolve_heat_damage() -> void:
    HeatSystem.process_heat_for_units(UnitManager.get_all_units())

func end_game() -> void:
    change_game_state(GameState.GAME_OVER)
    get_tree().paused = true