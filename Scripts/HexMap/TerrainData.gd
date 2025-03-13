class_name TerrainData
extends Resource

# Terrain type definition
class TerrainType:
    var id: String
    var movement_cost: float
    var defense_bonus: int
    var elevation: int
    var is_impassable: bool
    var heat_modifier: float
    var visual_material: Material
    var audio_footstep: AudioStream

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

# Terrain database
@export var terrain_types: Array[TerrainType] = []

# Global modifiers
@export var elevation_cost_multiplier: float = 0.5
@export var default_terrain: String = "plains"

# Cache for quick lookups
var _terrain_cache: Dictionary = {}

func _ready() -> void:
    _build_terrain_cache()

# Build a lookup cache for terrain types
func _build_terrain_cache() -> void:
    for terrain in terrain_types:
        _terrain_cache[terrain.id] = terrain

# Get terrain type by ID
func get_terrain_type(terrain_id: String) -> TerrainType:
    return _terrain_cache.get(terrain_id, _terrain_cache[default_terrain])

# Get movement cost for a terrain type
func get_movement_cost(terrain_id: String) -> float:
    var terrain = get_terrain_type(terrain_id)
    return terrain.movement_cost if terrain else 1.0

# Get defense bonus for a terrain type
func get_defense_bonus(terrain_id: String) -> int:
    var terrain = get_terrain_type(terrain_id)
    return terrain.defense_bonus if terrain else 0

# Check if terrain is impassable
func is_impassable(terrain_id: String) -> bool:
    var terrain = get_terrain_type(terrain_id)
    return terrain.is_impassable if terrain else false

# Get heat modifier for a terrain type
func get_heat_modifier(terrain_id: String) -> float:
    var terrain = get_terrain_type(terrain_id)
    return terrain.heat_modifier if terrain else 0.0

# Get visual material for a terrain type
func get_visual_material(terrain_id: String) -> Material:
    var terrain = get_terrain_type(terrain_id)
    return terrain.visual_material if terrain else null

# Get footstep audio for a terrain type
func get_footstep_audio(terrain_id: String) -> AudioStream:
    var terrain = get_terrain_type(terrain_id)
    return terrain.audio_footstep if terrain else null