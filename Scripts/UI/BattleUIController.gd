# BattleUIController.gd
# Manages UI state and input during tactical combat.
# Supports multiple player controllers (non-singleton).
# Uses a state machine and hex click handler to coordinate interaction.

extends CanvasLayer
class_name BattleUIController

enum ActionState {
	IDLE,
	SELECTING_MOVE_DEST,
	SELECTING_ATTACK_TARGET
}

var _current_state: ActionState = ActionState.IDLE
var _pending_unit: Unit = null
var _active_controller: BaseController = null  # ← Key change
var _active_unit_decal: Decal = null

@export var unit_status : UnitStatusPanel
@export var bottom_action_panel : BottomActionPanel
@export var initiative : InitiativeUITracker
@export var combat_log : CombatLog
@export var unit_decal_scene: PackedScene
@export var hex_info_panel: Control  # Hex info panel reference

var click_handler : HexClickHandler

func _ready() -> void:
	# Connect to game systems
	BattleController.instance.unit_selected.connect(_on_unit_selected)
	InitiativeSystem.instance.turn_order_updated.connect(_on_turn_order_updated)
	BattleController.instance.action_executed.connect(_on_action_executed)
	BattleController.instance.turn_started.connect(_on_turn_started)

	# Connect UI action signals
	bottom_action_panel.movement_initiated.connect(_on_move_requested)
	bottom_action_panel.attack_initiated.connect(_on_attack_requested)

	# Register for hex clicks
	click_handler = HexClickHandler.instance
	
	if click_handler:
		click_handler.hex_clicked.connect(_on_hex_clicked)
	else:
		push_error("No hex_click_handler")

	# Initialize hex info panel if available
	if hex_info_panel:
		# The hex info panel has its own hover detection, so we don't need additional setup here
		pass
		
	# Set up the hex info panel reference in the scene
	if not hex_info_panel:
		# Try to find the hex info panel as a child or sibling
		hex_info_panel = get_node_or_null("HexInfoPanel")
	
	# Ensure the hex info panel is properly initialized
	if hex_info_panel:
		# The hex info panel has its own hover detection, so we don't need additional setup here
		pass
	else:
		print("Warning: HexInfoPanel not found in the scene")

func _on_unit_selected(unit: Unit) -> void:
	if not unit or not unit.controller:
		return

	_active_controller = unit.controller
	unit_status.update_display(unit)

	# Show panel only for human-controlled units (e.g., team 0)
	if unit.team == 0:
		bottom_action_panel.show_for_unit(unit)
	else:
		bottom_action_panel.hide()

	_set_state(ActionState.IDLE)

# --- Action Requests from UI ---
func _on_move_requested(unit: Unit) -> void:
	if not unit or not unit.controller:
		return
	_pending_unit = unit
	_active_controller = unit.controller
	var reachable = MovementSystem.instance.get_reachable_hexes(unit)
	HexGridHighlights.instance.update_movement_highlights(reachable)
	_set_state(ActionState.SELECTING_MOVE_DEST)

func _on_attack_requested(unit: Unit) -> void:
	if not unit or not unit.controller:
		return
	_pending_unit = unit
	_active_controller = unit.controller
	for weapon in unit.weapons:
		if weapon.is_operational and weapon.maximum_range > 0:
			HexGridHighlights.instance.update_attack_highlights(unit, weapon)
	_set_state(ActionState.SELECTING_ATTACK_TARGET)

# --- Hex Click Handler ---
func _on_hex_clicked(cell: HexCell) -> void:
	if not _active_controller or not _pending_unit:
		return

	match _current_state:
		ActionState.SELECTING_MOVE_DEST:
			if cell in MovementSystem.instance.get_reachable_hexes(_pending_unit):
				# Build full path (optional: use pathfinding)
				var path = [_pending_unit.get_current_cell(), cell]
				_active_controller.handle_move_input(path)
				_set_state(ActionState.IDLE)

		ActionState.SELECTING_ATTACK_TARGET:
			var target_unit = cell.unit
			if target_unit and TeamManager.instance.are_enemies(_pending_unit.team, target_unit.team):
				var weapon = _pending_unit.weapons.filter(func(w): return w.is_operational)[0]
				if weapon:
					_active_controller.handle_attack_input(target_unit, weapon)
					_set_state(ActionState.IDLE)

