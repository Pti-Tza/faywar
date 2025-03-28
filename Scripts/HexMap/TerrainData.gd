# TerrainData.gd
extends Resource
class_name TerrainData

### Battletech Core Terrain Properties (TW p.52-58) ###
@export_category("Identification")
@export var name: String = "Terrain"
@export var map_symbol: String = "T"  # Standard BT map notation

@export_category("Movement Costs")
@export var foot_movement: int = 1      # Bipedal/infantry
@export var wheeled_movement: int = 2   # Wheeled vehicles
@export var tracked_movement: int = 3   # Tanks
@export var hover_movement: int = 1     # Hover units
@export var vtol_movement: int = 1      # VTOL aircraft

@export_category("Combat Modifiers")
@export var defense_bonus: int = 0      # To-hit penalty
@export var stealth_modifier: int = 0    # Sensor/visual detection
@export var heat_modifier: int = 0       # Heat generation per turn

@export_category("Special Rules")
@export var blocks_los: bool = false    # Line of sight blocking
@export var flammable: bool = false     # Can catch fire
@export var crumble: bool = false       # Can be destroyed
@export var min_depth: int = 0          # For water features
@export var max_depth: int = 0

### Advanced Properties ###
@export_category("Visual Presentation")

@export var terrain_texture: String = "grass"
@export var strategic_map_color: Color
@export var model: Mesh

## Base material for this terrain type
@export var visual_material: Material
## Array of material variations for visual diversity
@export var material_variations: Array[Material]
## Particle effect for environmental interactions
#@export var footstep_effect: GPUParticles3D

@export_category("Audio Properties")
## Footstep sound for standard movement
@export var footstep_audio: AudioStream
## Special movement sound (e.g., water splashing)
@export var special_move_audio: AudioStream



@export_category("Damage Rules")
@export var armor_damage_mod: float = 1.0  # Damage multiplier
@export var crit_chance_mod: float = 1.0   # Critical hit modifier

# Battletech-standard movement cost accessor
func get_movement_cost(mobility_type: UnitData.MobilityType) -> int:
	match mobility_type:
		UnitData.MobilityType.BIPEDAL: return foot_movement
		UnitData.MobilityType.WHEELED: return wheeled_movement
		UnitData.MobilityType.TRACKED: return tracked_movement
		UnitData.MobilityType.HOVER: return hover_movement
		UnitData.MobilityType.AERIAL: return vtol_movement
		_: return 999

# Official BT terrain validation (TO p.315)
func is_valid_combination(other: TerrainData) -> bool:
	if self.is_water() != other.is_water():
		return false
	if abs(self.min_depth - other.min_depth) > 1:
		return false
	return true

func is_water() -> bool:
	return "water" in name.to_lower()

func is_impassable_for(mobility_type:  UnitData.MobilityType) -> bool:
	return get_movement_cost(mobility_type) >= 999
