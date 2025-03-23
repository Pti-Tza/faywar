### Example Extension ###
# Example: SpawnReinforcementEvent.gd
extends MissionEvent
class_name SpawnReinforcementEvent

@export var spawn_location: Vector3i
@export var unit_profile: UnitData

func _execute() -> void:
    var unit = get_node("/root/UnitManager").spawn_unit(unit_profile, spawn_location)
    emit_signal("event_activated", unit)