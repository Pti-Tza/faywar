# DestructionHandler.gd (Abstract Base Class)
class_name DestructionHandler
extends Node

## Interface for handling destruction consequences
func handle_section_destruction(unit: Node, section: String) -> void:
    pass

## Interface for handling critical hits
func handle_critical_hit(unit: Node, component: String) -> void:
    pass