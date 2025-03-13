# SectionData.gd
class_name SectionData
extends Resource

## Section definition with static properties
var section_name: String 
var max_armor: float = 50.0
var max_structure: float = 25.0
var components: Array[ComponentData] = []
var armor_type: String = "Standard"  # "Ferro-Fibrous", "Reactive", etc.