
extends IStateController
class_name MainMenuController
## Main menu state controller handling initial game setup and navigation
##
## Manages UI presentation, save file interactions, and transitions to other game states.
## Coordinates with background loading system for visual presentation.

#region Signals
## Emitted when player selects new game with chosen difficulty
signal new_game_selected(difficulty: String)
## Emitted when player selects a valid save slot to load
signal load_game_selected(slot: int)
## Emitted when player opens settings menu
signal settings_opened
#endregion

#region Exports
@export_category("Dependencies")
## Reference to save game management system
@export var save_system: SaveManager
## UI controller handling menu presentation and interaction
@export var ui_controller: Control
## System for asynchronous background scene loading
@export var background_loader: BackgroundLoader

@export_category("Configuration")
## Default difficulty setting for new games
@export var default_difficulty: String = "medium"
## Maximum number of save slots to display
@export var max_save_slots: int = 10
#endregion

#region Private Variables
var _current_selection: int = 0      # Currently selected menu option index
var _valid_saves: Array[int] = []    # List of valid save slots with existing data
#endregion

#region State Lifecycle Methods
## Called when entering the main menu state
## @param context: Dictionary containing transition data from previous state
func enter_state(context: Dictionary) -> void:
    super(context)
    # Set visible mouse cursor for menu navigation
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    # Initialize UI components
    _initialize_ui()
    # Load background visuals asynchronously
    _load_background()
    # Refresh available save slots
    _refresh_save_slots()

## Called when exiting the main menu state
## @return: Dictionary containing transition data for next state
func exit_state() -> Dictionary:
    var transition_data = super()
    # Clean up background resources
    background_loader.unload_current()
    # Hide UI elements
    ui_controller.visible = false
    return transition_data

## Get unique identifier for this state
## @return: String constant representing main menu state
func get_state_name() -> String:
    return "MAIN_MENU"
#endregion

#region Input Handling
## Process input events specific to main menu navigation
## @param event: InputEvent to handle
func handle_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_accept"):
        _handle_confirm()
    elif event.is_action_pressed("ui_cancel"):
        _handle_back()
    elif event.is_action_pressed("ui_up"):
        _navigate(-1)
    elif event.is_action_pressed("ui_down"):
        _navigate(1)
#endregion

#region Private Implementation
## Initialize UI components and default state
func _initialize_ui() -> void:
    ui_controller.visible = true
    # Configure difficulty selection options
    ui_controller.set_difficulty_options(["easy", "medium", "hard"])
    # Set initial menu selection
    ui_controller.set_initial_selection(_current_selection)

## Load background scene asynchronously
func _load_background() -> void:
    background_loader.load_scene("res://backgrounds/main_menu_bg.tscn")
    
## Refresh list of valid save slots from storage
func _refresh_save_slots() -> void:
    _valid_saves = save_system.get_valid_saves(max_save_slots)
    ui_controller.update_save_slots(_valid_saves)

## Handle confirmation/selection action
func _handle_confirm() -> void:
    match _current_selection:
        0:  # New Game
            new_game_selected.emit(default_difficulty)
        1:  # Load Game
            if _valid_saves.size() > 0:
                load_game_selected.emit(_get_selected_slot())
        2:  # Settings
            settings_opened.emit()

## Handle menu navigation
## @param direction: Navigation direction (-1 = up, 1 = down)
func _navigate(direction: int) -> void:
    # Wrap selection index within valid range
    _current_selection = wrapi(_current_selection + direction, 0, 3)
    # Update UI highlight position
    ui_controller.update_selection(_current_selection)

## Get currently selected save slot index
## @return: Validated save slot index
func _get_selected_slot() -> int:
    return clamp(_current_selection - 1, 0, _valid_saves.size() - 1)
#endregion