# UnitData.gd
class_name UnitData
extends Resource

enum MobilityType {
    BIPEDAL,    # Humanoid mechs/units
    WHEELED,    # Wheeled vehicles
    HOVER,      # Hovercraft/floating units
    TRACKED,    # Tank-like units
    AERIAL      # Flying units (limited)
}

## Unit definition with static properties
@export var unit_name: String = "Unnamed Unit"
@export var sections: Array[SectionData] = []
@export var critical_sections: Array[String] = ["CTorso"]
@export var base_heat_capacity: float = 30.0
@export var base_heat_dissipation: float = 2.0
@export var mobility_type: MobilityType = MobilityType.BIPEDAL
@export var max_elevation_change: int = 2