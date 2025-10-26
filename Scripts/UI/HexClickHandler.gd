# HexClickHandler.gd
# Singleton that translates mouse clicks into hex cell selections.
# Emits 'hex_clicked' signal with the clicked HexCell.
# Automatically ignores clicks over UI elements.

extends Node3D
class_name HexClickHandler

static var instance: HexClickHandler

signal hex_clicked(cell: HexCell)

@onready var _camera := get_viewport().get_camera_3d()

func _init():
	instance = self

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return

	# Skip if mouse is over any UI control
	if _is_mouse_over_ui():
		return

	var ray_origin = _camera.project_ray_origin(get_viewport().get_mouse_position())
	var ray_end = ray_origin + _camera.project_ray_normal(get_viewport().get_mouse_position()) * 10000

	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	)

	if result:
		var cell = HexGridManager.instance.get_cell_at_position(result.position)
		if cell:
			hex_clicked.emit(cell)

func _is_mouse_over_ui() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	for control in get_tree().get_nodes_in_group("ui_control"):
		if control is Control and control.visible and control.get_global_rect().has_point(mouse_pos):
			return true
	return false
