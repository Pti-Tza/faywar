# UnitSection.gd
# Defines armor, structure, and components for a unit section.

class_name UnitSection
extends Resource

## Name of the section (e.g., "CTorso", "LArm")
@export var name: String = ""

## Armor points for this section
@export var armor: int = 0

## Structure points for this section
@export var structure: int = 0

## Components located in this section
@export var components: Array[String] = []

## Critical hit threshold for this section
@export var critical_threshold: int = 8

## Returns whether this section is destroyed
func is_destroyed() -> bool:
    return structure <= 0