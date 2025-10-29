# BottomActionPanel.gd
# Displays context-sensitive action buttons for the currently selected unit.
# Supports core tactical actions (Move, Attack, Brace) and is designed for easy extension.
#
# Responsibilities:
# - Dynamically populate action buttons based on unit state
# - Enable/disable actions using unit capabilities
# - Emit intent signals without executing game logic (decoupled design)
#
# Dependencies:
# - Requires valid `Unit` reference via `show_for_unit()`
# - Relies on `HexGridHighlights` for visual feedback
# - Assumes `action_button_scene` is a valid Button-based scene with `configure()` method

extends Control
class_name BottomActionPanel

## Emitted when the player initiates a move action
signal movement_initiated(unit: Unit)
## Emitted when the player initiates an attack action
signal attack_initiated(unit: Unit)

@export var end_turn_btn: Button
@export var actions_container: Container

@export var action_button_scene: PackedScene

# Action definitions with text, icon, and availability logic
# Icons are preloaded for performance

const CORE_ACTIONS := {
	"move": {
		"text": "Move",
		"icon": preload("res://Textures/UI/move_icon.png")
	},
	"attack": {
		"text": "Attack",
		"icon": preload("res://Textures/UI/attack_icon.png")
	},
	"sprint": {
		"text": "Sprint",
		"icon": preload("res://Textures/UI/move_icon.png")  # Using move icon as placeholder
	},
	"brace": {
		"text": "Brace",
		"icon": preload("res://Textures/UI/brace_icon.png")
	}
}

var current_unit: Unit = null

## Shows the action panel for the given unit and populates available actions.
## @param unit: The tactical unit to display actions for. Must be valid.
func show_for_unit(unit: Unit) -> void:
	if not unit:
		push_error("BottomActionPanel: Cannot show for null unit")
		return

	current_unit = unit
	visible = true
	_clear_actions()
	_populate_core_actions()
	_populate_custom_actions()

## Clears all dynamically created action buttons.
func _clear_actions() -> void:
	for child in actions_container.get_children():
		child.queue_free()
	# Note: Do NOT free children of `self` — only designated containers

## Populates core action buttons based on `CORE_ACTIONS`.
func _populate_core_actions() -> void:
	for action_key in CORE_ACTIONS:
		var config = CORE_ACTIONS[action_key]
		var btn = action_button_scene.instantiate()
		btn.configure(config.text, config.icon, _is_action_available(action_key))
		btn.pressed.connect(_on_core_action_selected.bind(action_key))
		actions_container.add_child(btn)

## Determines if a core action is available for the current unit.
## @param action: Action key (e.g., "move", "attack")
## @return: True if the action can be performed
func _is_action_available(action: String) -> bool:
	if not current_unit:
		return false

	match action:
		"move": return current_unit.remaining_mp > 0
		"attack": return current_unit.can_attack
		"sprint": return current_unit.remaining_mp > 1  # Sprint requires more MP
		"brace": return current_unit.can_brace
	return false

## Handles button press for core actions.
## Emits intent signals and triggers UI/visual feedback.
## Does NOT execute game logic (decoupled via BattleController).
func _on_core_action_selected(action: String) -> void:
	if not current_unit:
		return

	match action:
		"move":
			# Use local unit, not PlayerController.instance
			HexGridHighlights.instance.update_movement_highlights(current_unit)
			movement_initiated.emit(current_unit)

		"attack":
			HexGridHighlights.instance.update_attack_highlights(current_unit, null)
			attack_initiated.emit(current_unit)

		"sprint":
			# Sprint might have special highlighting or behavior
			HexGridHighlights.instance.update_movement_highlights(current_unit)
			# Could emit a separate signal for sprint if needed
			movement_initiated.emit(current_unit)

		"brace":
			current_unit.activate_brace()
			# Note: Turn ending should be handled by BattleController, not UI
			hide()

## Populates custom actions for non-standard units
func _populate_custom_actions() -> void:
	if current_unit and current_unit.has_method("get_custom_actions"):
		var custom_actions = current_unit.get_custom_actions()
		for action in custom_actions:
			var btn = action_button_scene.instantiate()
			btn.configure(action.text, action.icon, action.enabled)
			btn.pressed.connect(_on_custom_action_selected.bind(action.id))
			actions_container.add_child(btn)

## Handles button press for custom actions
func _on_custom_action_selected(action_id: String) -> void:
	if current_unit and current_unit.has_method("execute_action"):
		current_unit.execute_action(action_id)
		hide()
