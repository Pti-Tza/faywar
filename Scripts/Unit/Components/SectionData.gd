extends Resource
class_name SectionData

### Core Section Properties ###
@export var section_name: String = "" # e.g., "CTorso", "LArm"
@export var max_armor: float = 50.0
@export var max_structure: float = 25.0
@export var components: Array[ComponentData] = [] # Components in this section
@export var armor_type: String = "Standard" # "Ferro-Fibrous", "Reactive"
@export var critical: bool = false

### Damage Modifiers ###
@export var critical_damage_multiplier: float = 2.0 # BattleTech doubles crit damage
@export var structure_damage_threshold: float = 0.0 # Structure damage threshold for critical effects