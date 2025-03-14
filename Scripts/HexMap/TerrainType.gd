
extends Resource
class_name TerrainType

# Terrain type definition
var id: String
var movement_cost: float
var defense_bonus: int
var elevation: int
var is_impassable: bool
var heat_modifier: float
var visual_material: Material
var audio_footstep: AudioStream

var materials: Array[StandardMaterial3D] = []
var transition_priority: int = 0
var texture_variations: int = 1

func _init(
    id: String,
    movement_cost: float = 1.0,
    defense_bonus: int = 0,
    elevation: int = 0,
    is_impassable: bool = false,
    heat_modifier: float = 0.0,
    visual_material: Material = null,
    audio_footstep: AudioStream = null
    ):
        self.id = id
        self.movement_cost = movement_cost
        self.defense_bonus = defense_bonus
        self.elevation = elevation
        self.is_impassable = is_impassable
        self.heat_modifier = heat_modifier
        self.visual_material = visual_material
        self.audio_footstep = audio_footstep

func get_random_variant_material() -> StandardMaterial3D:
        if materials.is_empty():
            return null
        return materials[randi() % materials.size()]