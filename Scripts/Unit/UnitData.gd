# UnitData.gd
class_name UnitData
extends Resource

## Unit definition with static properties
@export var unit_name: String = "Unnamed Unit"
@export var sections: Array[SectionData] = []
@export var critical_sections: Array[String] = ["CTorso"]
@export var heat_capacity: float = 30.0
@export var heat_dissipation: float = 2.0