# --- State Management ---
func _set_state(new_state: ActionState) -> void:
	_current_state = new_state
	_pending_unit = null if new_state == ActionState.IDLE else _pending_unit
	_active_controller = null if new_state == ActionState.IDLE else _active_controller

	if new_state == ActionState.IDLE:
		HexGridHighlights.instance.clear_all_highlights()
		bottom_action_panel.hide()

# --- Action Execution Feedback ---
func _on_action_executed(action: String, result: Dictionary) -> void:
	match action:
		"move":
			combat_log.add_simple_entry(
				"{unit} moved {count} hexes".format({
					"unit": result.unit.unit_name,
					"count": result.path.size()
				}),
				"movement"
			)
		"attack":
			var dmg = result.total_damage
			combat_log.add_simple_entry(
				"{attacker} → {target}: {dmg} dmg".format({
					"attacker": result.attacker.unit_name,
					"target": result.target.unit_name,
					"dmg": dmg
				}),
				"damage" if dmg > 0 else "miss"
			)
	_set_state(ActionState.IDLE)

# --- System Event Handlers ---
func _on_turn_order_updated(order: Array[Unit]) -> void:
	initiative.update_turn_order(order)

func _on_turn_started(unit: Unit) -> void:
	_show_active_unit_decal(unit)
	
	# Also update the UI to show the active unit's information
	if unit:
		_active_controller = unit.controller
		unit_status.update_display(unit)
		
		# Show panel only for human-controlled units (e.g., team 0)
		if unit.team == 0:
			bottom_action_panel.show_for_unit(unit)
		else:
			bottom_action_panel.hide()
		
		_set_state(ActionState.IDLE)

func _show_active_unit_decal(unit: Unit) -> void:
	# Remove existing decal if present
	if _active_unit_decal:
		_active_unit_decal.queue_free()
		_active_unit_decal = null
	
	# Create new decal if we have a unit
	if unit and unit_decal_scene:
		_active_unit_decal = unit_decal_scene.instantiate()
		if _active_unit_decal:
			# Position the decal at the unit's global position
			_active_unit_decal.position = unit.global_position + Vector3(0, 0.1, 0)  # Slightly above the unit
			get_parent().add_child(_active_unit_decal)  # Add to the same parent as this UI controller

			# Set up a timer to continuously update the decal position
			var update_timer = Timer.new()
			update_timer.wait_time = 0.1  # Update 10 times per second
			update_timer.timeout.connect(_update_decal_position.bind(unit, _active_unit_decal))
			update_timer.autostart = true
			add_child(update_timer)
			
			# Set up a timer to rotate the decal
			var rotation_timer = Timer.new()
			rotation_timer.wait_time = 0.05  # Update rotation quickly for smooth effect
			rotation_timer.timeout.connect(_rotate_decal.bind(_active_unit_decal))
			rotation_timer.autostart = true
			add_child(rotation_timer)

func _update_decal_position(unit: Unit, decal: Decal) -> void:
	if unit and decal and is_instance_valid(unit) and is_instance_valid(decal):
		# Update the decal's position to match the unit's global position
		decal.position = unit.global_position + Vector3(0, 0.1, 0)  # Slightly above the unit
	else:
		# If unit or decal is no longer valid, stop updating
		for child in get_children():
			if child is Timer and child.timeout.is_connected(_update_decal_position):
				child.stop()
				child.queue_free()
				break

func _rotate_decal(decal: Decal) -> void:
	if decal and is_instance_valid(decal):
		# Rotate the decal around the Y axis for a spinning effect
		decal.rotate_y(0.1)  # Rotate by 0.1 radians each update
	else:
		# If decal is no longer valid, stop updating
		for child in get_children():
			if child is Timer and child.timeout.is_connected(_rotate_decal):
				child.stop()
				child.queue_free()
				break
