# UI/InitiativeUITracker.gd
extends HBoxContainer
class_name InitiativeUITracker

@export var slide_duration: float = 0.3  # Animation time in seconds

@onready var unit_icon_scene = preload("res://UI/UnitIcon.tscn")

var _current_order: Array[Unit] = []
var _tween: Tween

signal unit_focused(unit: Unit)

func update_turn_order(new_order: Array[Unit]) -> void:
	# First update: just populate
	if _current_order.is_empty():
		_populate_queue(new_order)
		_current_order = new_order.duplicate()
		return

	# Detect if first unit changed (i.e., turn ended)
	if new_order.size() > 0 and _current_order.size() > 0:
		if new_order[0] != _current_order[0]:
			# Animate removal of first unit
			_animate_turn_end()
	
	_current_order = new_order.duplicate()
	# Rebuild queue after animation if needed
	await _rebuild_after_animation(new_order)

func _populate_queue(order: Array[Unit]) -> void:
	for unit in order:
		var icon = _create_unit_icon(unit)
		add_child(icon)

func _create_unit_icon(unit: Unit) -> Node:
	var icon = unit_icon_scene.instantiate()
	
	# Check if the instantiated node is a Button, otherwise find the Button in its children
	var button: Button
	if icon is Button:
		button = icon
	else:
		# Find the first Button in the children
		button = icon.find_child("*", true, false) as Button
		if button == null:
			push_error("No Button found in the unit icon scene!")
			return null  # or handle the error as appropriate for your game
	
	button.icon = unit.icon
	button.connect("gui_input", Callable(self, "_on_unit_icon_interacted").bind(unit))
	button.focus_mode = Control.FOCUS_NONE
	return icon

func _animate_turn_end() -> void:
	if get_child_count() == 0:
		return

	var first_icon = get_child(0)
	_tween = create_tween()
	_tween.set_parallel(true)

	# Slide all icons left by first icon's width + spacing
	var slide_distance = first_icon.size.x + get_theme_constant("separation")

	for i in get_child_count():
		var child = get_child(i)
		_tween.tween_property(child, "position:x", child.position.x - slide_distance, slide_duration)

	# Fade out and remove first icon after slide
	_tween.tween_callback(Callable(self, "_remove_first_icon"))

func _remove_first_icon() -> void:
	if get_child_count() > 0:
		var first = get_child(0)
		first.queue_free()

func _rebuild_after_animation(new_order: Array[Unit]) -> void:
	# Wait for any active tween to finish
	if _tween and _tween.is_running():
		await _tween.finished

	# Ensure queue matches new_order (handles mid-turn changes)
	_sync_queue_to_order(new_order)

func _sync_queue_to_order(order: Array[Unit]) -> void:
	# Remove excess children
	while get_child_count() > order.size():
		get_child(0).queue_free()

	# Add missing children at the end
	while get_child_count() < order.size():
		var unit = order[get_child_count()]
		add_child(_create_unit_icon(unit))

	# Update icons in case units changed (e.g., destroyed)
	for i in min(get_child_count(), order.size()):
		var icon = get_child(i) as Button
		icon.icon = order[i].icon

## Input Handling
func _on_unit_icon_interacted(event: InputEvent, unit: Unit) -> void:
	if event is InputEventMouseButton and event.pressed:
		emit_signal("unit_focused", unit)
