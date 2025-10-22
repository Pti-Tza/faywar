# UI/IvenitiatiTracker.gd
extends HBoxContainer
class_name InitiativeTracker

@onready var unit_icon = preload("res://UI/UnitIcon.tscn")
func update_turn_order(order: Array[Unit]) -> void:
    clear_children()
    
    for unit in order:
        var icon = unit_icon.instantiate()
        icon.unit = unit
        icon.connect("gui_input", Callable(self, "_on_unit_icon_interacted").bind(unit))
        add_child(icon)

func _on_unit_icon_interacted(event: InputEvent, unit: Unit) -> void:
    if event is InputEventMouseButton and event.pressed:
        emit_signal("unit_focused", unit)

func clear_children() -> void:
    for child in get_children():
        child.queue_free()